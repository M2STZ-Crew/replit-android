import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../location/live_position.dart';
import '../location/responder_tracker.dart';
import '../navigation/instructions.dart';
import '../navigation/nav_route.dart';
import '../navigation/navigation_controller.dart';
import '../navigation/routing_service.dart';
import '../navigation/voice_guide.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/coordinator_kit.dart';
import '../widgets/design.dart';
import '../widgets/lane_strip.dart';
import '../widgets/maneuver_arrow.dart';
import '../widgets/map_glass.dart';
import '../widgets/map_marker.dart';
import '../widgets/map_layers.dart';
import '../widgets/map_tiles.dart';
import '../widgets/you_are_here.dart';

Color _safeGreen = AppColors.ok;

/// Where the directions lead: a citizen walking to a shelter, or a responder
/// or coordinator driving to a fire.
enum DirectionsTo { shelter, fire }

/// What a run to a fire knows beyond the route (06 · C10): the Area, where
/// it is in words, and — for someone responding — how to say they are there.
class FireRun {
  const FireRun({
    required this.areaId,
    required this.areaName,
    this.place,
    this.markArrived,
    this.readArea,
  });

  final String areaId;

  /// "Area 1.2".
  final String areaName;

  /// "F. Victor Street, Barangay 76", when the place is known.
  final String? place;

  /// Marks this person on scene (POST /incidents/{id}/arrived). Null when
  /// they are not responding: only someone on the way may arrive.
  final Future<void> Function()? markArrived;

  /// Reads the Area (GET /areas/{id}) for its centre and status; tests give
  /// their own.
  final Future<Map<String, dynamic>> Function()? readArea;
}

/// Road directions from the phone's live position to a fire. The incident's
/// coordinates must exist — callers offer the button only when they do.
/// With [areaId] (or [run]), the destination follows the incident: as more
/// reports join it, its centre moves, and the route moves with it.
Future<void> openRouteToFire(
  BuildContext context, {
  required double lat,
  required double lng,
  required String name,
  String? areaId,
  FireRun? run,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DirectionsScreen(
        destLat: lat,
        destLng: lng,
        destName: name,
        to: DirectionsTo.fire,
        run: run,
        refreshDestination: areaId == null || run != null
            ? null
            : () => _areaCentre(areaId),
      ),
    ),
  );
}

/// The incident's current centre, or null when it could not be read.
Future<LatLng?> _areaCentre(String areaId) async {
  final area = await ApiClient().getArea(areaId);
  final lat = (area['centroid_lat'] as num?)?.toDouble();
  final lng = (area['centroid_lng'] as num?)?.toDouble();
  return lat == null || lng == null ? null : LatLng(lat, lng);
}

