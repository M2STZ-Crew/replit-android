import 'package:latlong2/latlong.dart';

/// How busy a stretch of road is, as the routing provider reports it. Only
/// Mapbox's `driving-traffic` profile reports it; every other route says
/// [unknown] throughout, and the map draws no traffic for it.
enum Congestion { unknown, low, moderate, heavy, severe }

Congestion _congestion(Object? raw) => switch (raw) {
  'low' => Congestion.low,
  'moderate' => Congestion.moderate,
  'heavy' => Congestion.heavy,
  'severe' => Congestion.severe,
  _ => Congestion.unknown,
};

/// One lane at a maneuver, left to right, as the routing provider lists it
/// (PRD v14 §4.9.2): the ways it goes, and whether it can be taken for this
/// maneuver. Read from the maneuver's own intersection in the Directions
/// answer (`intersections[0].lanes`, the same format for Mapbox and OSRM).
class LaneInfo {
  const LaneInfo({
    required this.indications,
    required this.valid,
    this.preferred = false,
    this.validIndication,
  });

  /// `left`, `slight left`, `sharp left`, `straight`, `slight right`,
  /// `right`, `sharp right`, `uturn` or `none`.
  final List<String> indications;

  /// This lane can be used to make the maneuver.
  final bool valid;

  /// Mapbox's `active`: the lane the route prefers among the valid ones.
  final bool preferred;

  /// Which of [indications] the maneuver uses, when the provider says.
  final String? validIndication;

  /// The way this lane's arrow points on the strip.
  String get shown =>
      valid && validIndication != null ? validIndication! : indications.first;
}

/// The lanes of a step's maneuver, or null when there is nothing usable:
/// no lane data, a malformed entry, or no lane that can be taken. Nothing is
/// guessed — a strip that might be wrong is worse than none.
List<LaneInfo>? parseLanes(Object? intersections) {
  if (intersections is! List || intersections.isEmpty) return null;
  final first = intersections.first;
  if (first is! Map) return null;
  final raw = first['lanes'];
  if (raw is! List || raw.isEmpty) return null;
  final lanes = <LaneInfo>[];
  for (final lane in raw) {
    if (lane is! Map) return null;
    final indications = lane['indications'];
    final valid = lane['valid'];
    if (indications is! List ||
        indications.isEmpty ||
        indications.any((i) => i is! String) ||
        valid is! bool) {
      return null;
    }
    final chosen = lane['valid_indication'];
    lanes.add(
      LaneInfo(
        indications: List.unmodifiable(indications.cast<String>()),
        valid: valid,
        preferred: lane['active'] == true,
        validIndication: chosen is String ? chosen : null,
      ),
    );
  }
  if (!lanes.any((l) => l.valid)) return null;
  return List.unmodifiable(lanes);
}

/// One maneuver of a route: what to do, where, and onto which street.
///
/// Fields follow the OSRM step format, which Mapbox Directions shares, so one
/// parser reads both providers.
class NavStep {
  const NavStep({
    required this.type,
    required this.name,
    required this.location,
    required this.distance,
    required this.duration,
    required this.at,
    this.modifier,
    this.exit,
    this.bearingAfter,
    this.lanes,
  });

  /// `depart`, `turn`, `new name`, `continue`, `merge`, `on ramp`,
  /// `off ramp`, `fork`, `end of road`, `roundabout`, `rotary`,
  /// `roundabout turn`, `exit roundabout`, `exit rotary`, `notification`,
  /// `arrive`.
  final String type;

  /// `uturn`, `sharp right`, `right`, `slight right`, `straight`,
  /// `slight left`, `left`, `sharp left`; null when the provider gave none.
  final String? modifier;

  /// The street the maneuver leads onto; empty when the road has no name.
  final String name;

  /// Roundabout exit number, when there is one.
  final int? exit;

  /// Compass bearing (degrees) of the road after the maneuver.
  final double? bearingAfter;

  /// Where the maneuver happens.
  final LatLng location;

  /// Metres and seconds from this maneuver to the next one. Seconds are the
  /// provider's, traffic-aware when the route is.
  final double distance;
  final double duration;

  /// Metres along the route geometry at which this maneuver happens.
  final double at;

  /// The lanes at this maneuver, when the provider gave usable ones.
  final List<LaneInfo>? lanes;
}

/// One road route: its geometry, its steps, and what the provider says it
/// takes. Distances along it ([along]) are measured on its own geometry, so
/// progress and the step positions agree to the metre.
class NavRoute {
  NavRoute({
    required this.points,
    required this.duration,
    required this.steps,
    required this.summary,
    this.typicalDuration,
    this.congestion,
    this.approximate = false,
  }) : along = _cumulative(points);

