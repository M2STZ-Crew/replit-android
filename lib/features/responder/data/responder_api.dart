import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/api_client.dart';
import '../../reports/data/report_api.dart' show apiClientProvider;
import '../domain/entities/responder_incident.dart';

final responderApiProvider = Provider<ResponderApi>(
  (ref) => ResponderApi(ref.watch(apiClientProvider)),
);

/// Response Team operations: take an incident, advance it, broadcast position,
/// press fire codes (Section 2.5 stages 4-6, Section 2.6).
class ResponderApi {
  ResponderApi(this._client);

  final ApiClient _client;

  /// Incidents visible to the caller's agency. The backend applies the two-way
  /// BFP <-> Fire Volunteer visibility rule, so no client-side filtering.
  Future<Result<List<ResponderIncident>>> incidents({String? status}) async {
    try {
      final res = await _client.get<List<dynamic>>(
        '/incidents',
        queryParameters: {'status': ?status},
      );
      if (res.statusCode == 200 && res.data != null) {
        return Success([
          for (final i in res.data!)
            ResponderIncident.fromMap(i as Map<String, dynamic>),
        ]);
      }
      return Failure(ApiClient.toException(StateError('failed'), res));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  Future<Result<ResponderIncident>> _transition(String path, {Object? body}) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(path, data: body);
      if (res.statusCode == 200 && res.data != null) {
        return Success(ResponderIncident.fromMap(res.data!));
      }
      return Failure(ApiClient.toException(StateError('failed'), res));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// Self-select onto a verified incident (Section 2.5 stage 4).
  Future<Result<ResponderIncident>> selfDispatch(String incidentId, {String? notes}) =>
      _transition('/incidents/$incidentId/self-dispatch', body: {'notes': ?notes});

  Future<Result<ResponderIncident>> markEnRoute(String incidentId) =>
      _transition('/incidents/$incidentId/en-route');

  Future<Result<ResponderIncident>> markArrived(String incidentId) =>
      _transition('/incidents/$incidentId/arrived');

  /// POST /incidents/{id}/location — one GPS fix during active response.
  ///
  /// Called on a 5 s cadence (Section 2.4). Deliberately returns a Result that
  /// callers may ignore: a dropped fix is normal on mobile data and must not
  /// interrupt the responder, since the next one is seconds away.
  Future<Result<void>> pushLocation({
    required String incidentId,
    required double lat,
    required double lng,
    required DateTime capturedAt,
    double? accuracyM,
    double? speedMps,
    double? headingDeg,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/incidents/$incidentId/location',
        data: {
          'lat': lat,
          'lng': lng,
          'captured_at': capturedAt.toUtc().toIso8601String(),
          'accuracy_m': ?accuracyM,
          'speed_mps': ?speedMps,
          // The server rejects a bearing outside [0, 360).
          'heading_deg': ?(headingDeg != null && headingDeg >= 0 && headingDeg < 360
              ? headingDeg
              : null),
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return const Success(null);
      }
      return Failure(ApiClient.toException(StateError('failed'), res));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// GET /fire-codes — the catalog. target_role decides who may press each one.
  Future<Result<List<FireCode>>> fireCodes() async {
    try {
      final res = await _client.get<List<dynamic>>('/fire-codes');
      if (res.statusCode == 200 && res.data != null) {
        return Success([
          for (final c in res.data!) FireCode.fromMap(c as Map<String, dynamic>),
        ]);
      }
      return Failure(ApiClient.toException(StateError('failed'), res));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  Future<Result<void>> pressFireCode({
    required String codeId,
    String? incidentId,
    String? notes,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/fire-codes/$codeId/press',
        data: {'area_id': ?incidentId, 'notes': ?notes},
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return const Success(null);
      }
      return Failure(ApiClient.toException(StateError('failed'), res));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }
}
