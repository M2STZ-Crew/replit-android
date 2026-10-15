import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import 'phone_gate.dart';
import 'session.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code, this.details});
  final int statusCode;
  final String message;

  /// The backend's machine-readable `error` (e.g. `phone_code_cooldown`), when
  /// it sent one. Screens branch on this, never on the wording of [message].
  final String? code;

  /// The backend's `details` object, e.g. `{retry_after_seconds: 42}`.
  final Map<String, dynamic>? details;

  @override
  String toString() => message;
}

/// The stored session is over and could not be renewed: sign in again.
///
/// Distinct from a plain 401 so screens can tell "your session expired" from
/// "the network is down" and react differently. A retry cannot fix this one —
/// only signing in can — so anything that catches it should send the user to
/// the login screen rather than offering a button that will fail again.
class SessionExpiredException extends ApiException {
  SessionExpiredException()
    : super(401, 'Your session has ended. Please sign in again.');
}

class ApiClient {
  ApiClient({http.Client? client}) : _raw = client ?? http.Client();

  /// The bare connection; the session refresh goes over it.
  final http.Client _raw;

  /// Every other request goes over this one: a lapsed access token is renewed
  /// and the request replayed, whichever call it was ([_RenewingClient]).
  late final http.Client _client = _RenewingClient(_raw, _refreshSession);

  /// A refresh already under way, shared by every caller that hits a 401.
  static Future<bool>? _refreshing;

