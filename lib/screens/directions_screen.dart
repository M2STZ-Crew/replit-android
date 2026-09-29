import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../location/live_position.dart';
import '../location/route_progress.dart';
import '../theme.dart';
import '../widgets/map_tiles.dart';
import '../widgets/design.dart';
import '../widgets/you_are_here.dart';

Color _safeGreen = AppColors.ok;

/// A route, as the directions screen draws and measures it.
typedef RouteResult = ({List<LatLng> points, double metres});

/// Fetches a route between two points; null when no route could be found.
typedef RouteFetcher = Future<RouteResult?> Function(LatLng from, LatLng to);

/// Directions to an evacuation site, in the app, the way Google Maps walks
/// you there.
///
/// The route comes from OSRM's public demo server (free, no key). Once it is
/// drawn, the screen keeps up with the walker:
/// - the distance and minutes left count down as they move;
/// - the part already walked fades, and the part ahead stays bright;
/// - stray more than [offRouteMetres] from the route and a new one is fetched
///   from where they are (at most every 30 s);
/// - Start puts the map in follow-and-turn mode, so the way they face is up;
/// - within [arrivedWithinMetres] of the shelter it says they have arrived.
///
/// If no route can be found it falls back to a straight line and says so, so
/// the heading and distance still show.
class DirectionsScreen extends StatefulWidget {
  const DirectionsScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destName,
    this.originLat,
    this.originLng,
    this.fetchRoute,
  });

  final double destLat;
  final double destLng;
  final String destName;
  final double? originLat;
  final double? originLng;

  /// Where routes come from: OSRM when none is given. Tests give their own.
  final RouteFetcher? fetchRoute;

  /// Further than this from the route counts as off it.
  static const double offRouteMetres = 50;

  /// This close to the shelter counts as there.
  static const double arrivedWithinMetres = 30;

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  final MapFollow _follow = MapFollow();
  final MapController _map = MapController();
  final Distance _distance = const Distance();

  late final LatLng _dest = LatLng(widget.destLat, widget.destLng);
  late final RouteFetcher _fetch = widget.fetchRoute ?? _osrmRoute;

  LatLng? _origin;
  List<LatLng> _route = [];
  double? _routeMeters;
  bool _loading = true;
  bool _isApprox = false;

  /// Where the walker is, and where that puts them on the route.
  LatLng? _here;
  RouteProgress? _progress;

  bool _navigating = false;
  bool _arrived = false;
  bool _rerouting = false;
  int _offRouteFixes = 0;
  DateTime? _lastReroute;

  @override
  void initState() {
    super.initState();
    if (widget.originLat != null && widget.originLng != null) {
      _origin = LatLng(widget.originLat!, widget.originLng!);
    }
    LivePosition.instance.acquire();
    LivePosition.instance.here.addListener(_onMoved);
    _refineLocationThenRoute();
  }

  @override
  void dispose() {
    LivePosition.instance.here.removeListener(_onMoved);
    LivePosition.instance.release();
    _follow.dispose();
    super.dispose();
  }

  Future<void> _refineLocationThenRoute() async {
    // Best-effort: use the freshest GPS as the start point.
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition();
          _origin = LatLng(pos.latitude, pos.longitude);
          // Permission is settled: from here on the position is live.
          LivePosition.instance.offer(_origin!, accuracy: pos.accuracy);
        }
      }
    } catch (_) {
      // keep the passed origin
    }
    _origin ??= _dest;
    await _loadRoute(first: true);
  }

  static Future<RouteResult?> _osrmRoute(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final points = [
      for (final c in route['geometry']['coordinates'] as List<dynamic>)
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    final metres = (route['distance'] as num?)?.toDouble();
    if (points.length < 2 || metres == null) return null;
    return (points: points, metres: metres);
  }

  /// The route from [_origin]. The first time, it frames the whole route and
  /// falls back to a straight line if none is found; a re-route keeps the
  /// camera where it is, and keeps the old route if the new one fails.
  Future<void> _loadRoute({required bool first}) async {
    final origin = _origin!;
    setState(() => first ? _loading = true : _rerouting = true);
    RouteResult? found;
    try {
      found = await _fetch(origin, _dest);
    } catch (_) {
      found = null;
    }
    if (!mounted) return;
    if (found == null) {
      if (first) {
        _fallbackStraightLine();
      } else {
        setState(() => _rerouting = false);
      }
      return;
    }
    final route = found;
    setState(() {
      _route = route.points;
      _routeMeters = route.metres;
      _isApprox = false;
      _loading = false;
      _rerouting = false;
      _progress = _here == null ? null : RouteProgress.of(_route, _here!);
    });
    if (first) _fitRoute();
  }

  void _fallbackStraightLine() {
    if (!mounted) return;
    setState(() {
      _route = [_origin!, _dest];
      _routeMeters = _distance.as(LengthUnit.Meter, _origin!, _dest);
      _isApprox = true;
      _loading = false;
      _progress = _here == null ? null : RouteProgress.of(_route, _here!);
    });
    _fitRoute();
  }

  void _fitRoute() {
    if (_route.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: _route,
            padding: const EdgeInsets.fromLTRB(60, 120, 60, 260),
          ),
        );
      } catch (_) {
        // The map is not laid out yet; its initial fit already frames it.
      }
    });
  }

  /// The walker moved: count down, fade what is behind, and fetch a new route
  /// if they have left this one.
  void _onMoved() {
    final here = LivePosition.instance.here.value;
    if (here == null || !mounted) return;
    if (_route.length < 2) {
      _here = here;
      return;
    }
    final progress = RouteProgress.of(_route, here);
    final there =
        _distance.as(LengthUnit.Meter, here, _dest) <=
        DirectionsScreen.arrivedWithinMetres;
    setState(() {
      _here = here;
      _progress = progress;
      if (there) _arrived = true;
    });
    if (!_arrived && !_isApprox) _maybeReroute(here, progress);
  }

  /// Two fixes in a row off the route, and no re-route in the last 30 s: ask
  /// for a new one from here. One stray fix is GPS noise, not a wrong turn.
  void _maybeReroute(LatLng here, RouteProgress progress) {
    if (progress.offRouteMetres <= DirectionsScreen.offRouteMetres) {
      _offRouteFixes = 0;
      return;
    }
    _offRouteFixes++;
    final last = _lastReroute;
    if (_offRouteFixes < 2 ||
        _rerouting ||
        (last != null &&
            DateTime.now().difference(last) < const Duration(seconds: 30))) {
      return;
    }
    _offRouteFixes = 0;
    _lastReroute = DateTime.now();
    _origin = here;
    unawaited(_loadRoute(first: false));
  }

  void _startOrStop() {
    setState(() => _navigating = !_navigating);
    if (_navigating) {
      _follow.compass();
    } else {
      _follow.release();
      try {
        _map.rotate(0);
      } catch (_) {}
      _fitRoute();
    }
  }

  double get _remaining => _progress?.remainingMetres ?? _routeMeters ?? 0;

  int get _walkMinutes => (_remaining / 1.39 / 60).ceil(); // ~5 km/h

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    final progress = _progress;
    final ahead = progress == null ? _route : progress.ahead(_route);
    final behind = progress == null
        ? const <LatLng>[]
        : progress.behind(_route);
    return Scaffold(
      backgroundColor: context.pal.background,
      body: Stack(
        children: [
          if (origin != null)
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [origin, _dest],
                  padding: const EdgeInsets.fromLTRB(60, 120, 60, 260),
                ),
                interactionOptions: kMapGestures,
                onMapEvent: _follow.onMapEvent,
              ),
              children: [
                MapTiles.layer(light: context.pal.isLight),
                if (_route.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      // Walked: faded. Ahead: bright.
                      if (behind.length >= 2)
                        Polyline(
                          points: behind,
                          strokeWidth: 5,
                          color: context.pal.muted.withValues(alpha: 0.45),
                        ),
                      if (ahead.length >= 2)
                        Polyline(
                          points: ahead,
                          strokeWidth: 5,
                          color: context.pal.accent,
                          borderStrokeWidth: 1,
                          borderColor: Colors.black54,
                        ),
                    ],
                  ),
                MarkerLayer(
                  rotate: true,
                  markers: [
                    // You are the blue dot, which moves as you walk.
                    Marker(
                      point: _dest,
                      width: 36,
                      height: 36,
                      child: _destMarker(),
                    ),
                  ],
                ),
                YouAreHereLayer(follow: _follow),
                MapLocationButtons(
                  follow: _follow,
                  // Above the route card.
                  alignment: const Alignment(1, 0.2),
                ),
                MapTiles.attribution(),
              ],
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _backButton(),
                  const SizedBox(width: 12),
                  Expanded(child: _titlePill()),
                ],
              ),
            ),
          ),
          if (_loading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: context.pal.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
          Positioned(left: 16, right: 16, bottom: 16, child: _routeCard()),
        ],
      ),
    );
  }

  Widget _backButton() {
    return const BackWell();
  }

  Widget _titlePill() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: context.pal.surfaceSolid,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.pal.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.navigation, color: context.pal.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.destName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.pal.onBackground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _destMarker() => Container(
    decoration: BoxDecoration(
      color: _safeGreen,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x9922C55E), blurRadius: 12)],
    ),
    child: const Icon(Icons.home_outlined, color: Colors.white, size: 20),
  );

  /// What to tell the walker under the numbers, if anything.
  String? get _note {
    if (_rerouting) return 'Finding a new route from where you are…';
    final p = _progress;
    if (p != null &&
        !_isApprox &&
        p.offRouteMetres > DirectionsScreen.offRouteMetres) {
      return 'You are off the route. We will find you a new one.';
    }
    if (_isApprox) {
      // Said plainly: this is a straight line, not a route. Someone
      // evacuating needs to know the difference.
      return 'Direct line shown — live routing was unavailable. Follow main '
          'roads toward the marker.';
    }
    return null;
  }

  Widget _routeCard() {
    if (_arrived) {
      return Panel(
        padding: const EdgeInsets.all(20),
        color: context.pal.surfaceSolid.withValues(alpha: 0.94),
        border: _safeGreen,
        child: Row(
          children: [
            IconWell(tint: _safeGreen, asset: Art.evac, size: 40, glyph: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Eyebrow('You have arrived', color: _safeGreen),
                  const SizedBox(height: 6),
                  Text(
                    widget.destName.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.cardTitle.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final note = _note;
    return Panel(
      padding: const EdgeInsets.all(20),
      color: context.pal.surfaceSolid.withValues(alpha: 0.94),
      border: _safeGreen.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(tint: _safeGreen, asset: Art.evac, size: 40, glyph: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow(
                      _navigating ? 'On your way' : 'Route to safety',
                      color: _safeGreen,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.destName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.cardTitle.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.straighten,
                  _loading ? '—' : formatDistance(_remaining),
                  'to go',
                ),
              ),
              Expanded(
                child: _metric(
                  Icons.directions_walk,
                  _loading ? '—' : '~$_walkMinutes min',
                  'on foot',
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 14),
            Text(note, style: context.type.meta.copyWith(height: 16 / 11)),
          ],
          const SizedBox(height: 16),
          AppButton(
            _navigating ? 'Stop' : 'Start',
            height: 48,
            onPressed: _loading ? null : _startOrStop,
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.pal.accent, size: 19),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.numeral.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Eyebrow(label, color: context.pal.muted),
            ],
          ),
        ),
      ],
    );
  }
}
