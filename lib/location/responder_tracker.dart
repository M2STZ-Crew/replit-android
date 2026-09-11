import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';

/// Shares a dispatched responder's position with command every five seconds
/// (Master Context v10 §6) for as long as the dispatch lasts.
///
/// This used to live inside the incident screen: a timer that asked the GPS
/// for a brand-new fix every five seconds and posted it. Two things were wrong
/// with that. Leaving the screen — to check the map, answer the phone — stopped
/// the sharing, and a fix slower than five seconds let requests pile up behind
/// one another. Now one tracker per app listens to a continuous position
/// stream and posts the latest point on a steady five-second beat, whichever
/// screen is showing. On Android it runs as a foreground service with an
/// ongoing notification, so it keeps going with the screen off.
///
/// It stops by itself when the server refuses a point (403/404): the dispatch
/// ended — fire out, withdrawn — and there is nothing left to share.
class ResponderTracker {
  ResponderTracker._();

  static final ResponderTracker instance = ResponderTracker._();

  static const Duration interval = Duration(seconds: 5);

  /// The API the points go to. Replaceable in tests.
  @visibleForTesting
  ApiClient api = ApiClient();

  /// The latest position, for the incident screen's map.
  final ValueNotifier<Position?> position = ValueNotifier(null);

  /// The incident being shared for, or null when not sharing.
  final ValueNotifier<String?> sharingFor = ValueNotifier(null);

  StreamSubscription<Position>? _sub;
  Timer? _beat;
  String? _dispatchId;
  Position? _latest;
  bool _posting = false;

  bool get isSharing => sharingFor.value != null;

  /// Share for this dispatch. Harmless to call again for the same one.
  Future<void> start({required String incidentId, required String dispatchId}) async {
    if (sharingFor.value == incidentId && _dispatchId == dispatchId) return;
    await stop();
    if (!await _permitted()) return;
    sharingFor.value = incidentId;
    _dispatchId = dispatchId;
    _listen(foreground: defaultTargetPlatform == TargetPlatform.android);
    _beat = Timer.periodic(interval, (_) => _post());
  }

  Future<void> stop() async {
    _beat?.cancel();
    _beat = null;
    _dispatchId = null;
    _latest = null;
    sharingFor.value = null;
    // Not awaited: nothing depends on the platform finishing the teardown, and
    // a later listen is ordered after it on the same channel anyway.
    unawaited(_sub?.cancel());
    _sub = null;
  }

  void _listen({required bool foreground}) {
    _sub = Geolocator.getPositionStream(locationSettings: _settings(foreground)).listen(
      (p) {
        final first = _latest == null;
        _latest = p;
        position.value = p;
        if (first) _post(); // the first point goes at once, not five seconds later
      },
      onError: (Object _) {
        // The foreground service could not start (a permission the OS
        // withheld). Keep sharing while the app is open rather than not at all.
        if (foreground && isSharing) {
          final failed = _sub;
          _listen(foreground: false);
          unawaited(failed?.cancel());
        }
      },
    );
  }

  LocationSettings _settings(bool foreground) {
    if (foreground) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Sharing your location with command',
          notificationText: 'RepLiT sends your position while you respond.',
          notificationChannelName: 'Response location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  Future<bool> _permitted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<void> _post() async {
    final p = _latest;
    final incidentId = sharingFor.value;
    if (p == null || incidentId == null || _posting) return;
    _posting = true;
    try {
      await api.postResponderLocation(
        incidentId,
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: p.accuracy >= 0 ? p.accuracy : null,
        speedMps: p.speed >= 0 ? p.speed : null,
        headingDeg: (p.heading >= 0 && p.heading < 360) ? p.heading : null,
        dispatchId: _dispatchId,
      );
    } on ApiException catch (e) {
      // No active dispatch any more (fire out, withdrawn), or no incident.
      if (e.statusCode == 403 || e.statusCode == 404) await stop();
    } catch (_) {
      // Offline for a moment — the next beat tries again with a newer point.
    } finally {
      _posting = false;
    }
  }
}