  /// Sign in with an email or a mobile number, and the password.
  ///
  /// A number works only once it is verified on the account; staff, who have
  /// none, keep signing in by email.
  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/login');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': ?email,
        'phone': ?phone,
        'password': password,
      }),
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

  /// Track It Live for an incident the caller reported: GET /areas/{id}/tracking.
  ///
  /// The same snapshot the `track:<id>` socket channel pushes — status, the
  /// incident's position, and each responding unit's label and position. The
  /// socket is the normal source; this is the first read and the fallback
  /// while the socket is down. 403 for anyone who did not report it.
  Future<Map<String, dynamic>> getTracking(String areaId) async {
    final resp = await _authed(
      () => _client.get(
        Uri.parse('${ApiConfig.baseUrl}/areas/$areaId/tracking'),
        headers: _auth,
      ),
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
    final resp = await _authed(
      () => _client.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: _auth,
      ),
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

  /// Phone OTP step 1: POST /verification/phone/request.
  ///
  /// The number may be typed any usual way (0917 123 4567, +63 917…); the
  /// server normalises it. Returns {message, phone, sent, expires_in_seconds,
  /// resend_after_seconds}. `sent` is false when the number is already
  /// verified on this account. A 429 carries `details.retry_after_seconds`.
  Future<Map<String, dynamic>> requestPhoneOtp(String phone) async {
    final resp = await _authed(
      () => _client.post(
        Uri.parse('${ApiConfig.baseUrl}/verification/phone/request'),
        headers: _jsonAuth,
        body: jsonEncode({'phone': phone}),
      ),
    );
    return _decode(resp);
  }

  /// Phone OTP (+40%) step 2: POST /verification/phone/verify.
  ///
  /// Returns {verified, verified_percent, badge, message}.
  Future<Map<String, dynamic>> verifyPhoneOtp(String code) async {
    final resp = await _authed(
      () => _client.post(
        Uri.parse('${ApiConfig.baseUrl}/verification/phone/verify'),
        headers: _jsonAuth,
        body: jsonEncode({'code': code}),
      ),
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

  /// Respond — "I am going": POST /incidents/{id}/self-dispatch (v12 §2.5.2).
  ///
  /// Open to responders and to Fire Volunteer / BFP coordinators once an
  /// incident is verified. The first to respond puts it On the way; responding
  /// twice to the same incident is refused (409).
  ///
  /// [vehicleName] is the unit they are going on — the coordinator's Accept
  /// sheet picks it. A label on the response (the citizen's tracking card
  /// shows it); a server without the field simply ignores it.
  Future<Map<String, dynamic>> selfDispatch(
    String id, {
    String? notes,
    String? vehicleName,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/self-dispatch'),
      headers: _jsonAuth,
      body: jsonEncode({'notes': ?notes, 'vehicle_name': ?vehicleName}),
    );
    return _decode(resp);
  }

  /// Response team members, for the Post-Incident Report roster picker:
  /// GET /incidents/{id}/available-responders. Each item has full_name,
  /// agency_type, organization_id, is_busy, on_this_incident.
  ///
  /// v11 removed manual dispatch, so this no longer feeds a dispatch screen —
  /// it feeds "who actually went", filed afterwards (§2.5.3).
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

  // v11 removed manual dispatch (§2.5): choosing a truck and a crew while the
  // incident was live was the paperwork that slowed the response down. The
  // truck, driver and roster are recorded afterwards on the Post-Incident
  // Report instead.

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

  // v11 has no markEnRoute: the first Accept carries an incident through
  // verified into en_route in one act (§2.5.1), so a responder opening it is
  // already rolling. Arrived is the next thing they press.

  /// Advance to arrived: POST /incidents/{id}/arrived.
  Future<Map<String, dynamic>> markArrived(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/arrived'),
      headers: _auth,
    );
    return _decode(resp);
  }

  // Withdraw went with manual dispatch (§2.5): there is no assignment to take
  // back. A responder who did not go simply is not on the report's roster.

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

  /// Verify — "this is a real fire": POST /incidents/{id}/verify (v12 §2.5.1).
  ///
  /// Sends nobody. The first verify moves the incident Reported -> Verified;
  /// then anyone going responds ([selfDispatch]). Responders may verify as well
  /// as captains. A responder finding it already verified is told to respond.
  Future<Map<String, dynamic>> verifyIncident(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/verify'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Two Areas that have grown to within reach of each other and wait on a
  /// merge-or-keep-separate decision (120 s window): GET
  /// /areas/overlaps/pending. Items carry area_a_id/area_b_id, their
  /// designations, distance_m and expires_at.
  Future<List<dynamic>> getPendingOverlaps() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/areas/overlaps/pending'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) _decode(resp); // throws with the server's words
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// Fold Area B into Area A: POST /areas/overlaps/{id}/merge.
  Future<Map<String, dynamic>> mergeOverlap(String overlapId) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/areas/overlaps/$overlapId/merge'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Keep two overlapping Areas apart: POST /areas/overlaps/{id}/keep-separate.
  Future<Map<String, dynamic>> keepOverlapSeparate(String overlapId) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/areas/overlaps/$overlapId/keep-separate'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// What this person has done, newest first, from the audit log: GET
  /// /audit-logs?actor_user_id=… (Admin and sub-admins only; a sub-admin sees
  /// entries for incidents their agency can see).
  Future<List<dynamic>> getMyDecisions(String userId, {int limit = 200}) async {
    final query = Uri(
      queryParameters: {'actor_user_id': userId, 'limit': '$limit'},
    ).query;
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/audit-logs?$query'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) _decode(resp); // throws with the server's words
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// The AI summaries written for one incident, newest first: GET
  /// /incidents/{id}/summaries. Written once the fire is out (v1.12.5).
  Future<List<dynamic>> getIncidentSummaries(String id) async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/summaries'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) _decode(resp); // throws with the server's words
    return jsonDecode(resp.body) as List<dynamic>;
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
  ///
  /// Everything here was picked on the form, not typed. [units] items are
  /// {name, type?, equipment_id?}; [roster] items are {name, user_id?}.
  Future<Map<String, dynamic>> filePostIncidentReport(
    String id, {
    DateTime? incidentAt,
    DateTime? fireOutAt,
    required List<Map<String, dynamic>> units,
    required String driverName,
    String? driverUserId,
    required List<Map<String, dynamic>> roster,
    required List<String> equipmentTaken,
    String? notes,
    bool falseAlarm = false,
    String? falseAlarmNote,
  }) async {
    final types = <String>[];
    for (final u in units) {
      final t = (u['type'] as String?) ?? 'Unit';
      if (!types.contains(t)) types.add(t);
    }
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/post-incident-report'),
      headers: _jsonAuth,
      body: jsonEncode({
        'incident_at': ?incidentAt?.toUtc().toIso8601String(),
        'fire_out_at': ?fireOutAt?.toUtc().toIso8601String(),
        'units': units,
        // A server from before several units could be recorded reads one
        // truck: the units as a line. The current server ignores these once
        // `units` is there.
        'truck_equipment_id': ?(units.isEmpty
            ? null
            : units.first['equipment_id']),
        'truck_label': units.map((u) => u['name']).join(', '),
        'truck_type': types.join(', '),
        'driver_name': driverName,
        'driver_user_id': ?driverUserId,
        'roster': roster,
        'equipment_taken': equipmentTaken,
        // The captain's own words; the AI summary reads them.
        'notes': ?notes,
        // v11 §2.5.3: the team reached the scene and found nothing. The server
        // requires the reason whenever the flag is set.
        'false_alarm': falseAlarm,
        'false_alarm_note': ?falseAlarmNote,
      }),
    );
    return _decode(resp);
  }

  /// Incidents the signed-in captain's team still owes a Post-Incident Report
  /// for — fire out, and their team has not filed:
  /// GET /post-incident-reports/owed. Each responding team files its own, so an
  /// incident another team already closed can still be owed here.
  Future<List<dynamic>> getOwedPostIncidentReports() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/post-incident-reports/owed'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load pending reports.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// The members of the signed-in captain's organisation — who the
  /// Post-Incident Report offers as driver and for the roster:
  /// GET /organizations/mine/members.
  Future<List<dynamic>> getMyOrgMembers() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/organizations/mine/members'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load your team.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  // ---- Responder accounts (coordinator, v1.12.4) ----------------------------

  /// The coordinator's responder accounts — their agency, their team:
  /// GET /team/responders. Active first.
  Future<List<dynamic>> getTeamResponders() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/team/responders'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, 'Failed to load your responders.');
    }
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// The address a new responder with this name would get now
  /// ("jdelacruz.resfir@replit.com"): GET /team/responders/email-preview.
  Future<String> previewResponderEmail(
    String firstName,
    String lastName,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/team/responders/email-preview')
        .replace(
          queryParameters: {'first_name': firstName, 'last_name': lastName},
        );
    final resp = await _client.get(uri, headers: _auth);
    return _decode(resp)['email'] as String;
  }

  /// Create a responder account: POST /team/responders. Returns
  /// {responder, email, temporary_password} — the password only this once.
  Future<Map<String, dynamic>> createResponder({
    required String firstName,
    required String lastName,
    String? mobile,
  }) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/team/responders'),
      headers: _jsonAuth,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'mobile': ?mobile,
      }),
    );
    return _decode(resp);
  }

  /// A new temporary password for a responder, returned once:
  /// POST /team/responders/{id}/reset-password.
  Future<Map<String, dynamic>> resetResponderPassword(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/team/responders/$id/reset-password'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Stop a responder account signing in (it keeps its history):
  /// POST /team/responders/{id}/deactivate.
  Future<Map<String, dynamic>> deactivateResponder(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/team/responders/$id/deactivate'),
      headers: _auth,
    );
    return _decode(resp);
  }

  /// Let a deactivated responder sign in again:
  /// POST /team/responders/{id}/reactivate.
  Future<Map<String, dynamic>> reactivateResponder(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/team/responders/$id/reactivate'),
      headers: _auth,
    );
    return _decode(resp);
  }

  // ---- AI summaries (coordinator, v1.12.5) ----------------------------------

  /// Every incident a team filed a report for, newest first, each with its
  /// newest AI summary and a `state` — ready, writing (the server is writing
  /// it; refresh shortly) or unavailable (no AI key): GET /ai-summaries.
  Future<List<dynamic>> getAiSummaries() async {
    final resp = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/ai-summaries'),
      headers: _auth,
    );
    if (resp.statusCode >= 400) _decode(resp); // throws with the server's words
    return jsonDecode(resp.body) as List<dynamic>;
  }

  /// A five-minute link to the incident's PDF for the phone's browser, which
  /// cannot send the sign-in: POST /incidents/{id}/report-link. The PDF is
  /// built when the link is opened, so it carries every report filed by then.
  Future<Uri> getReportLink(String id) async {
    final resp = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/incidents/$id/report-link'),
      headers: _auth,
    );
    return Uri.parse('${ApiConfig.baseUrl}${_decode(resp)['path']}');
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

  /// Trade the stored refresh token for a new session. True when it worked.
  ///
  /// Supabase rotates the refresh token on every use, so two concurrent
  /// refreshes would race and one would present a token the server has already
  /// retired. Callers therefore share a single in-flight attempt.
  Future<bool> _refreshSession() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final attempt = _doRefresh();
    _refreshing = attempt;
    return attempt.whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final token = Session.instance.refreshToken;
    if (token == null || token.isEmpty) return false;
    try {
      final resp = await _raw.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': token}),
      );
      if (resp.statusCode >= 400) return false;
      _storeSession(jsonDecode(resp.body) as Map<String, dynamic>);
      await Session.instance.persist();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Send a request whose 401 means the session is over.
  ///
  /// [_client] has already renewed a lapsed access token and replayed the
  /// request, so a 401 that reaches here is one renewing could not fix: the
  /// refresh token is missing or also expired. The session is cleared —
  /// leaving dead credentials on the device is what made this stick once —
  /// and [SessionExpiredException] is thrown for the caller to route to
  /// login. Used by the calls the app starts up with (/auth/me and friends).
  Future<http.Response> _authed(Future<http.Response> Function() send) async {
    final resp = await send();
    if (resp.statusCode == 401) {
      await Session.instance.clear();
      throw SessionExpiredException();
    }
    return resp;
  }

  void _storeSession(Map<String, dynamic> data) {
    Session.instance.setTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      email: data['email'] as String?,
    );
  }

  Map<String, dynamic> _decode(http.Response resp) {
    Map<String, dynamic> body;
    try {
      body = resp.body.isNotEmpty
          ? jsonDecode(resp.body) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (_) {
      // Not JSON. The backend always answers with JSON, so this means the app
      // is talking to something that is not RepLiT — which in practice means
      // the address was baked into the build wrongly. It used to surface as a
      // FormatException that no caller expected, so every screen reported it as
      // "could not reach the server" and the real cause stayed invisible.
      throw ApiException(
        resp.statusCode,
        'The server at ${ApiConfig.host} did not reply with RepLiT data. '
        'This build points at the wrong address — install the latest version.',
      );
    }
    if (resp.statusCode >= 400) {
      final message =
          (body['message'] as String?) ??
          'Request failed (${resp.statusCode}).';
      final code = body['error'] is String ? body['error'] as String : null;
      final details = body['details'] is Map<String, dynamic>
          ? body['details'] as Map<String, dynamic>
          : null;
      // A citizen whose phone is not verified is refused everywhere but the
      // verification routes. Whichever screen hit it, the answer is the same:
      // show the gate. RoleGate catches it at start-up; this catches the rest.
      if (resp.statusCode == 403 && code == PhoneGate.errorCode) {
        PhoneGate.trip();
      }
      throw ApiException(
        resp.statusCode,
        message,
        code: code,
        details: details,
      );
    }
    return body;
  }
}

