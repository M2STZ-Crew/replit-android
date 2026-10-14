import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../widgets/map_tiles.dart';
import 'nav_route.dart';

/// By road in a vehicle (a responder or coordinator going to a fire), or on
/// foot (a resident walking to a shelter).
enum TravelMode { driving, walking }

/// A walker's pace, metres per second (about 5 km/h).
const double kWalkingPace = 1.39;

/// The routes for one trip, recommended first, and what they can be trusted
/// for.
class RouteSet {
  const RouteSet({
    required this.routes,
    required this.provider,
    required this.trafficAware,
  });

  final List<NavRoute> routes;

  /// Who computed them: `mapbox` or `osrm`.
  final String provider;

  /// True only when the provider timed them with live traffic (Mapbox
  /// `driving-traffic`). Nothing in the app may say "traffic" otherwise.
  final bool trafficAware;
}

/// No route could be had from any provider. [message] is safe to show.
class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Where routes come from (v1.12.9, Master Context / PRD v12 §4.9).
///
/// **Mapbox Directions** first, with the public token the app already ships
/// for its map tiles (`MAPBOX_TOKEN`; a `pk.` token, meant to be in the app).
/// For a vehicle it uses `driving-traffic`: live traffic in the times, up to
/// three routes (the recommended one and two alternatives), turn-by-turn steps
/// with street names, congestion per stretch of road, and `max_width` set to a
/// fire truck's width, so roads tagged narrower than the truck are left out
/// while ordinary residential streets stay in. When the phone is moving, its
/// heading goes with the request, so a new route starts the way the truck is
/// already going instead of with a U-turn.
///
/// **OSRM's public demo server** when Mapbox cannot answer (no token, quota,
/// network): real road routes, but free-flow speeds with no traffic, and a
/// server with no service guarantee. A set from it is never [RouteSet.trafficAware].
/// For a walker it times the route at walking pace, since it only routes cars.
///
/// Nothing is invented: when neither answers, [routes] throws.
class RoutingService {
  RoutingService({
    http.Client? client,
    String? mapboxToken,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _token = mapboxToken ?? MapTiles.token;

  final http.Client _client;
  final String _token;
  final Duration timeout;

  /// A fire truck's width in metres: roads tagged narrower are avoided.
  static const double truckWidthMetres = 2.5;

  /// Routes from [from] to [to]. [headingDeg] is the direction the phone is
  /// travelling, when it is moving.
  Future<RouteSet> routes(
    LatLng from,
    LatLng to, {
    required TravelMode mode,
    double? headingDeg,
    bool alternatives = true,
  }) async {
    if (_token.isNotEmpty) {
      try {
        return await _mapbox(from, to, mode, headingDeg, alternatives);
      } catch (_) {
        // Fall through to OSRM: a route without traffic beats no route.
      }
    }
    try {
      return await _osrm(from, to, mode, headingDeg, alternatives);
    } on TimeoutException {
      throw const RoutingException(
        'The routing service did not answer in time.',
      );
    } on RoutingException {
      rethrow;
    } catch (_) {
      throw const RoutingException('Could not reach the routing service.');
    }
  }

  Future<RouteSet> _mapbox(
    LatLng from,
    LatLng to,
    TravelMode mode,
    double? headingDeg,
    bool alternatives,
  ) async {
    final driving = mode == TravelMode.driving;
    final profile = driving ? 'driving-traffic' : 'walking';
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/$profile/${_coords(from, to)}',
      {
        'alternatives': '$alternatives',
        'steps': 'true',
        'overview': 'full',
        'geometries': 'geojson',
        'language': 'en',
        if (driving) 'annotations': 'congestion,duration',
        if (driving) 'max_width': '$truckWidthMetres',
        if (driving && headingDeg != null) 'bearings': _bearing(headingDeg),
        'access_token': _token,
      },
    );
    final routes = await _get(uri);
    return RouteSet(
      routes: routes,
      provider: 'mapbox',
      trafficAware: driving && routes.any((r) => r.hasTraffic),
    );
  }

  Future<RouteSet> _osrm(
    LatLng from,
    LatLng to,
    TravelMode mode,
    double? headingDeg,
    bool alternatives,
  ) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${_coords(from, to)}',
      {
        'alternatives': '$alternatives',
        'steps': 'true',
        'overview': 'full',
        'geometries': 'geojson',
        if (mode == TravelMode.driving && headingDeg != null)
          'bearings': _bearing(headingDeg),
      },
    );
    final routes = await _get(
      uri,
      walkingPace: mode == TravelMode.walking ? kWalkingPace : null,
    );
    return RouteSet(routes: routes, provider: 'osrm', trafficAware: false);
  }

  Future<List<NavRoute>> _get(Uri uri, {double? walkingPace}) async {
    final resp = await _client.get(uri).timeout(timeout);
    if (resp.statusCode != 200) {
      throw RoutingException('Routing failed (${resp.statusCode}).');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = parseRoutes(json, walkingPace: walkingPace);
    if (json['code'] != 'Ok' || routes.isEmpty) {
      throw const RoutingException('No road route was found.');
    }
    return routes;
  }

  static String _coords(LatLng from, LatLng to) =>
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';

  /// Start the way the phone is heading (±45°); any way into the destination.
  static String _bearing(double headingDeg) =>
      '${headingDeg.round() % 360},45;';
}

/// Driving time for an incident screen's ETA label, without a routing call
/// on every refresh: the last answer is reused while the start is within
/// 50 m of where it was asked, for the same destination, for up to a minute.
/// The incident screens refresh every few seconds, and Mapbox's free tier is
/// 100,000 requests a month.
class DriveTime {
  DriveTime({RoutingService? service}) : _service = service ?? RoutingService();

  final RoutingService _service;
  LatLng? _from;
  LatLng? _to;
  DateTime? _at;
  double? _seconds;

  /// Seconds by road from [from] to [to], or null when no route answered.
  Future<double?> seconds(LatLng from, LatLng to) async {
    const distance = Distance();
    final cached = _seconds;
    if (cached != null &&
        _to == to &&
        _from != null &&
        distance.as(LengthUnit.Meter, _from!, from) < 50 &&
        DateTime.now().difference(_at!) < const Duration(minutes: 1)) {
      return cached;
    }
    try {
      final set = await _service.routes(
        from,
        to,
        mode: TravelMode.driving,
        alternatives: false,
      );
      _from = from;
      _to = to;
      _at = DateTime.now();
      return _seconds = set.routes.first.duration;
    } catch (_) {
      return null;
    }
  }
}