  /// A straight line from [from] to [to], for when no road route could be had.
  /// [approximate] is set: it is never shown as a road route, has no turns,
  /// and its time is a pace estimate.
  factory NavRoute.straight(LatLng from, LatLng to, {required double pace}) {
    final metres = const Distance().as(LengthUnit.Meter, from, to);
    return NavRoute(
      points: [from, to],
      duration: metres / pace,
      steps: const [],
      summary: '',
      approximate: true,
    );
  }

  final List<LatLng> points;

  /// Seconds end to end, as the provider estimates it.
  final double duration;

  /// The same trip without today's traffic, when the provider gave it.
  final double? typicalDuration;
  final List<NavStep> steps;

  /// The main roads it takes ("Taft Avenue, EDSA"), when the provider gave
  /// them.
  final String summary;

  /// Congestion per geometry segment (points.length - 1 entries), or null.
  final List<Congestion>? congestion;

  /// A straight line standing in for a route (see [NavRoute.straight]).
  final bool approximate;

  /// Metres from the start to each point.
  final List<double> along;

  /// Metres end to end, on this geometry.
  double get length => along.last;

  /// Whether any part of it carries live traffic.
  bool get hasTraffic =>
      congestion?.any((c) => c != Congestion.unknown) ?? false;

  static List<double> _cumulative(List<LatLng> points) {
    const distance = Distance(roundResult: false);
    final out = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      out[i] =
          out[i - 1] + distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return out;
  }
}

/// The routes in an OSRM or Mapbox Directions response, recommended first.
/// A route without at least two points is dropped. [walkingPace], when given,
/// replaces the provider's times with that pace in metres per second — for a
/// walker routed on a driving network, whose driving times would be wrong.
List<NavRoute> parseRoutes(Map<String, dynamic> json, {double? walkingPace}) {
  final routes = <NavRoute>[];
  for (final raw in (json['routes'] as List?) ?? const []) {
    final route = raw as Map<String, dynamic>;
    final coords = (route['geometry'] as Map?)?['coordinates'] as List?;
    if (coords == null || coords.length < 2) continue;
    final points = [
      for (final c in coords)
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    final along = NavRoute._cumulative(points);
    final legs = (route['legs'] as List?) ?? const [];
    final leg = legs.isEmpty ? const <String, dynamic>{} : legs.first as Map;
    final steps = <NavStep>[];
    var from = 0;
    for (final s in (leg['steps'] as List?) ?? const []) {
      final step = s as Map;
      final m = step['maneuver'] as Map;
      final loc = m['location'] as List;
      final location = LatLng(
        (loc[1] as num).toDouble(),
        (loc[0] as num).toDouble(),
      );
      from = _vertexNear(points, location, from);
      final metres = (step['distance'] as num?)?.toDouble() ?? 0;
      steps.add(
        NavStep(
          type: (m['type'] as String?) ?? 'turn',
          modifier: m['modifier'] as String?,
          exit: (m['exit'] as num?)?.toInt(),
          bearingAfter: (m['bearing_after'] as num?)?.toDouble(),
          // Mapbox lists a road's other names after a ';': say the first.
          name: ((step['name'] as String?) ?? '').split(';').first.trim(),
          location: location,
          distance: metres,
          duration: walkingPace != null
              ? metres / walkingPace
              : (step['duration'] as num?)?.toDouble() ?? 0,
          at: along[from],
          lanes: parseLanes(step['intersections']),
        ),
      );
    }
    final congestion = (leg['annotation'] as Map?)?['congestion'] as List?;
    final metres = (route['distance'] as num?)?.toDouble() ?? along.last;
    routes.add(
      NavRoute(
        points: points,
        duration: walkingPace != null
            ? metres / walkingPace
            : (route['duration'] as num?)?.toDouble() ?? 0,
        typicalDuration: walkingPace != null
            ? null
            : (route['duration_typical'] as num?)?.toDouble(),
        steps: steps,
        summary: (leg['summary'] as String?)?.trim() ?? '',
        congestion: congestion != null && congestion.length == points.length - 1
            ? [for (final c in congestion) _congestion(c)]
            : null,
      ),
    );
  }
  return routes;
}

/// The index of the route vertex at [location], searching forward from
/// [from]: a step's maneuver point is the first point of its geometry, and the
/// route's geometry is the steps' geometries end to end. Falls back to the
/// nearest vertex at or after [from].
int _vertexNear(List<LatLng> points, LatLng location, int from) {
  const distance = Distance(roundResult: false);
  var best = from;
  var bestMetres = double.infinity;
  for (var i = from; i < points.length; i++) {
    final d = distance.as(LengthUnit.Meter, points[i], location);
    if (d < 1) return i;
    if (d < bestMetres) {
      bestMetres = d;
      best = i;
    }
  }
  return best;
}