/// Turn-by-turn directions, as Google Maps gives them (v1.12.9): a citizen
/// to an evacuation site on foot, or a responder or coordinator to the fire
/// by road ([to]).
///
/// The screen draws and listens; the work is elsewhere — routes from
/// [RoutingService] (Mapbox `driving-traffic`, OSRM when Mapbox cannot
/// answer), progress, rerouting and voice cues from [NavigationController],
/// speech from [VoiceGuide], and one GPS stream at a fix a second from
/// [LivePosition].
///
/// - **Before Start**, every route the provider offered is on the map (the
///   chosen one in blue, the others grey) and in a list with its time,
///   distance and main road; the quickest is chosen, and tapping another
///   chooses it. Times say whether they include live traffic.
/// - **After Start**, the map follows heading-up with the dot low on the
///   screen, the next maneuver is in a banner ("250 m — Turn left onto Taft
///   Avenue"), the voice says it, and the time, distance and arrival clock
///   count down. Moving the map by hand stops the following; Re-centre
///   brings the navigation view back.
/// - **Off the route**, a new one is fetched from where they are, and the
///   banner, voice and numbers follow the new route. When routing fails the
///   last route stays and the card says so; it is never replaced by a route
///   that was not calculated.
///
/// The route starts from the phone's live GPS. For a fire there is no other
/// honest starting point: with location off or refused the screen says so and
/// offers to try again, and draws no route rather than inventing one. A shelter
/// route may start from where the citizen sent their report ([originLat]).
class DirectionsScreen extends StatefulWidget {
  const DirectionsScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destName,
    this.originLat,
    this.originLng,
    this.fetchRoute,
    this.refreshDestination,
    this.voice,
    this.to = DirectionsTo.shelter,
    this.run,
  });

  final double destLat;
  final double destLng;
  final String destName;
  final double? originLat;
  final double? originLng;

  /// Where routes come from: [RoutingService] when none is given. Tests
  /// give their own.
  final RouteFetch? fetchRoute;

  /// Reads the destination again, every [destinationEvery]; null keeps it
  /// fixed.
  final Future<LatLng?> Function()? refreshDestination;

  /// Speaks the instructions; tests give a silent one.
  final VoiceGuide? voice;

  /// A shelter on foot, or a fire by road.
  final DirectionsTo to;

  /// The Area being driven to, when there is one.
  final FireRun? run;

  /// This close to a shelter counts as there.
  static const double arrivedWithinMetres = 30;

  /// This close to a fire counts as there: the server's On scene radius.
  static const double atTheFireWithinMetres = 100;

  /// How often the incident's centre is read again while the screen is open.
  static const Duration destinationEvery = Duration(seconds: 30);

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  final MapController _map = MapController();
  final StreamController<LocationMarkerPosition?> _dot =
      StreamController.broadcast();
  final StreamController<double?> _travel = StreamController.broadcast();
  late final MapFollow _follow = MapFollow(
    positions: _dot.stream,
    headings: hybridHeadings(_travel.stream),
  );
  late final VoiceGuide _voice = widget.voice ?? VoiceGuide();
  late final NavigationController _nav;
  StreamSubscription<NavDisplay>? _displaySub;
  StreamSubscription<String>? _speechSub;
  Timer? _tick;
  Timer? _destinationTimer;

  LatLng? _origin;

  /// No GPS and no other honest starting point: nothing to route from.
  bool _noLocation = false;
  bool _framed = false;

  /// The Area's status, as last read ([FireRun]).
  String? _areaStatus;
  bool _arriving = false;

  /// The run reached the fire and that has been acted on, once.
  bool _arrivalHandled = false;

  /// Water layers drawn while driving (the Map layers button).
  final Set<String> _water = {};
  final Map<String, List<LatLng>> _waterPoints = {};

  bool get _toFire => widget.to == DirectionsTo.fire;

  TravelMode get _mode => _toFire ? TravelMode.driving : TravelMode.walking;

  @override
  void initState() {
    super.initState();
    final service = RoutingService();
    _nav = NavigationController(
      destination: LatLng(widget.destLat, widget.destLng),
      mode: _mode,
      destinationName: _toFire ? 'the fire' : widget.destName,
      arrivedWithinMetres: _toFire
          ? DirectionsScreen.atTheFireWithinMetres
          : DirectionsScreen.arrivedWithinMetres,
      fetch:
          widget.fetchRoute ??
          (from, to, {headingDeg}) =>
              service.routes(from, to, mode: _mode, headingDeg: headingDeg),
    )..addListener(_changed);
    _displaySub = _nav.displays.listen((d) {
      _dot.add(
        LocationMarkerPosition(
          latitude: d.point.latitude,
          longitude: d.point.longitude,
          accuracy: d.accuracy ?? double.nan,
        ),
      );
      _travel.add(d.travelHeadingDeg);
    });
    _speechSub = _nav.announcements.listen((text) => _voice.speak(text));
    unawaited(_voice.load());
    if (widget.originLat != null && widget.originLng != null) {
      _origin = LatLng(widget.originLat!, widget.originLng!);
    }
    LivePosition.instance.acquire(precise: true);
    LivePosition.instance.fix.addListener(_onFix);
    // The arrival clock moves on while standing still; so does "no GPS".
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
    if (widget.run != null) unawaited(_refreshDestination());
    if (widget.refreshDestination != null || widget.run != null) {
      _destinationTimer = Timer.periodic(
        DirectionsScreen.destinationEvery,
        (_) => _refreshDestination(),
      );
    }
    _refineLocationThenRoute();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _destinationTimer?.cancel();
    LivePosition.instance.fix.removeListener(_onFix);
    LivePosition.instance.release(precise: true);
    unawaited(_displaySub?.cancel());
    unawaited(_speechSub?.cancel());
    unawaited(_voice.stop());
    _nav
      ..removeListener(_changed)
      ..dispose();
    _follow.dispose();
    unawaited(_dot.close());
    unawaited(_travel.close());
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (!_framed && _nav.routes.isNotEmpty) {
      _framed = true;
      _fitRoute();
    }
    if (_toFire && _nav.arrived && !_arrivalHandled) {
      _arrivalHandled = true;
      unawaited(_reachedTheFire());
    }
  }

  /// Within reach of the fire: navigation ends there, and someone responding
  /// is marked on scene without having to press anything — the server's own
  /// GPS check may beat this to it, which counts the same.
  Future<void> _reachedTheFire() async {
    if (_nav.navigating) _nav.setNavigating(false);
    _follow.release();
    if (widget.run?.markArrived != null && _areaStatus != 'arrived') {
      await _markArrived();
    }
  }

  void _onFix() {
    final fix = LivePosition.instance.fix.value;
    if (fix != null) _nav.onFix(fix);
  }

  Future<void> _refineLocationThenRoute() async {
    if (_noLocation) setState(() => _noLocation = false);
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
      // keep the passed origin, if there is one
    }
    if (!mounted) return;
    if (_origin == null) {
      // Never route from a made-up point: say what is missing instead.
      setState(() => _noLocation = true);
      return;
    }
    if (LivePosition.instance.fix.value == null) {
      LivePosition.instance.offer(_origin!);
    }
    await _nav.start(_origin!);
  }

  Future<void> _refreshDestination() async {
    try {
      final run = widget.run;
      LatLng? to;
      if (run != null) {
        // One read for both: where the Area is now, and how far it has got.
        final area =
            await (run.readArea ?? () => ApiClient().getArea(run.areaId))();
        final status = area['status'] as String?;
        if (mounted && status != null && status != _areaStatus) {
          setState(() => _areaStatus = status);
        }
        final lat = (area['centroid_lat'] as num?)?.toDouble();
        final lng = (area['centroid_lng'] as num?)?.toDouble();
        to = lat == null || lng == null ? null : LatLng(lat, lng);
      } else {
        to = await widget.refreshDestination!();
      }
      if (to == null || !mounted) return;
      final moved = metresBetween(to, _nav.destination);
      if (moved > 30) await _nav.setDestination(to);
    } catch (_) {
      // Offline: keep going to where the incident was.
    }
  }

  void _fitRoute() {
    final route = _nav.route;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: [...route.points, _nav.destination],
            padding: _framePadding,
          ),
        );
      } catch (_) {
        // The map is not laid out yet; its initial fit already frames it.
      }
    });
  }

  /// Room the route is framed in: clear of the header and of whatever card
  /// or sheet is over the bottom of the map.
  EdgeInsets get _framePadding => _choosingFireRoute
      ? EdgeInsets.fromLTRB(
          48,
          120,
          48,
          MediaQuery.sizeOf(context).height * 0.6 + 16,
        )
      : const EdgeInsets.fromLTRB(60, 120, 60, 320);

  /// Before Start on the way to a fire: the Choose a route sheet (06 · C09),
  /// shared by the responder and the coordinator.
  bool get _choosingFireRoute =>
      _toFire && !_noLocation && !_nav.navigating && !_nav.arrived;

  void _startOrStop() {
    final on = !_nav.navigating;
    _nav.setNavigating(on);
    if (on) {
      _follow.navigate();
    } else {
      unawaited(_voice.stop());
      _follow.release();
      try {
        _map.rotate(0);
      } catch (_) {}
      _fitRoute();
    }
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    final navigating = _nav.navigating && !_nav.arrived;
    final banner = navigating ? _banner() : null;
    return Scaffold(
      backgroundColor: context.pal.background,
      body: Stack(
        children: [
          if (origin != null || _noLocation)
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _nav.destination,
                initialZoom: 16,
                initialCameraFit: origin == null
                    ? null
                    : CameraFit.coordinates(
                        coordinates: [origin, _nav.destination],
                        padding: _framePadding,
                      ),
                backgroundColor: context.pal.background,
                interactionOptions: kMapGestures,
                onMapEvent: _follow.onMapEvent,
              ),
              children: [
                MapTiles.layer(light: context.pal.isLight),
                // The fire's Area radius, under the routes and markers.
                if (_toFire)
                  CircleLayer(
                    circles: [
                      MapAreas.incidentRadius(
                        context.pal,
                        _nav.destination,
                        metres: kAreaRadiusMetres,
                      ),
                    ],
                  ),
                if (_nav.routes.isNotEmpty) PolylineLayer(polylines: _lines()),
                MarkerLayer(
                  rotate: true,
                  markers: [
                    for (final key in _water)
                      for (final p in _waterPoints[key] ?? const <LatLng>[])
                        Marker(
                          point: p,
                          width: MapMarker.target,
                          height: MapMarker.target,
                          child: MapMarker(
                            kind: _waterKind(key),
                            label: _waterKind(key).noun,
                          ),
                        ),
                    Marker(
                      point: _nav.destination,
                      width: _toFire ? MapMarker.target : 36,
                      height: _toFire ? MapMarker.target : 36,
                      child: _toFire
                          ? MapMarker(
                              kind: MapMarkerKind.incident,
                              label: widget.destName,
                              selected: true,
                            )
                          : _destMarker(),
                    ),
                  ],
                ),
                YouAreHereLayer(follow: _follow, navigating: navigating),
                // Choosing a route, the sheet covers where these sit; on
                // the run, the banner's own controls take their place.
                if (!_toFire || _noLocation)
                  MapLocationButtons(
                    follow: _follow,
                    alignment: const Alignment(1, -0.1),
                  ),
                MapTiles.attribution(),
              ],
            ),
          if (_choosingFireRoute) ...[
            // The top veil keeps the status bar readable over the map.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 120,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        context.pal.background.withValues(alpha: 0.92),
                        context.pal.background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _GlassBack(),
              ),
            ),
          ] else if (_onFireRun)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?banner,
                    if (banner == null) const _GlassBack(),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _rotationButton(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _MapControl(
                        icon: AppIcons.layers,
                        label: 'Map layers',
                        onTap: _pickLayers,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    banner ??
                    Row(
                      children: [
                        const BackWell(),
                        const SizedBox(width: 12),
                        Expanded(child: _titlePill()),
                      ],
                    ),
              ),
            ),
          if (_nav.loading)
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
          if (_choosingFireRoute)
            Positioned(left: 0, right: 0, bottom: 0, child: _chooseRouteSheet())
          else if (_onFireRun)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (navigating)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _recentre(),
                    ),
                  _runPanel(),
                ],
              ),
            )
          else
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [if (navigating) _recentre(), _routeCard()],
              ),
            ),
        ],
      ),
    );
  }

  /// The routes on the map: alternatives grey and underneath, the chosen one
  /// in blue on top — walked part faded, live traffic coloured over the part
  /// ahead. Grey means "another route", never traffic.
  List<Polyline> _lines() {
    final routes = _nav.routes;
    final active = _nav.route!;
    final p = _nav.progress;
    // To a fire (06 · C09) the chosen route is coral and the others dotted;
    // to a shelter the chosen one is blue and the others grey.
    final chosenColour = _toFire ? context.pal.accent : context.pal.info;
    final lines = <Polyline>[
      for (var i = 0; i < routes.length; i++)
        if (i != _nav.active && !routes[i].approximate)
          _toFire
              ? Polyline(
                  points: routes[i].points,
                  strokeWidth: 4,
                  color: context.pal.textSoft.withValues(alpha: 0.8),
                  pattern: const StrokePattern.dotted(spacingFactor: 2),
                )
              : Polyline(
                  points: routes[i].points,
                  strokeWidth: 5,
                  color: context.pal.muted.withValues(alpha: 0.6),
                  borderStrokeWidth: 1,
                  borderColor: Colors.black38,
                ),
    ];
    final seg = p == null ? 0 : _segmentAt(active, p.along);
    final behind = p == null
        ? const <LatLng>[]
        : [...active.points.sublist(0, seg + 1), _pointAt(active, p.along)];
    final ahead = p == null
        ? active.points
        : [_pointAt(active, p.along), ...active.points.sublist(seg + 1)];
    if (behind.length >= 2) {
      lines.add(
        Polyline(
          points: behind,
          strokeWidth: 6,
          color: context.pal.muted.withValues(alpha: 0.45),
        ),
      );
    }
    if (ahead.length >= 2) {
      lines.add(
        Polyline(
          points: ahead,
          strokeWidth: 6,
          color: chosenColour,
          borderStrokeWidth: 1.5,
          borderColor: Colors.black54,
          pattern: active.approximate
              ? StrokePattern.dashed(segments: const [12, 8])
              : const StrokePattern.solid(),
        ),
      );
    }
    lines.addAll(_traffic(active, seg));
    return lines;
  }

  /// Runs of slow, heavy and severe traffic on the part still ahead.
  List<Polyline> _traffic(NavRoute route, int from) {
    final levels = route.congestion;
    if (levels == null) return const [];
    final out = <Polyline>[];
    var i = from;
    while (i < levels.length) {
      final level = levels[i];
      final colour = _trafficColour(level);
      if (colour == null) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < levels.length && levels[j + 1] == level) {
        j++;
      }
      out.add(
        Polyline(
          points: route.points.sublist(i, j + 2),
          strokeWidth: 6,
          color: colour,
        ),
      );
      i = j + 1;
    }
    return out;
  }

  Color? _trafficColour(Congestion level) => switch (level) {
    Congestion.moderate => context.pal.warn,
    Congestion.heavy => context.pal.live,
    Congestion.severe => const Color(0xFF8E1B1B),
    _ => null,
  };

  int _segmentAt(NavRoute route, double along) {
    var seg = 0;
    while (seg + 2 < route.along.length && route.along[seg + 1] <= along) {
      seg++;
    }
    return seg;
  }

  LatLng _pointAt(NavRoute route, double along) {
    final seg = _segmentAt(route, along);
    final a = route.points[seg];
    final b = route.points[seg + 1];
    final len = route.along[seg + 1] - route.along[seg];
    final t = len <= 0
        ? 0.0
        : ((along - route.along[seg]) / len).clamp(0.0, 1.0);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  // ----------------------------------------------------------- banner ---
  /// The next maneuver, Google Maps style, or null when there is none to
  /// show (a straight line has no turns).
  Widget? _banner() {
    final route = _nav.route;
    final p = _nav.progress;
    if (route == null || p == null || p.nextStep == null) return null;
    final step = route.steps[p.nextStep!];
    final dest = _toFire ? 'the fire' : widget.destName;
    if (_toFire) return _fireBanner(route, p.nextStep!, p.metresToNext, dest);
    // A second maneuver close behind the first is worth knowing now.
    final after = p.nextStep! + 1 < route.steps.length
        ? route.steps[p.nextStep! + 1]
        : null;
    final soon = after != null && after.at - step.at <= 100;
    return Semantics(
      liveRegion: true,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        color: context.pal.info,
        border: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ManeuverArrow(type: step.type, modifier: step.modifier),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bannerDistance(p.metresToNext),
                        key: const ValueKey('maneuver-distance'),
                        style: context.type.numeral.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        instructionFor(step, destination: dest),
                        key: const ValueKey('maneuver-text'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.label.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (soon) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Then',
                    style: context.type.meta.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  ManeuverArrow(
                    type: after.type,
                    modifier: after.modifier,
                    size: 20,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      instructionFor(after, destination: dest),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.meta.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Back to the navigation view after looking around the map by hand.
  Widget _recentre() {
    return ListenableBuilder(
      listenable: _follow,
      builder: (context, _) {
        if (_follow.mode == FollowMode.compass) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            button: true,
            label: 'Re-centre',
            excludeSemantics: true,
            child: Material(
              color: context.pal.surfaceSolid,
              shape: StadiumBorder(side: BorderSide(color: context.pal.line)),
              child: InkWell(
                key: const ValueKey('recentre'),
                customBorder: const StadiumBorder(),
                onTap: _follow.navigate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.navigation,
                        size: 18,
                        color: context.pal.info,
                      ),
                      const SizedBox(width: 8),
                      Text('Re-centre', style: context.type.label),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
          Icon(AppIcons.navigation, color: context.pal.accent, size: 16),
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
      color: _toFire ? context.pal.live : _safeGreen,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(
          color: (_toFire ? context.pal.live : _safeGreen).withValues(
            alpha: 0.6,
          ),
          blurRadius: 12,
        ),
      ],
    ),
    child: Icon(
      _toFire ? AppIcons.localFireDepartment : AppIcons.home,
      color: Colors.white,
      size: 20,
    ),
  );

  Color get _tone => _toFire ? context.pal.live : _safeGreen;

  Widget get _destIcon => _toFire
      ? IconWell(
          tint: context.pal.live,
          icon: AppIcons.localFireDepartment,
          size: 40,
          glyph: 20,
        )
      : IconWell(tint: _safeGreen, asset: Art.evac, size: 40, glyph: 20);

  // ------------------------------------------------------------- card ---
  /// What to tell them under the numbers, if anything: most urgent first.
  String? get _note {
    if (_nav.rerouting) return 'Finding a new route from where you are…';
    final problem = _nav.problem;
    if (problem != null) return problem;
    final route = _nav.route;
    if (route != null && route.approximate) {
      // Said plainly: this is a straight line, not a route. Someone going to
      // a fire or a shelter needs to know the difference.
      return 'Direct line shown — live routing was unavailable. Follow main '
          'roads toward the marker.';
    }
    final fix = _nav.lastFix;
    if (_nav.navigating &&
        fix != null &&
        DateTime.now().difference(fix.time) > const Duration(seconds: 15)) {
      return 'Waiting for GPS — the position shown may be old.';
    }
    if (_nav.weakSignal) {
      return 'Weak GPS signal — your position may be off by '
          '${fix?.accuracy?.round() ?? 0} m.';
    }
    if (_nav.offRoute) {
      return 'You are off the route. We will find you a new one.';
    }
    return null;
  }

  /// Whether the times include traffic, said only when it is true — and its
  /// absence said too, for a drive.
  String? get _trafficNote {
    final route = _nav.route;
    if (!_toFire || route == null || route.approximate) return null;
    if (_nav.trafficAware) return 'Times include live traffic.';
    return 'No live traffic data — times are estimates.';
  }

  Widget _routeCard() {
    if (_noLocation) return _noLocationCard();
    if (_nav.arrived) return _arrivedCard();
    return _nav.navigating ? _navigatingCard() : _previewCard();
  }

  Widget _noLocationCard() {
    return Panel(
      padding: const EdgeInsets.all(20),
      color: context.pal.surfaceSolid.withValues(alpha: 0.94),
      border: context.pal.warn.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.locationOff, color: context.pal.warn),
              const SizedBox(width: 12),
              Expanded(
                child: Eyebrow('Your location is off', color: context.pal.warn),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'We cannot see where you are, so there is no route to draw. Turn '
            'on location and allow RepLiT to use it, then try again. The map '
            'shows where ${widget.destName} is.',
            style: context.type.bodySm,
          ),
          const SizedBox(height: 16),
          AppButton(
            'Try again',
            height: 48,
            onPressed: _refineLocationThenRoute,
          ),
        ],
      ),
    );
  }

  Widget _arrivedCard() {
    return Panel(
      padding: const EdgeInsets.all(20),
      color: context.pal.surfaceSolid.withValues(alpha: 0.94),
      border: _tone,
      child: Row(
        children: [
          _destIcon,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow(
                  _toFire ? 'You are at the fire' : 'You have arrived',
                  color: _tone,
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
    );
  }

  /// Before Start: where to, every route offered, and Start.
  Widget _previewCard() {
    final note = _note;
    final traffic = _trafficNote;
    final routes = _nav.routes;
    final real = routes.where((r) => !r.approximate).length;
    return Panel(
      padding: const EdgeInsets.all(20),
      color: context.pal.surfaceSolid.withValues(alpha: 0.94),
      border: _tone.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _destIcon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow(
                      _toFire ? 'Route to the fire' : 'Route to safety',
                      color: _tone,
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
          const SizedBox(height: 14),
          if (_nav.loading && routes.isEmpty)
            Text('Finding the best route…', style: context.type.meta)
          else if (real > 1)
            for (var i = 0; i < routes.length; i++) ...[
              _routeOption(i),
              if (i + 1 < routes.length) const SizedBox(height: 8),
            ]
          else
            _metrics(),
          if (traffic != null) ...[
            const SizedBox(height: 12),
            Text(traffic, style: context.type.meta),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note, style: context.type.meta.copyWith(height: 16 / 11)),
          ],
          const SizedBox(height: 16),
          AppButton(
            'Start',
            height: 48,
            onPressed: routes.isEmpty ? null : _startOrStop,
          ),
        ],
      ),
    );
  }

  /// One of the offered routes: time, distance, its main road; tap to take it.
  Widget _routeOption(int i) {
    final route = _nav.routes[i];
    final chosen = i == _nav.active;
    final via = route.summary.isEmpty ? '' : ' · via ${route.summary}';
    return Panel(
      key: ValueKey('route-$i'),
      onTap: () => _nav.select(i),
      radius: AppRadius.control,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: chosen ? context.pal.info.withValues(alpha: 0.12) : null,
      border: chosen ? context.pal.info : context.pal.line,
      child: Row(
        children: [
          Text(
            '~${_minutes(route.duration)} min',
            style: context.type.numeral.copyWith(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${formatDistance(route.length)}$via',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.meta,
            ),
          ),
          if (i == _nav.fastest) ...[
            const SizedBox(width: 8),
            Tag('Fastest', color: context.pal.ok),
          ],
        ],
      ),
    );
  }

  /// On the way to a fire, or there (06 · C10): the run panel replaces the
  /// card, the C10 banner the shelter one.
  bool get _onFireRun => _toFire && !_noLocation && !_choosingFireRoute;

  /// C10 — the next turn: its arrow on the brand plate, how far, the
  /// instruction in plain words (the same sentence the voice says), the one
  /// after it, and the voice toggle.
  Widget _fireBanner(NavRoute route, int next, double metres, String dest) {
    final step = route.steps[next];
    final after = next + 1 < route.steps.length ? route.steps[next + 1] : null;
    final then = after == null || after.type == 'arrive'
        ? null
        : instructionFor(after, destination: dest);
    // PRD v14 §4.9.2: the lanes for the next maneuver, under the instruction,
    // once it is close enough to change lanes for.
    final lanes = laneStripVisible(step, metres) ? step.lanes : null;
    final useLanes = lanes == null ? null : laneInstruction(step);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: MapGlass.strong(context),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: context.pal.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.wellFire,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  alignment: Alignment.center,
                  child: ManeuverArrow(
                    type: step.type,
                    modifier: step.modifier,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Read out as it changes; the voice toggle stays its own node.
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bannerDistance(metres),
                          key: const ValueKey('maneuver-distance'),
                          style: context.type.numeralXl,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          instructionFor(step, destination: dest),
                          key: const ValueKey('maneuver-text'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.instruction,
                        ),
                        if (then != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Then ${then[0].toLowerCase()}${then.substring(1)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.detail.copyWith(
                              color: context.pal.label,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: _voice.enabled,
                  builder: (context, on, _) => Semantics(
                    container: true,
                    button: true,
                    toggled: on,
                    label: on ? 'Voice guidance on' : 'Voice guidance off',
                    onTap: () => _voice.setEnabled(!on),
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => _voice.setEnabled(!on),
                      radius: 24,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          on ? AppIcons.volumeUp : AppIcons.volumeOff,
                          size: 24,
                          color: on
                              ? context.pal.onBackground
                              : context.pal.label,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (lanes != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  LaneStrip(lanes: lanes),
                  if (useLanes != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          useLanes,
                          key: const ValueKey('lane-text'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.detail.copyWith(
                            color: context.pal.textSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: MapGlass.blurs(context)
          ? BackdropFilter(filter: MapGlass.blur, child: body)
          : body,
    );
  }

  /// Heading-up while driving (the map turns with you); tap for north-up,
  /// and again to turn with you once more.
  Widget _rotationButton() {
    return ListenableBuilder(
      listenable: _follow,
      builder: (context, _) {
        final headingUp = _follow.mode == FollowMode.compass;
        return _MapControl(
          icon: headingUp ? AppIcons.explore : AppIcons.navigation,
          label: headingUp
              ? 'Heading up — tap for north up'
              : 'North up — tap for heading up',
          onTap: () {
            if (headingUp) {
              _follow.follow();
              try {
                _map.rotate(0);
              } catch (_) {}
            } else {
              _follow.navigate();
            }
          },
        );
      },
    );
  }

  static MapMarkerKind _waterKind(String key) => switch (key) {
    'hydrants' => MapMarkerKind.hydrant,
    'cisterns' => MapMarkerKind.cistern,
    _ => MapMarkerKind.water,
  };

  /// Map layers: the water a crew may need on arrival.
  Future<void> _pickLayers() async {
    const layers = [
      ('hydrants', 'Hydrants'),
      ('water', 'Bodies of water'),
      ('cisterns', 'Underground cisterns'),
    ];
    await showFrameSheet<void>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => SheetFrame(
          children: [
            const SheetTitles(
              eyebrow: 'Map layers',
              title: 'Water on the way',
              body: 'Show where a crew can draw water near the route.',
            ),
            const SizedBox(height: 16),
            for (final (key, label) in layers) ...[
              ListRow(
                title: label,
                leading: IconPlate(_waterKind(key).glyph),
                trailing: Switch(
                  value: _water.contains(key),
                  onChanged: (_) => set(() => _toggleWater(key)),
                ),
                onTap: () => set(() => _toggleWater(key)),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleWater(String key) {
    setState(() {
      if (!_water.remove(key)) _water.add(key);
    });
    if (_water.contains(key) && !_waterPoints.containsKey(key)) {
      unawaited(_loadWater(key));
    }
  }

  Future<void> _loadWater(String key) async {
    final api = ApiClient();
    try {
      final rows = await switch (key) {
        'hydrants' => api.getHydrants(),
        'cisterns' => api.getUndergroundCisterns(),
        _ => api.getBodiesOfWater(),
      };
      final points = [
        for (final r in rows.cast<Map<String, dynamic>>())
          if (r['latitude'] != null && r['longitude'] != null)
            LatLng(
              (r['latitude'] as num).toDouble(),
              (r['longitude'] as num).toDouble(),
            ),
      ];
      if (mounted) setState(() => _waterPoints[key] = points);
    } catch (_) {
      if (mounted) {
        setState(() => _water.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that layer.')),
        );
      }
    }
  }

  Future<void> _markArrived() async {
    final mark = widget.run?.markArrived;
    if (mark == null || _arriving) return;
    setState(() => _arriving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await mark();
      messenger.showSnackBar(
        const SnackBar(content: Text('You are on scene. Marked arrived.')),
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      // Already on scene — the GPS check or another unit got there first —
      // is the outcome wanted, not a failure.
      if (e.statusCode == 409) {
        await _refreshDestination();
        if (_areaStatus == 'arrived') {
          messenger.showSnackBar(
            const SnackBar(content: Text('You are on scene.')),
          );
          navigator.pop(true);
          return;
        }
      }
      if (mounted) setState(() => _arriving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) setState(() => _arriving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not mark arrived. Check signal.')),
      );
    }
  }

  /// C10 — the run panel: where the Area stands, whether this phone is
  /// sharing its location, where it is going, how far and how long, and
  /// Mark arrived for someone who is responding.
  Widget _runPanel() {
    final run = widget.run;
    final p = _nav.progress;
    final route = _nav.route;
    final metres = p?.remainingMetres ?? route?.length;
    final seconds = p?.remainingSeconds ?? route?.duration;
    final arrived = _nav.arrived;
    final onScene = _areaStatus == 'arrived';
    final notes = [?_note];
    final where = run == null ? '' : ' — ${run.areaName}';
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: MapGlass.strong(context),
        border: Border(top: BorderSide(color: context.pal.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          12 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF979797),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (run != null) LifecycleChip(_areaStatus ?? 'en_route'),
                const Spacer(),
                ValueListenableBuilder<String?>(
                  valueListenable: ResponderTracker.instance.sharingFor,
                  builder: (context, sharing, _) =>
                      run == null || sharing != run.areaId
                      ? const SizedBox.shrink()
                      : Row(
                          children: [
                            Icon(
                              AppIcons.podcasts,
                              size: 16,
                              color: context.pal.live,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sharing your location',
                              style: context.type.detail.copyWith(
                                color: context.pal.label,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              (run?.place ?? widget.destName).toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.headline,
            ),
            const SizedBox(height: 12),
            Text(
              arrived
                  ? 'You are at the fire$where'
                  : '${metres == null ? '—' : formatDistance(metres)}, about '
                        '${seconds == null ? '—' : _minutes(seconds)} min$where',
              style: context.type.body.copyWith(color: context.pal.textSoft),
            ),
            for (final n in notes) ...[
              const SizedBox(height: 8),
              Text(n, style: context.type.caption),
            ],
            const SizedBox(height: 12),
            if (run?.markArrived != null && !onScene) ...[
              AppButton(
                'Mark arrived',
                run: true,
                busy: _arriving,
                onPressed: _arriving ? null : _markArrived,
              ),
              if (_nav.navigating && !arrived)
                Center(child: TextLink('End navigation', onTap: _startOrStop)),
            ] else if (_nav.navigating && !arrived)
              AppButton.secondary('End navigation', onPressed: _startOrStop)
            else
              AppButton.secondary(
                'Done',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: MapGlass.blurs(context)
          ? BackdropFilter(filter: MapGlass.blur, child: body)
          : body,
    );
  }

  /// C09 — Choose a route: every road route to the fire, the chosen one
  /// marked, and Start navigation. On glass over the map, full width.
  Widget _chooseRouteSheet() {
    final routes = _nav.routes;
    final real = routes.where((r) => !r.approximate).length;
    final notes = [?_trafficNote, ?_note];
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: MapGlass.strong(context),
        border: Border(top: BorderSide(color: context.pal.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          12 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF979797),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text('Choose a route', style: context.type.sheetTitle),
            ),
            const SizedBox(height: 12),
            Text(
              _nav.provider == 'osrm'
                  ? 'To ${widget.destName}. These driving routes come from '
                        'the backup router, which cannot check street width.'
                  : 'To ${widget.destName}. Every route avoids footpaths and '
                        'streets too narrow for a truck.',
              style: context.type.body.copyWith(color: context.pal.textSoft),
            ),
            const SizedBox(height: 12),
            if (_nav.loading && routes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Finding the best route…',
                  style: context.type.bodySm,
                ),
              )
            else
              for (var i = 0; i < routes.length; i++)
                if (real <= 1 || !routes[i].approximate) ...[
                  _FireRouteOption(
                    key: ValueKey('route-$i'),
                    route: routes[i],
                    chosen: i == _nav.active,
                    badge: real < 2
                        ? null
                        : i == _nav.fastest
                        ? 'Fastest'
                        : i == _nav.shortest
                        ? 'Shortest'
                        : null,
                    onTap: () => _nav.select(i),
                  ),
                  const SizedBox(height: 12),
                ],
            for (final n in notes) ...[
              Text(n, style: context.type.caption),
              const SizedBox(height: 8),
            ],
            AppButton(
              'Start navigation',
              run: true,
              onPressed: routes.isEmpty ? null : _startOrStop,
            ),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: MapGlass.blurs(context)
          ? BackdropFilter(filter: MapGlass.blur, child: body)
          : body,
    );
  }

  /// Under way: time, distance and arrival; voice; Stop.
  Widget _navigatingCard() {
    final note = _note;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: context.pal.surfaceSolid.withValues(alpha: 0.94),
      border: _tone.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Eyebrow('On your way', color: _tone),
          const SizedBox(height: 12),
          _metrics(arrival: true),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note, style: context.type.meta.copyWith(height: 16 / 11)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _voice.enabled,
                builder: (context, on, _) => Semantics(
                  button: true,
                  toggled: on,
                  label: on ? 'Voice guidance on' : 'Voice guidance off',
                  excludeSemantics: true,
                  child: IconWellButton(
                    icon: AppIcons.volumeUp,
                    size: 48,
                    tint: on ? context.pal.info : context.pal.muted,
                    onTap: () => _voice.setEnabled(!on),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.secondary(
                  'Stop',
                  height: 48,
                  onPressed: _startOrStop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metrics({bool arrival = false}) {
    final p = _nav.progress;
    final route = _nav.route;
    final metres = p?.remainingMetres ?? route?.length;
    final seconds = p?.remainingSeconds ?? route?.duration;
    final eta = _nav.eta;
    return Row(
      children: [
        Expanded(
          child: _metric(
            AppIcons.straighten,
            metres == null ? '—' : formatDistance(metres),
            'to go',
          ),
        ),
        Expanded(
          child: _metric(
            _toFire ? AppIcons.directionsCar : AppIcons.directionsWalk,
            seconds == null ? '—' : '~${_minutes(seconds)} min',
            _toFire ? 'driving' : 'on foot',
          ),
        ),
        if (arrival)
          Expanded(
            child: _metric(
              AppIcons.schedule,
              eta == null ? '—' : _clock(eta),
              'arrive',
            ),
          ),
      ],
    );
  }

  static int _minutes(double seconds) => (seconds / 60).ceil();

  static String _clock(DateTime t) {
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';
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

/// One road route to the fire (Route option, 06 · C09): its time, distance
/// and the badge the provider's numbers earn it, with its main road under.
/// Radio behaviour; the whole card is the target.
class _FireRouteOption extends StatelessWidget {
  const _FireRouteOption({
    super.key,
    required this.route,
    required this.chosen,
    required this.onTap,
    this.badge,
  });

  final NavRoute route;
  final bool chosen;
  final VoidCallback onTap;

  /// "Fastest" or "Shortest" — facts the route numbers show, never a claim
  /// about safety.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final minutes = (route.duration / 60).ceil();
    final shape = BorderRadius.circular(AppRadius.card);
    final via = route.approximate
        ? 'Direct line — no road route'
        : route.summary.isEmpty
        ? 'By road'
        : 'Via ${route.summary}';
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: chosen,
      label:
          '$minutes min, ${formatDistance(route.length)}'
          '${badge == null ? '' : ', $badge'}, $via',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          highlightColor: pal.pressed,
          splashColor: pal.pressed,
          child: AnimatedContainer(
            duration: Motion.of(context).state,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: chosen ? pal.accent.withValues(alpha: 0.16) : pal.surface,
              borderRadius: shape,
              border: Border.all(
                color: chosen ? pal.accent : pal.line,
                width: chosen ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Ring(on: chosen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$minutes min',
                            style: context.type.numeralSm.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            formatDistance(route.length),
                            style: context.type.rowValue,
                          ),
                          if (badge != null)
                            Tag(badge!, color: pal.accentInk, dot: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(via, style: context.type.bodySm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The radio's 22px ring: inset and grey, or coral with a coral dot.
class _Ring extends StatelessWidget {
  const _Ring({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AnimatedContainer(
      duration: Motion.of(context).state,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: pal.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? pal.accent : pal.lineStrong,
          width: on ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: on
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: pal.accent,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// Back, as an Icon button over a map: glass and a blur, 48px.
class _GlassBack extends StatelessWidget {
  const _GlassBack();

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.control);
    final button = Material(
      color: MapGlass.glass(context),
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: context.pal.line),
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.chevronLeft,
            size: 24,
            color: context.pal.onBackground,
          ),
        ),
      ),
    );
    return Align(
      alignment: Alignment.topLeft,
      child: Semantics(
        button: true,
        label: 'Back',
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: shape,
          child: MapGlass.blurs(context)
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: button,
                )
              : button,
        ),
      ),
    );
  }
}

/// A 48px icon button over the map (Icon button, Overlay): glass and a blur.
class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.control);
    final button = Material(
      color: MapGlass.glass(context),
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: context.pal.line),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 24, color: context.pal.onBackground),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: shape,
        child: MapGlass.blurs(context)
            ? BackdropFilter(filter: MapGlass.blur, child: button)
            : button,
      ),
    );
  }
}
