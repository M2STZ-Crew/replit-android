import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/responder_api.dart';

class TrackingState {
  const TrackingState({
    this.incidentId,
    this.lastSentAt,
    this.fixesSent = 0,
    this.lastError,
  });

  final String? incidentId;
  final DateTime? lastSentAt;
  final int fixesSent;

  /// Surfaced only after repeated failures — see [TrackingNotifier].
  final String? lastError;

  bool get isBroadcasting => incidentId != null;
}

/// Broadcasts the responder's position while they are actively responding
/// (Section 2.4: 5-second intervals, so dispatchers and citizens see units move).
///
/// Driven by the OS position stream rather than a polling timer: the platform
/// batches and optimises location delivery, and repeatedly calling
/// getCurrentPosition would wake the GPS chip far more often than needed.
/// Posts are throttled to the 5 s cadence.
class TrackingNotifier extends StateNotifier<TrackingState> {
  TrackingNotifier(this._api) : super(const TrackingState());

  final ResponderApi _api;
  StreamSubscription<Position>? _sub;
  DateTime? _lastPostedAt;
  bool _posting = false;
  int _consecutiveFailures = 0;

  /// A single dropped fix is normal on mobile data; only a sustained outage is
  /// worth telling the responder about, since they can do nothing about one.
  static const _failuresBeforeSurfacing = 3;

  Future<void> start(String incidentId) async {
    if (state.incidentId == incidentId) return;
    await stop();

    // Permission was granted for the SOS flow, but a responder may have
    // installed and gone straight here.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = TrackingState(
        incidentId: incidentId,
        lastError: 'Location permission is needed so dispatch can see your unit.',
      );
      return;
    }

    state = TrackingState(incidentId: incidentId);
    _lastPostedAt = null;
    _consecutiveFailures = 0;

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Metres, not seconds: a stationary unit stops emitting, which is the
        // cheapest possible idle state. The throttle below caps the rate.
        distanceFilter: 5,
      ),
    ).listen(_onFix, onError: (Object e) {
      state = TrackingState(
        incidentId: state.incidentId,
        lastSentAt: state.lastSentAt,
        fixesSent: state.fixesSent,
        lastError: 'Location unavailable: $e',
      );
    });
  }

  Future<void> _onFix(Position position) async {
    final incidentId = state.incidentId;
    if (incidentId == null) return;

    final now = DateTime.now();
    if (_lastPostedAt != null &&
        now.difference(_lastPostedAt!) < AppConstants.responderGpsInterval) {
      return; // throttled to the 5 s cadence
    }
    // Never queue a second request behind a slow one — on a poor connection
    // that would build an ever-growing backlog of stale positions.
    if (_posting) return;

    _posting = true;
    _lastPostedAt = now;
    final result = await _api.pushLocation(
      incidentId: incidentId,
      lat: position.latitude,
      lng: position.longitude,
      capturedAt: position.timestamp,
      accuracyM: position.accuracy,
      speedMps: position.speed >= 0 ? position.speed : null,
      headingDeg: position.heading,
    );
    _posting = false;

    if (!mounted) return;
    result.when(
      success: (_) {
        _consecutiveFailures = 0;
        state = TrackingState(
          incidentId: incidentId,
          lastSentAt: now,
          fixesSent: state.fixesSent + 1,
        );
      },
      failure: (error) {
        _consecutiveFailures++;
        debugPrint('GPS push failed: ${error.message}');
        state = TrackingState(
          incidentId: incidentId,
          lastSentAt: state.lastSentAt,
          fixesSent: state.fixesSent,
          lastError: _consecutiveFailures >= _failuresBeforeSurfacing
              ? 'Dispatch is not receiving your position.'
              : null,
        );
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lastPostedAt = null;
    _posting = false;
    _consecutiveFailures = 0;
    if (mounted) state = const TrackingState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(ref.watch(responderApiProvider));
});
