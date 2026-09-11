import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../diagnostics/report_timing.dart';

/// The location an SOS report is sent with.
///
/// Meeting 12 found the citizen flow too slow (Master Context v10 §6). The
/// GPS fix used to start only when the camera opened — after the three-second
/// hold — and the shutter refused to fire until it arrived, so a cold fix was
/// dead time stacked on top of everything else. Now the fix starts the moment
/// the resident *begins* holding SOS and keeps working while they aim, shoot
/// and choose who to call. The report waits for it only if it still has not
/// arrived by the time they press send.
///
/// One shared instance, because the fix outlives the screen that started it:
/// the hold starts it, the camera draws it, the report sends it.
class SosLocation {
  SosLocation._();

  static final SosLocation instance = SosLocation._();

  /// A fresh fix gives up after this long; the report then falls back to the
  /// device's last known position rather than failing outright.
  static const Duration freshLimit = Duration(seconds: 20);

  /// How old a position may be and still be sent without a fresh fix.
  static const Duration sendableAge = Duration(minutes: 2);

  /// How old the device's cached position may be to stand in, indoors, when a
  /// fresh fix times out. The report carries its accuracy, and the 300 m
  /// cluster radius absorbs indoor error (§10.1) — a report with a slightly
  /// stale position beats no report.
  static const Duration fallbackAge = Duration(minutes: 10);

  /// The best position so far, for screens to draw. Null until one arrives.
  final ValueNotifier<Position?> position = ValueNotifier(null);

  /// Why there is no position, when there is none — shown to the resident.
  final ValueNotifier<String?> problem = ValueNotifier(null);

  Future<Position?>? _inFlight;

  static bool _isRecent(Position p, Duration age) =>
      DateTime.now().difference(p.timestamp).abs() <= age;

  /// Start a fresh fix, or join the one already in flight.
  ///
  /// [requestPermission] is false from the SOS hold: a permission dialog there
  /// would cancel the hold under the resident's thumb. Permission is normally
  /// granted at start-up already; if not, the camera screen asks.
  Future<Position?> warmUp({bool requestPermission = true}) {
    final current = position.value;
    if (current != null && !_isRecent(current, sendableAge)) {
      // An old fix from an earlier session would put the pin in the wrong
      // place until the fresh one lands.
      position.value = null;
    }
    return _inFlight ??= _acquire(requestPermission).whenComplete(() => _inFlight = null);
  }

  Future<Position?> _acquire(bool requestPermission) async {
    problem.value = null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      problem.value = 'Location is off. Turn it on so responders can find you.';
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && requestPermission) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (requestPermission) {
        problem.value = 'Location permission is off. Allow it so responders can find you.';
      }
      return null;
    }

    // Something to draw at once while the fresh fix comes in.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && position.value == null && _isRecent(last, sendableAge)) {
        position.value = last;
      }
    } catch (_) {
      // no cached fix — fine
    }

    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: freshLimit,
        ),
      );
      position.value = fresh;
      ReportTiming.instance.mark('location_fix');
      return fresh;
    } catch (_) {
      final fallback = position.value ?? await _cachedWithin(fallbackAge);
      if (fallback != null) {
        position.value = fallback;
        ReportTiming.instance.mark('location_fallback');
        return fallback;
      }
      problem.value =
          'Could not pinpoint your location. Move near a window or outdoors and try again.';
      return null;
    }
  }

  Future<Position?> _cachedWithin(Duration age) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      return last != null && _isRecent(last, age) ? last : null;
    } catch (_) {
      return null;
    }
  }

  /// The position to send: the fix in flight (waiting for it if need be), a
  /// recent one already in hand, or a new fix. Null only if none can be had.
  Future<Position?> forReport() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final current = position.value;
    if (current != null && _isRecent(current, sendableAge)) {
      return Future.value(current);
    }
    return warmUp();
  }

  /// Test seam: forget everything.
  @visibleForTesting
  void reset() {
    position.value = null;
    problem.value = null;
    _inFlight = null;
  }
}