/// Renews a lapsed access token for any request, then sends it again.
///
/// Access tokens last about an hour. Only the start-up calls used to renew
/// one, so an hour into a response every other request — the location fixes
/// the server marks a crew arrived from, the incident polls, Mark arrived —
/// went out with a dead token and failed quietly; the GPS arrival never came.
/// Now a 401 on a request that carried a token spends the refresh token once
/// (shared by every request that hit it, since Supabase rotates it), and the
/// request is replayed with the new token. A multipart upload cannot be
/// replayed; it still renews, so its retry goes through.
///
/// When renewing fails the 401 comes back saying the session has ended, in
/// words a person can act on, rather than the server's note about a header.
class _RenewingClient extends http.BaseClient {
  _RenewingClient(this._inner, this._renew);

  final http.Client _inner;
  final Future<bool> Function() _renew;

  static const _ended = 'Your session has ended. Please sign in again.';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authorised =
        request.headers['Authorization']?.startsWith('Bearer') ?? false;
    final replay = authorised && request is http.Request
        ? _copy(request)
        : null;
    final first = await _inner.send(request);
    if (first.statusCode != 401 || !authorised) return first;
    final body = await first.stream.toBytes();
    final again = http.StreamedResponse(
      Stream.value(body),
      401,
      headers: first.headers,
      request: first.request,
      reasonPhrase: first.reasonPhrase,
    );
    if (!await _renew()) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({'message': _ended, 'error': 'session_expired'}),
          ),
        ),
        401,
        headers: const {'content-type': 'application/json'},
        request: first.request,
      );
    }
    if (replay == null) return again;
    replay.headers['Authorization'] =
        'Bearer ${Session.instance.accessToken ?? ''}';
    return _inner.send(replay);
  }

  static http.Request _copy(http.Request r) => http.Request(r.method, r.url)
    ..bodyBytes = r.bodyBytes
    ..headers.addAll(r.headers)
    ..followRedirects = r.followRedirects
    ..maxRedirects = r.maxRedirects
    ..persistentConnection = r.persistentConnection;

  @override
  void close() => _inner.close();
}
