import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/responder_api.dart';
import '../../domain/entities/responder_incident.dart';
import 'tracking_provider.dart';

/// Incidents visible to this responder's agency.
final responderIncidentsProvider =
    FutureProvider.autoDispose<List<ResponderIncident>>((ref) async {
  final result = await ref.watch(responderApiProvider).incidents();
  return result.when(
    success: (items) => items,
    failure: (error) => throw error,
  );
});

/// The fire-code catalog. Rarely changes, so it is fetched once and kept.
final fireCodesProvider = FutureProvider<List<FireCode>>((ref) async {
  final result = await ref.watch(responderApiProvider).fireCodes();
  return result.when(
    success: (codes) =>
        codes..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
    failure: (error) => throw error,
  );
});

/// Drives the accept -> en route -> arrived progression.
class ResponderActions extends StateNotifier<bool> {
  ResponderActions(this._ref) : super(false);

  final Ref _ref;

  ResponderApi get _api => _ref.read(responderApiProvider);

  /// Runs one transition and reconciles GPS broadcasting with the new status.
  /// Returns a failure message, or null on success.
  Future<String?> _run(
    Future<dynamic> Function() call,
    String incidentId,
  ) async {
    state = true;
    final dynamic result = await call();
    state = false;

    return result.when(
      success: (dynamic value) {
        final incident = value as ResponderIncident;
        // Broadcasting follows the lifecycle rather than a button: it starts
        // when the responder commits and stops the moment the incident is no
        // longer being travelled to, so a phone never streams GPS indefinitely.
        final tracking = _ref.read(trackingProvider.notifier);
        if (incident.status == IncidentStatus.dispatched ||
            incident.status == IncidentStatus.enRoute) {
          tracking.start(incidentId);
        } else {
          tracking.stop();
        }
        _ref.invalidate(responderIncidentsProvider);
        return null;
      },
      failure: (dynamic error) => error.message as String,
    );
  }

  Future<String?> accept(String incidentId) =>
      _run(() => _api.selfDispatch(incidentId), incidentId);

  Future<String?> enRoute(String incidentId) =>
      _run(() => _api.markEnRoute(incidentId), incidentId);

  Future<String?> arrived(String incidentId) =>
      _run(() => _api.markArrived(incidentId), incidentId);

  Future<String?> pressCode({
    required String codeId,
    required String incidentId,
  }) async {
    final result =
        await _api.pressFireCode(codeId: codeId, incidentId: incidentId);
    return result.when(success: (_) => null, failure: (e) => e.message);
  }
}

final responderActionsProvider =
    StateNotifierProvider<ResponderActions, bool>(ResponderActions.new);
