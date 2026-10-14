import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// "450 m" below a kilometre, "1.3 km" from there.
///
/// Rounded before choosing the unit, so 999.6 m reads "1.0 km", never
/// "1000 m".
String formatDistance(double metres) {
  if (metres.round() < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// "450 m away", "1.3 km away".
String distanceAway(double metres) => '${formatDistance(metres)} away';

/// Great-circle metres between two points.
double metresBetween(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

/// One position fix with what navigation needs besides the point: how sure
/// the GPS is, how fast and which way the phone is moving, and when.
class LiveFix {
  const LiveFix({
    required this.point,
    required this.time,
    this.accuracy,
    this.speed,
    this.heading,
  });

  final LatLng point;
  final DateTime time;

  /// Metres, when known.
  final double? accuracy;

  /// Metres per second, when known.
  final double? speed;

  /// Direction of travel in degrees (0 = north), when known.
  final double? heading;
}

/// Where the resident is now, kept current while a screen that shows distances
/// is open.
///
/// The map used to ask the GPS once, when it opened, and every "450 m away"
/// was measured from that one fix for as long as the app stayed open — walk
/// toward a fire and the number never moved. Now one position stream feeds
/// every screen that measures: the map, and an incident's details.
///
/// Kind to the battery on purpose. The stream runs only while at least one
/// such screen holds it ([acquire] / [release]), stops whenever the app goes to
/// the background, and reports a new position only after the phone has moved
/// [distanceFilterMetres] — standing still costs nothing.
///
/// It never asks for permission itself: the map asks when it opens, and a
/// permission prompt from here would pop up over whatever screen is showing.
///
/// Navigation needs more (v1.12.9): turn-by-turn directions holding it
/// `precise` switch the stream to the best accuracy and a fix every second,
/// whether or not the phone moved, and [fix] carries speed and heading with
/// each one. Android otherwise delivers a fix every five seconds, which is
/// what made the map jump 50 m at a time on the road. Back to the gentle
/// settings when the last precise holder lets go.
class LivePosition with WidgetsBindingObserver {
  LivePosition._();

  static final LivePosition instance = LivePosition._();

  static const int distanceFilterMetres = 10;

  /// How often a precise holder gets a fix.
  static const Duration preciseInterval = Duration(seconds: 1);

  /// The latest position, or null before the first one.
  final ValueNotifier<LatLng?> here = ValueNotifier(null);

  /// The latest fix in full, set together with [here].
  final ValueNotifier<LiveFix?> fix = ValueNotifier(null);

  /// Accuracy of [here] in metres, when known.
  double? accuracy;

  int _holders = 0;
  int _precise = 0;
  bool _background = false;
  bool _starting = false;
  bool _runningPrecise = false;
  StreamSubscription<Position>? _sub;

  /// A screen that shows distances opened. Pair every call with [release],
  /// passing the same [precise].
  void acquire({bool precise = false}) {
    _holders++;
    if (precise) _precise++;
    if (_holders == 1) WidgetsBinding.instance.addObserver(this);
    if (precise && !_runningPrecise) _stop();
    unawaited(_start());
  }

  /// That screen closed.
  void release({bool precise = false}) {
    if (_holders == 0) return;
    _holders--;
    if (precise && _precise > 0) _precise--;
    if (_holders == 0) {
      WidgetsBinding.instance.removeObserver(this);
      _stop();
    } else if (_precise == 0 && _runningPrecise) {
      _stop();
      unawaited(_start());
    }
  }

  /// A position the screen got some other way — the map's first fix, which
  /// may also be the moment permission was granted, so the stream starts too.
  void offer(
    LatLng point, {
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? time,
  }) {
    this.accuracy = accuracy ?? this.accuracy;
    here.value = point;
    fix.value = LiveFix(
      point: point,
      time: time ?? DateTime.now(),
      accuracy: accuracy,
      speed: speed,
      heading: heading,
    );
    if (_holders > 0) unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _background = false;
      unawaited(_start());
    } else if (state == AppLifecycleState.paused) {
      _background = true;
      _stop();
    }
  }

  Future<void> _start() async {
    if (_sub != null || _starting || _background || _holders == 0) return;
    _starting = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      if (_sub != null || _background || _holders == 0) return;
      final precise = _precise > 0;
      _runningPrecise = precise;
      _sub = Geolocator.getPositionStream(locationSettings: _settings(precise))
          .listen(
            (p) {
              accuracy = p.accuracy;
              final point = LatLng(p.latitude, p.longitude);
              here.value = point;
              fix.value = LiveFix(
                point: point,
                time: p.timestamp,
                accuracy: p.accuracy >= 0 ? p.accuracy : null,
                speed: p.speed >= 0 ? p.speed : null,
                heading: p.heading >= 0 && p.heading < 360 ? p.heading : null,
              );
            },
            // Location switched off mid-stream, or the platform gave up. The
            // last position stays; the next resume or offer tries again.
            onError: (Object _) => _stop(),
            cancelOnError: true,
          );
    } catch (_) {
      // No location service on this device (or in a test): distances simply
      // stay measured from the last position the screen had.
    } finally {
      _starting = false;
    }
  }

  void _stop() {
    final sub = _sub;
    _sub = null;
    _runningPrecise = false;
    unawaited(sub?.cancel());
  }

  /// Gentle by default: a new point only after 10 m. Precise: the best fix
  /// every second, moving or not — on Android the interval has to be asked
  /// for, or the platform's default of five seconds applies.
  static LocationSettings _settings(bool precise) {
    if (!precise) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMetres,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: preciseInterval,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }
}
