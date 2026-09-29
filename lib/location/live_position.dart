import 'dart:async';

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
class LivePosition with WidgetsBindingObserver {
  LivePosition._();

  static final LivePosition instance = LivePosition._();

  static const int distanceFilterMetres = 10;

  /// The latest position, or null before the first one.
  final ValueNotifier<LatLng?> here = ValueNotifier(null);

  /// Accuracy of [here] in metres, when known.
  double? accuracy;

  int _holders = 0;
  bool _background = false;
  bool _starting = false;
  StreamSubscription<Position>? _sub;

  /// A screen that shows distances opened. Pair every call with [release].
  void acquire() {
    _holders++;
    if (_holders == 1) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_start());
    }
  }

  /// That screen closed.
  void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) {
      WidgetsBinding.instance.removeObserver(this);
      _stop();
    }
  }

  /// A position the screen got some other way — the map's first fix, which
  /// may also be the moment permission was granted, so the stream starts too.
  void offer(LatLng point, {double? accuracy}) {
    this.accuracy = accuracy ?? this.accuracy;
    here.value = point;
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
      _sub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: distanceFilterMetres,
            ),
          ).listen(
            (p) {
              accuracy = p.accuracy;
              here.value = LatLng(p.latitude, p.longitude);
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
    unawaited(sub?.cancel());
  }
}
