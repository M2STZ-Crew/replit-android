import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import 'session.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<void> login({required String email, required String password}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/login');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _storeSession(_decode(resp));
  }

  Future<void> signup({
    required String email,
    required String password,
    required String fullName,
    String? mobile,
    String? dateOfBirth, // ISO yyyy-MM-dd
    String? gender,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/signup');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'mobile': ?mobile,
        'date_of_birth': ?dateOfBirth,
        'gender': ?gender,
      }),
    );
    _storeSession(_decode(resp));
  }

  /// Update the caller's editable profile fields: PATCH /auth/me/profile.
  /// Returns the refreshed /auth/me-shaped profile.
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? mobile,
    String? dateOfBirth, // ISO yyyy-MM-dd
    String? gender,
  }) async {
    final resp = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/auth/me/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
      body: jsonEncode({
        'full_name': ?fullName,
        'mobile': ?mobile,
        'date_of_birth': ?dateOfBirth,
        'gender': ?gender,
      }),
    );
    return _decode(resp);
  }

  /// Request a password-reset email (public): POST /auth/recover.
  Future<String> requestPasswordReset(String email) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/recover'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final body = _decode(resp);
    return (body['message'] as String?) ??
        'If that email is registered, a reset link has been sent.';
  }

  /// The caller's in-app notification inbox (newest first): GET /notifications.
  Future<List<dynamic>> getNotifications() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load notifications.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Unread-notification count for the bell badge: GET /notifications/unread-count.
  Future<int> getUnreadNotificationCount() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications/unread-count'),
      headers: _auth,
    );
    final body = _decode(resp);
    return (body['count'] as num?)?.toInt() ?? 0;
  }

  /// Mark all the caller's notifications read: POST /notifications/read-all.
  Future<void> markAllNotificationsRead() async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
        headers: _auth,
      );
    } catch (_) {
      // best-effort
    }
  }

  /// Mark one notification read: POST /notifications/{id}/read.
  Future<void> markNotificationRead(String id) async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
        headers: _auth,
      );
    } catch (_) {
      // best-effort
    }
  }

  /// Send a test push to the caller's registered devices: POST /devices/test.
  Future<String> sendTestPush() async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/devices/test'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    final body = _decode(resp);
    return (body['message'] as String?) ?? 'Test notification sent.';
  }

  /// Submit an incident report (multipart): photo + device GPS + agencies + notes.
  Future<Map<String, dynamic>> submitReport({
    required double lat,
    required double lng,
    double? accuracyM,
    required List<String> agencies,
    String? notes,
    required List<int> photoBytes,
    String photoFilename = 'sos.jpg',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/reports/submit');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] =
          'Bearer ${Session.instance.accessToken ?? ''}'
      ..fields['device_lat'] = lat.toString()
      ..fields['device_lng'] = lng.toString()
      ..fields['selected_agencies'] = agencies.join(',');
    if (accuracyM != null) {
      request.fields['device_gps_accuracy_m'] = accuracyM.toString();
    }
    if (notes != null && notes.isNotEmpty) request.fields['notes'] = notes;
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: photoFilename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    // Through the shared client (not request.send(), which opens a new one):
    // the connection is reused, and a test can stand in for the server.
    final streamed = await _client.send(request);
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp);
  }

  /// Read one incident area (citizen-accessible): GET /areas/{id}.
  Future<Map<String, dynamic>> getArea(String areaId) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/areas/$areaId'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    return _decode(resp);
  }

  /// List evacuation sites (citizen-accessible): GET /map/evacuation-sites.
  Future<List<dynamic>> getEvacuationSites() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/map/evacuation-sites'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load evacuation sites.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// List incident areas (citizen-accessible): GET /areas.
  ///
  /// Citizens use /areas (not the staff-only /incidents feed). Each item has
  /// centroid_lat/centroid_lng, designation, status, report_count, etc. Pass
  /// activeOnly: false to also include resolved/rejected areas.
  Future<List<dynamic>> getAreas({bool activeOnly = true}) async {
    final query = activeOnly ? '' : '?active_only=false';
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/areas$query'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load incident areas.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Add responder agencies to an incident you already reported:
  /// POST /areas/{areaId}/request-agencies. Returns the merged agency list.
  Future<Map<String, dynamic>> requestAreaAgencies(
    String areaId,
    List<String> agencies,
  ) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/areas/$areaId/request-agencies'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
      body: jsonEncode({'agencies': agencies}),
    );
    return _decode(resp);
  }

  /// Current user profile + verification status: GET /auth/me.
  ///
  /// Returns role, full_name, email, phone, verified_percent (0–100), and badge
  /// (yellow | light_green | green | green_check).
  Future<Map<String, dynamic>> getMe() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    return _decode(resp);
  }

  /// Progressive verification, per channel: GET /verification/status.
  /// `{verified_percent, badge, channels: [{type, status, ...}]}` — the only
  /// way to tell "never submitted" from "submitted, awaiting review".
  Future<Map<String, dynamic>> getVerificationStatus() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/verification/status'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    return _decode(resp);
  }

  /// The caller's own reports with signed media URLs: GET /reports/mine.
  Future<List<dynamic>> getMyReports() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/reports/mine'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load your reports.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Respond to a 300 m neighborhood alert: POST /notifications/respond.
  /// [response] is 'report' (confirm a fire nearby) or 'ignore' (dismiss).
  Future<void> respondToAlert(String areaId, String response) async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
        },
        body: jsonEncode({'area_id': areaId, 'response': response}),
      );
    } catch (_) {
      // best-effort
    }
  }

  /// Register/refresh this device's FCM token: POST /devices.
  Future<void> registerDevice({
    required String fcmToken,
    String platform = 'android',
    String? deviceName,
    String? appVersion,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/devices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
      body: jsonEncode({
        'fcm_token': fcmToken,
        'platform': platform,
        'device_name': ?deviceName,
        'app_version': ?appVersion,
      }),
    );
    _decode(resp);
  }

  /// Unregister an FCM token: DELETE /devices/{token} (best-effort).
  Future<void> unregisterDevice(String fcmToken) async {
    try {
      await _client.delete(
        Uri.parse('${ApiConfig.baseUrl}/devices/$fcmToken'),
        headers: {
          'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
        },
      );
    } catch (_) {
      // ignore — local token is cleared regardless
    }
  }

  /// Update the caller's last-known location: POST /auth/me/location.
  ///
  /// Sets users.location so the 300 m neighborhood-alert worker can reach this
  /// device. Best-effort — a failure must not block the app.
  Future<void> updateMyLocation(double lat, double lng) async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/me/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
        },
        body: jsonEncode({'latitude': lat, 'longitude': lng}),
      );
    } catch (_) {
      // ignore
    }
  }

  /// Revoke the current session server-side: POST /auth/logout (best-effort).
  Future<void> logout() async {
    try {
      await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
        headers: {
          'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
        },
      );
    } catch (_) {
      // Ignore — the local session is cleared regardless.
    }
  }

  // ----------------------------------------------------------------- //
  // Progressive verification (Phase 4)
  // ----------------------------------------------------------------- //

  /// Email verification (+10%): POST /verification/email/request.
  ///
  /// Sends a one-time link to the user's email. Confirmation happens when the
  /// user clicks the link (opens in a browser); the app then re-reads /auth/me.
  Future<String> requestEmailVerification() async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/verification/email/request'),
      headers: {
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
    );
    final body = _decode(resp);
    return (body['message'] as String?) ?? 'Verification email sent.';
  }

  /// Phone OTP (+40%) step 1: POST /verification/phone/request.
  Future<String> requestPhoneOtp(String phone) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/verification/phone/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
      body: jsonEncode({'phone': phone}),
    );
    final body = _decode(resp);
    return (body['message'] as String?) ?? 'Verification code sent via SMS.';
  }

  /// Phone OTP (+40%) step 2: POST /verification/phone/verify.
  ///
  /// Returns {verified, verified_percent, badge, message}.
  Future<Map<String, dynamic>> verifyPhoneOtp(String code) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/verification/phone/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
      },
      body: jsonEncode({'code': code}),
    );
    return _decode(resp);
  }

  /// National ID (+50%) manual path: POST /verification/national-id/manual.
  ///
  /// Uploads an ID photo + a matching selfie for Admin review. The +50% is
  /// awarded once an admin approves. Returns {verified, verified_percent, ...}.
  Future<Map<String, dynamic>> submitNationalIdManual({
    required List<int> idBytes,
    required List<int> selfieBytes,
    String idFilename = 'national_id.jpg',
    String selfieFilename = 'selfie.jpg',
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/verification/national-id/manual',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] =
          'Bearer ${Session.instance.accessToken ?? ''}';
    request.files.add(
      http.MultipartFile.fromBytes(
        'id_image',
        idBytes,
        filename: idFilename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'selfie_image',
        selfieBytes,
        filename: selfieFilename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp);
  }

  // ----------------------------------------------------------------- //
  // Responder / staff incidents (response_team console)
  // ----------------------------------------------------------------- //

  Map<String, String> get _auth => {
    'Authorization': 'Bearer ${Session.instance.accessToken ?? ''}',
  };

  Map<String, String> get _jsonAuth => {
    'Content-Type': 'application/json',
    ..._auth,
  };

  /// List incidents visible to the caller's agency: GET /incidents.
  ///
  /// [status] filters to one area_status; pass activeOnly: false with it for a
  /// status that is off the live feed (e.g. 'post_incident_report').
  Future<List<dynamic>> getIncidents({
    bool activeOnly = true,
    String? status,
  }) async {
    final query = Uri(
      queryParameters: {
        if (!activeOnly) 'active_only': 'false',
        'status': ?status,
      },
    ).query;
    final resp = await _client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/incidents${query.isEmpty ? '' : '?$query'}',
      ),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load incidents.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// One incident with reports + lifecycle: GET /incidents/{id}.
  Future<Map<String, dynamic>> getIncident(String id) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Self-select onto a verified incident: POST /incidents/{id}/self-dispatch.
  Future<Map<String, dynamic>> selfDispatch(String id, {String? notes}) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/self-dispatch'),
      headers: _jsonAuth,
      body: jsonEncode({'notes': ?notes}),
    );
    return _decode(resp);
  }

  /// List response_team users a sub-admin can dispatch (crew picker):
  /// GET /incidents/{id}/available-responders. Each item has full_name,
  /// agency_type, organization_id, is_busy, on_this_incident.
  Future<List<dynamic>> getAvailableResponders(String id) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/available-responders'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load responders.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Manually dispatch one response_team user (sub-admin): POST
  /// /incidents/{id}/dispatch. One call per responder; vehicleName + crewRole
  /// record which truck they crew and in what role.
  Future<Map<String, dynamic>> dispatchResponder(
    String id, {
    required String responderId,
    String? organizationId,
    String? vehicleName,
    String? crewRole,
    String? notes,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/dispatch'),
      headers: _jsonAuth,
      body: jsonEncode({
        'responder_id': responderId,
        'organization_id': ?organizationId,
        'vehicle_name': ?vehicleName,
        'crew_role': ?crewRole,
        'notes': ?notes,
      }),
    );
    return _decode(resp);
  }

  /// List the caller's organization equipment (fleet): GET /equipment.
  Future<List<dynamic>> getEquipment() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/equipment'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load equipment.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// List active fire codes (FC-1..FC-8): GET /fire-codes.
  Future<List<dynamic>> getFireCodes() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/fire-codes'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load fire codes.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Press / broadcast a fire code to the incident's units: POST
  /// /fire-codes/{codeId}/press.
  Future<Map<String, dynamic>> pressFireCode(
    String codeId, {
    String? areaId,
    String? notes,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/fire-codes/$codeId/press'),
      headers: _jsonAuth,
      body: jsonEncode({'area_id': ?areaId, 'notes': ?notes}),
    );
    return _decode(resp);
  }

  /// Raise an alarm-escalation request to BFP: POST /alarm-requests.
  Future<Map<String, dynamic>> createAlarmRequest({
    required String areaId,
    required String alarmLevel,
    String? justification,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/alarm-requests'),
      headers: _jsonAuth,
      body: jsonEncode({
        'area_id': areaId,
        'requested_alarm_level': alarmLevel,
        'justification': ?justification,
      }),
    );
    return _decode(resp);
  }

  /// List alarm requests for review (BFP sub-admin/admin): GET /alarm-requests.
  /// Pass [status] (e.g. 'pending') to filter. Items include area_designation
  /// and requested_by_name.
  Future<List<dynamic>> getAlarmRequests({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/alarm-requests$query'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load alarm requests.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Execute (apply) an alarm request — BFP only: POST /alarm-requests/{id}/execute.
  Future<Map<String, dynamic>> executeAlarmRequest(
    String id, {
    String? notes,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/alarm-requests/$id/execute'),
      headers: _jsonAuth,
      body: jsonEncode({'notes': ?notes}),
    );
    return _decode(resp);
  }

  /// Reject an alarm request — BFP only: POST /alarm-requests/{id}/reject.
  Future<Map<String, dynamic>> rejectAlarmRequest(
    String id, {
    String? notes,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/alarm-requests/$id/reject'),
      headers: _jsonAuth,
      body: jsonEncode({'notes': ?notes}),
    );
    return _decode(resp);
  }

  /// Advance to en route: POST /incidents/{id}/en-route.
  Future<Map<String, dynamic>> markEnRoute(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/en-route'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Advance to arrived: POST /incidents/{id}/arrived.
  Future<Map<String, dynamic>> markArrived(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/arrived'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Withdraw a dispatch: POST /incidents/{id}/dispatches/{dispatchId}/withdraw.
  Future<Map<String, dynamic>> withdrawDispatch(
    String id,
    String dispatchId,
  ) async {
    final resp = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/incidents/$id/dispatches/$dispatchId/withdraw',
      ),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// List dispatches on an incident: GET /incidents/{id}/dispatches.
  Future<List<dynamic>> getDispatches(String id) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/dispatches'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load dispatches.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Latest location per responder: GET /incidents/{id}/responders/locations.
  Future<List<dynamic>> getResponderLocations(String id) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/responders/locations'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(
        resp.statusCode,
        'Failed to load responder locations.',
      );
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Post one responder GPS fix (5 s cadence): POST /incidents/{id}/location.
  Future<void> postResponderLocation(
    String id, {
    required double lat,
    required double lng,
    double? accuracyM,
    double? speedMps,
    double? headingDeg,
    String? dispatchId,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/location'),
      headers: _jsonAuth,
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
        'accuracy_m': ?accuracyM,
        'speed_mps': ?speedMps,
        'heading_deg': ?headingDeg,
        'dispatch_id': ?dispatchId,
      }),
    );
    _decode(resp);
  }

  /// An incident's member reports with reporter name + signed photo (sub-admin
  /// review): GET /incidents/{id}/reports.
  Future<List<dynamic>> getIncidentReports(String id) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/reports'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load reports.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Verify an incident (Fire-Vol sub-admin): POST /incidents/{id}/verify.
  Future<Map<String, dynamic>> verifyIncident(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/verify'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Reject an incident (sub-admin): POST /incidents/{id}/reject.
  Future<Map<String, dynamic>> rejectIncident(String id, String reason) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/reject'),
      headers: _jsonAuth,
      body: jsonEncode({'reason': reason}),
    );
    return _decode(resp);
  }

  /// Resolve an incident (sub-admin): POST /incidents/{id}/resolve.
  Future<Map<String, dynamic>> resolveIncident(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/resolve'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// File the Post-Incident Report (team captain, Master Context v10 §2.5):
  /// POST /incidents/{id}/post-incident-report. Single submit — the report and
  /// the incident's close commit together, and a filed report cannot be edited.
  /// [roster] items are {name, role?, user_id?}.
  Future<Map<String, dynamic>> filePostIncidentReport(
    String id, {
    String? truckEquipmentId,
    required String truckLabel,
    required String truckType,
    required String driverName,
    String? driverUserId,
    required List<Map<String, dynamic>> roster,
    required List<String> equipmentTaken,
    String? notes,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/post-incident-report'),
      headers: _jsonAuth,
      body: jsonEncode({
        'truck_equipment_id': ?truckEquipmentId,
        'truck_label': truckLabel,
        'truck_type': truckType,
        'driver_name': driverName,
        'driver_user_id': ?driverUserId,
        'roster': roster,
        'equipment_taken': equipmentTaken,
        'notes': ?notes,
      }),
    );
    return _decode(resp);
  }

  /// A filed Post-Incident Report: GET /incidents/{id}/post-incident-report.
  Future<Map<String, dynamic>> getPostIncidentReport(String id) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/post-incident-report'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Responder dashboard counters: GET /incidents/stats.
  Future<Map<String, dynamic>> getIncidentStats() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/stats'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Map layer reads (any authenticated user — Master Context v10 §2.4).
  Future<List<dynamic>> getHydrants() => _mapLayer('hydrants');
  Future<List<dynamic>> getRiskZones() => _mapLayer('risk-zones');
  Future<List<dynamic>> getBodiesOfWater() => _mapLayer('bodies-of-water');
  Future<List<dynamic>> getUndergroundCisterns() =>
      _mapLayer('underground-cisterns');

  Future<List<dynamic>> _mapLayer(String layer) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/map/$layer'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load $layer.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  void _storeSession(Map<String, dynamic> data) {
    Session.instance.setTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      email: data['email'] as String?,
    );
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final Map<String, dynamic> body = resp.body.isNotEmpty
        ? jsonDecode(resp.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (resp.statusCode >= 400) {
      final message =
          (body['message'] as String?) ??
          'Request failed (${resp.statusCode}).';
      throw ApiException(resp.statusCode, message);
    }
    return body;
  }
}
