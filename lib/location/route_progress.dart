import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Where someone is along a route: how much is left, and how far off it they
/// have strayed. What makes "1.2 km · 15 min" count down as they walk.
///
/// The person is placed on the nearest point of the route, and what is left is
/// the route from there to its end, plus the step back onto it. Distances
/// inside a segment use a flat-earth approximation around that segment, which
/// is well under a metre off at street scale.
class RouteProgress {
  const RouteProgress._({
    required this.remainingMetres,
    required this.offRouteMetres,
    required this.segment,
    required this.onRoute,
  });

  /// From here to the end, following the route.
  final double remainingMetres;

  /// How far the person is from the route line.
  final double offRouteMetres;

  /// The route segment they are on: [route[segment], route[segment + 1]].
  final int segment;

  /// The nearest point on the route: where the walked part ends.
  final LatLng onRoute;

  static const double _earth = 6371008.8;

  /// Place [here] on [route]. A route of fewer than two points is just its
  /// one point.
  static RouteProgress of(List<LatLng> route, LatLng here) {
    if (route.length < 2) {
      final end = route.isEmpty ? here : route.first;
      final d = _metres(here, end);
      return RouteProgress._(
        remainingMetres: d,
        offRouteMetres: d,
        segment: 0,
        onRoute: end,
      );
    }

    // Length of every segment, and of the route after each one.
    final lengths = [
      for (var i = 0; i + 1 < route.length; i++)
        _metres(route[i], route[i + 1]),
    ];
    final after = List<double>.filled(lengths.length, 0);
    for (var i = lengths.length - 2; i >= 0; i--) {
      after[i] = after[i + 1] + lengths[i + 1];
    }

    var best = double.infinity;
    var bestSegment = 0;
    var bestPoint = route.first;
    var bestT = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      final (point, t) = _nearestOnSegment(route[i], route[i + 1], here);
      final d = _metres(here, point);
      if (d < best) {
        best = d;
        bestSegment = i;
        bestPoint = point;
        bestT = t;
      }
    }
    final restOfSegment = lengths[bestSegment] * (1 - bestT);
    return RouteProgress._(
      remainingMetres: best + restOfSegment + after[bestSegment],
      offRouteMetres: best,
      segment: bestSegment,
      onRoute: bestPoint,
    );
  }

  /// The part of [route] still ahead: from the nearest point to the end.
  List<LatLng> ahead(List<LatLng> route) =>
      route.length < 2 ? route : [onRoute, ...route.sublist(segment + 1)];

  /// The part already walked: from the start to the nearest point.
  List<LatLng> behind(List<LatLng> route) =>
      route.length < 2 ? const [] : [...route.sublist(0, segment + 1), onRoute];

  static double _metres(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Meter, a, b);

  /// The nearest point to [p] on segment a–b, and how far along it (0..1).
  static (LatLng, double) _nearestOnSegment(LatLng a, LatLng b, LatLng p) {
    final cosLat = math.cos((a.latitude + b.latitude) / 2 * math.pi / 180);
    double x(LatLng q) =>
        (q.longitude - a.longitude) * math.pi / 180 * _earth * cosLat;
    double y(LatLng q) => (q.latitude - a.latitude) * math.pi / 180 * _earth;
    final bx = x(b), by = y(b), px = x(p), py = y(p);
    final len2 = bx * bx + by * by;
    final t = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
    return (
      LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
      t,
    );
  }
}
