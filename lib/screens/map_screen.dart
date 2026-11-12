import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/live_hub.dart';
import '../api/map_cache.dart';
import '../api/report_queue.dart';
import '../location/live_position.dart';
import '../models/hotline.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import '../widgets/drag_down_sheet.dart';
import '../widgets/map_glass.dart';
import '../widgets/map_layers.dart';
import '../widgets/map_marker.dart';
import '../widgets/map_tiles.dart';
import 'area_detail_screen.dart';
import '../widgets/you_are_here.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';
import '../updates/update_banner.dart';

/// Pasay City centre — the map's home view when the user's GPS is unavailable.
const LatLng _pasayCenter = LatLng(14.5378, 121.0014);

/// How far "near you" reaches in the areas sheet: the frame's "Within 1.5 km".
const double _nearMetres = 1500;

/// How long the map waits on the GPS for its first fix before saying it has
/// none: as long as the SOS screen waits (`SosLocation.freshLimit`).
const Duration _fixWait = Duration(seconds: 20);

// The panels over the map are Glass (chips, the place card) or Glass strong
// (the areas sheet, the offline card): see MapGlass for the rules.

/// One chip in the "Map layers" row, and the layer it switches.
/// What a layer is drawn in. A role rather than a swatch, so the light and
/// dark palettes each give it their own value.
enum _Tone { incident, shelter, hydrant, risk, water, cistern }

class _Layer {
  const _Layer(
    this.key,
    this.label,
    this.tone, {
    this.tag = '',
    this.icon,
    this.asset,
    this.latKey = 'latitude',
    this.lngKey = 'longitude',
  });

  /// Endpoint and cache slot: incidents, evac, risk, hydrants, water, cisterns.
  final String key;
  final String label;
  final _Tone tone;

  /// The marker a point of this layer is drawn as (04 · Map marker): every
  /// kind of water shares the one blue surface, as the WATER chip says.
  MapMarkerKind get markerKind => switch (tone) {
    _Tone.hydrant => MapMarkerKind.hydrant,
    _Tone.water => MapMarkerKind.water,
    _Tone.cistern => MapMarkerKind.cistern,
    _Tone.shelter => MapMarkerKind.shelter,
    _Tone.risk => MapMarkerKind.risk,
    _Tone.incident => MapMarkerKind.incident,
  };

  /// The shared legend tone (MapMarkerKind.tone), so this map and the staff
  /// maps draw each category in one colour.
  Color colour(AppPalette pal) => markerKind.tone(pal);

  /// The eyebrow on this layer's detail sheet.
  final String tag;
  final IconData? icon;
  final String? asset;
  final String latKey;
  final String lngKey;

  bool get isGis => key != 'incidents' && key != 'evac';
}

// Chip dots and marker edges are the Figma's own colours for each layer.
const _incidents = _Layer('incidents', 'Incidents', _Tone.incident);
const _shelters = _Layer(
  'evac',
  'Shelters',
  _Tone.shelter,
  tag: 'SHELTER',
  asset: Art.evac,
);
const _hydrants = _Layer(
  'hydrants',
  'Hydrants',
  _Tone.hydrant,
  tag: 'FIRE HYDRANT',
  asset: Art.hydrant,
);
const _risk = _Layer(
  'risk',
  'Risk zones',
  _Tone.risk,
  tag: 'RISK AREA',
  icon: AppIcons.warning,
  latKey: 'centroid_lat',
  lngKey: 'centroid_lng',
);
const _water = _Layer(
  'water',
  'Water',
  _Tone.water,
  tag: 'BODY OF WATER',
  icon: AppIcons.waves,
);
const _cisterns = _Layer(
  'cisterns',
  'Cisterns',
  _Tone.cistern,
  tag: 'UNDERGROUND CISTERN',
  icon: AppIcons.waterDamage,
);

List<_Layer> _layers = [
  _incidents,
  _shelters,
  _hydrants,
  _risk,
  _water,
  _cisterns,
];
List<_Layer> _gisLayers = [_risk, _hydrants, _water, _cisterns];

/// "04 Map" and "05 Map — offline queue" from the REPLIT-OVERHAUL Figma — the
/// citizen home.
///
/// Data sources are the citizen-readable endpoints only:
///  - GET /areas → active incident clusters, refreshed every 15 s.
///  - GET /map/evacuation-sites → shelters (outside-Pasay ones marked).
///  - GET /map/risk-zones, /hydrants, /bodies-of-water, /underground-cisterns
///    → the other §2.4 layers. Each is fetched when its chip is first turned
///    on, and all of them once a day in the background so they are on the
///    phone ([MapCache]) when the signal goes.
///
/// With no signal the areas sheet becomes "Saved on this phone": what is
/// queued ([ReportQueue]), whether the layers are cached, and that the
/// hotlines still dial. A queued report puts the "report waiting" card where
/// the layer chips were.
///
/// What the frame shows that is not drawn, and why: the incident kind
/// ("Structure fire") — an area carries no type, so it is named by its
/// designation; and a hospital marker — there is no hospital layer. Streets
/// come from the phone's own geocoder, and are left out when it has none.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.api, this.feed});

  /// Stands in for the server in tests.
  final ApiClient? api;

  /// Where live area changes come from: `map:areas` on the app's one socket
  /// when none is given. Tests give their own.
  final LiveFeed? feed;

  /// The server's channel for the live citizen map.
  static const String channel = 'map:areas';

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapFollow _follow = MapFollow();

  late final ApiClient _api = widget.api ?? ApiClient();
  final MapController _map = MapController();
  final ReportQueue _queue = ReportQueue.instance;

  /// Live area changes. With it up, a new incident or a status change is on
  /// the map within a second; the 15 s read below becomes a once-a-minute
  /// safety net for anything a dropped socket missed.
  late final LiveFeed _live = widget.feed ?? ChannelFeed(MapScreen.channel);
  StreamSubscription<Map<String, dynamic>>? _liveChanges;
  int _pollTicks = 0;

  Timer? _poll;
  bool _loading = true;

  /// The last /areas call could not reach the server.
  bool _offline = false;
  bool _retrying = false;

  /// A full read of GET /areas has come back. Until one has, an empty list
  /// means "not known yet", not "nothing active".
  bool _areasLoaded = false;

  final Set<String> _on = {'incidents', 'evac'};
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _evac = [];
  final Map<String, List<Map<String, dynamic>>> _gis = {};
  DateTime? _cacheSavedAt;

  LatLng? _myLoc;
  double? _accuracy;
  String? _street;

  /// The first fix is still being asked for. Until it answers, the areas
  /// sheet cannot say what is near, so it says it is checking.
  bool _locating = true;

  /// Why there is no fix, once the GPS has said it cannot give one.
  String? _locationProblem;

  /// Street names for nearby areas, by area id. A null entry means "asked,
  /// no answer" — the geocoder is not asked twice for the same area.
  final Map<String, String?> _areaStreets = {};

  bool get _isOffline =>
      _offline || (_queue.pending.value.isNotEmpty && _queue.offline.value);

  @override
  void initState() {
    super.initState();
    _queue.pending.addListener(_rebuild);
    _queue.offline.addListener(_rebuild);
    _queue.lastRejection.addListener(_onRejection);
    // Distances follow the resident as they move, not the fix the map opened
    // with.
    LivePosition.instance.acquire();
    LivePosition.instance.here.addListener(_onMoved);
    _liveChanges = _live.messages.listen(_onAreaChange);
    _live.live.addListener(_onLiveChanged);
    _live.start();
    _bootstrap();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _pollTick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _queue.pending.removeListener(_rebuild);
    _queue.offline.removeListener(_rebuild);
    _queue.lastRejection.removeListener(_onRejection);
    LivePosition.instance.here.removeListener(_onMoved);
    LivePosition.instance.release();
    _live.live.removeListener(_onLiveChanged);
    unawaited(_liveChanges?.cancel());
    // The screen closes only the feed it opened; one handed in belongs to
    // whoever handed it in.
    if (widget.feed == null) unawaited(_live.dispose());
    _follow.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onRejection() {
    final message = _queue.lastRejection.value;
    if (message == null) return;
    _queue.lastRejection.value = null;
    _toast(t('A saved report was turned down: {why}', {'why': message}));
  }

  // --------------------------------------------------------------- live ---
  void _pollTick() {
    _pollTicks++;
    if (!_live.live.value || _pollTicks % 4 == 0) unawaited(_loadAreas());
  }

  /// Just connected, or reconnected: whatever changed while the socket was
  /// down came with no message, so one full read catches up.
  void _onLiveChanged() {
    if (_live.live.value) unawaited(_loadAreas());
    _rebuild();
  }

  /// One area changed on the server: put it on the map, move it, or — when it
  /// is no longer live (fire out, closed, rejected, merged) — take it off.
  void _onAreaChange(Map<String, dynamic> message) {
    final area = message['area'];
    if (message['type'] != 'area' || area is! Map<String, dynamic>) return;
    if (!mounted) return;
    final id = area['id'];
    final keep =
        message['active'] != false &&
        area['centroid_lat'] != null &&
        area['centroid_lng'] != null;
    final at = _areas.indexWhere((a) => a['id'] == id);
    setState(() {
      if (!keep) {
        if (at >= 0) _areas = [..._areas]..removeAt(at);
      } else if (at >= 0) {
        _areas = [..._areas]..[at] = area;
      } else {
        // Newest first, as GET /areas lists them.
        _areas = [area, ..._areas];
      }
    });
    if (keep && at < 0) _lookUpAreaStreets();
  }

  // --------------------------------------------------------------- data ---
  Future<void> _bootstrap() async {
    unawaited(_queue.load());
    final savedAt = await MapCache.instance.savedAt();
    if (mounted) setState(() => _cacheSavedAt = savedAt);
    await Future.wait([_loadAreas(), _loadEvac()]);
    if (mounted) setState(() => _loading = false);
    unawaited(_refreshStaleLayers());
    await _locateQuietly(recenter: true);
  }

  Future<void> _loadAreas() async {
    try {
      final raw = await _api.getAreas();
      final areas = raw
          .cast<Map<String, dynamic>>()
          .where((a) => a['centroid_lat'] != null && a['centroid_lng'] != null)
          .toList();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _areasLoaded = true;
        _offline = false;
      });
      _lookUpAreaStreets();
      // The signal is back; do not make a queued report wait out its timer.
      if (_queue.pending.value.isNotEmpty) unawaited(_queue.flush());
    } on ApiException {
      // The server answered, so this is not "offline". Keep the last areas.
      if (mounted) setState(() => _offline = false);
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }
  }

  Future<void> _loadEvac() async {
    List<dynamic>? rows;
    try {
      rows = await _api.getEvacuationSites();
      unawaited(_save('evac', rows));
    } catch (_) {
      rows = await MapCache.instance.get('evac');
    }
    if (rows == null || !mounted) return;
    final located = _located(_shelters, rows);
    setState(() => _evac = located);
  }

  Future<void> _save(String layer, List<dynamic> rows) async {
    await MapCache.instance.put(layer, rows);
    final savedAt = await MapCache.instance.savedAt();
    if (mounted) setState(() => _cacheSavedAt = savedAt);
  }

  Future<List<dynamic>> _fetchGis(String key) => switch (key) {
    'risk' => _api.getRiskZones(),
    'hydrants' => _api.getHydrants(),
    'water' => _api.getBodiesOfWater(),
    _ => _api.getUndergroundCisterns(),
  };

  /// Rows the layer can place: a point, or (risk zones) a drawn area.
  List<Map<String, dynamic>> _located(_Layer layer, List<dynamic> rows) => rows
      .cast<Map<String, dynamic>>()
      .where(
        (r) =>
            (r[layer.latKey] != null && r[layer.lngKey] != null) ||
            (layer == _risk && r['area_geojson'] != null),
      )
      .toList();

  void _toggle(_Layer layer) {
    setState(() {
      if (!_on.remove(layer.key)) _on.add(layer.key);
    });
    if (_on.contains(layer.key) &&
        layer.isGis &&
        !_gis.containsKey(layer.key)) {
      _loadGis(layer);
    }
  }

  /// Show the saved copy at once, then replace it with a fresh one.
  Future<void> _loadGis(_Layer layer) async {
    final cached = await MapCache.instance.get(layer.key);
    if (cached != null && mounted && !_gis.containsKey(layer.key)) {
      setState(() => _gis[layer.key] = _located(layer, cached));
    }
    try {
      final rows = await _fetchGis(layer.key);
      unawaited(_save(layer.key, rows));
      if (mounted) setState(() => _gis[layer.key] = _located(layer, rows));
    } catch (_) {
      if (!mounted || _gis.containsKey(layer.key)) return;
      setState(() => _on.remove(layer.key));
      _toast(
        t('Could not load {layer}.', {'layer': t(layer.label).toLowerCase()}),
      );
    }
  }

  /// Once a day, fetch every reference layer — chip on or not — so it is on
  /// the phone before the signal is gone rather than after.
  Future<void> _refreshStaleLayers() async {
    if (_offline) return;
    final stale = await MapCache.instance.stale();
    for (final layer in _gisLayers) {
      if (!stale.contains(layer.key)) continue;
      try {
        final rows = await _fetchGis(layer.key);
        await _save(layer.key, rows);
        if (mounted) setState(() => _gis[layer.key] = _located(layer, rows));
      } catch (_) {
        return; // offline or failing — try again next time the map opens
      }
    }
  }

  // ----------------------------------------------------------- location ---
  /// Best-effort GPS. Never blocks the map; on success optionally recentres.
  /// While it asks, [_locating] keeps the areas sheet on "checking"; when it
  /// cannot have a fix, [_locationProblem] says why.
  Future<void> _locateQuietly({required bool recenter}) async {
    if (mounted && _myLoc == null) {
      setState(() {
        _locating = true;
        _locationProblem = null;
      });
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _noFix(t('Location is off. Turn it on to see active areas near you.'));
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _noFix(
          t(
            'Location permission is off. Allow it to see active areas near you.',
          ),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: _fixWait),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _myLoc = here;
        _accuracy = pos.accuracy;
        _locating = false;
        _locationProblem = null;
      });
      // Also where the live stream starts, now that permission is settled.
      LivePosition.instance.offer(here, accuracy: pos.accuracy);
      if (recenter) _map.move(here, 15.2);
      _streetFrom = here;
      _street = await _streetAt(here);
      if (mounted) setState(() {});
      _lookUpAreaStreets();
    } on PermissionRequestInProgressException {
      // Another screen is asking this moment (the push set-up does at sign-
      // in). Ask again once it has its answer, rather than call it refused.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _myLoc == null) {
          unawaited(_locateQuietly(recenter: recenter));
        }
      });
    } catch (_) {
      // ignore — map stays on its current view
      _noFix(
        t('Could not find your location yet. Move near a window or outdoors.'),
      );
    }
  }

  /// No fix to measure from: the sheet says why, unless one arrived some
  /// other way in the meantime (the position stream, [_onMoved]).
  void _noFix(String why) {
    if (!mounted || _myLoc != null) return;
    setState(() {
      _locating = false;
      _locationProblem = why;
    });
  }

  /// Where [_street] was looked up, so it is looked up again only after a
  /// real walk — the geocoder is a network call, not something to run on
  /// every ten metres.
  LatLng? _streetFrom;

  /// The resident moved: every distance on the map is measured again.
  void _onMoved() {
    final here = LivePosition.instance.here.value;
    if (here == null || !mounted) return;
    setState(() {
      _myLoc = here;
      _accuracy = LivePosition.instance.accuracy ?? _accuracy;
      _locating = false;
      _locationProblem = null;
    });
    final from = _streetFrom;
    if (from != null && metresBetween(from, here) > 150) {
      _streetFrom = here;
      _streetAt(here).then((street) {
        if (street != null && mounted) setState(() => _street = street);
      });
      _lookUpAreaStreets();
    }
  }

  /// The location card: bring the map to you and keep it with you as you
  /// move, as Google Maps' location button does. Dragging the map lets go.
  void _recenter() {
    if (_myLoc != null) {
      _follow.follow();
    } else {
      _locateQuietly(recenter: true);
    }
  }

  /// The phone's geocoder, reduced to a street name. Android answers with a
  /// Plus Code ("8Q7X+2F") where it knows no street; that is not a street.
  static Future<String?> _streetAt(LatLng p) async {
    try {
      final marks = await geo.placemarkFromCoordinates(p.latitude, p.longitude);
      for (final m in marks) {
        for (final s in [m.thoroughfare, m.street]) {
          final v = s?.trim() ?? '';
          if (v.isNotEmpty && !v.contains('+')) return v;
        }
      }
    } catch (_) {
      // No geocoder, or no signal for it.
    }
    return null;
  }

  void _lookUpAreaStreets() {
    for (final entry in _nearbyAreas()) {
      final id = entry.area['id'] as String?;
      if (id == null || _areaStreets.containsKey(id)) continue;
      _areaStreets[id] = null;
      final point = LatLng(
        (entry.area['centroid_lat'] as num).toDouble(),
        (entry.area['centroid_lng'] as num).toDouble(),
      );
      _streetAt(point).then((street) {
        if (street != null && mounted) {
          setState(() => _areaStreets[id] = street);
        }
      });
    }
  }

  /// Great-circle metres. Distances are measured on the phone because no
  /// endpoint takes a radius — the server returns the city, the phone measures.
  double? _metresTo(double lat, double lng) {
    final me = _myLoc;
    if (me == null) return null;
    return const Distance().as(LengthUnit.Meter, me, LatLng(lat, lng));
  }

  static String _formatDistance(double metres) => formatDistance(metres);

  /// Areas within 1.5 km, nearest first. With no fix nothing can be measured,
  /// so nothing is called near. (Before v1.12.23 the newest two stood in, and
  /// a resident signing in saw two Areas anywhere in the city listed as
  /// "near you" until the GPS answered.) The map still draws every Area.
  List<({Map<String, dynamic> area, double metres})> _nearbyAreas() {
    final me = _myLoc;
    if (me == null) return const [];
    final measured = [
      for (final a in _areas)
        (
          area: a,
          metres: metresBetween(
            me,
            LatLng(
              (a['centroid_lat'] as num).toDouble(),
              (a['centroid_lng'] as num).toDouble(),
            ),
          ),
        ),
    ];
    return (measured.where((e) => e.metres <= _nearMetres).toList()
          ..sort((x, y) => x.metres.compareTo(y.metres)))
        .take(2)
        .toList();
  }

  Map<String, dynamic>? _nearestOpenShelter() {
    final open = _evac.where((s) => s['is_active'] != false).toList();
    if (open.isEmpty) return null;
    if (_myLoc == null) return open.first;
    double d(Map<String, dynamic> s) =>
        _metresTo(
          (s['latitude'] as num).toDouble(),
          (s['longitude'] as num).toDouble(),
        ) ??
        double.infinity;
    open.sort((x, y) => d(x).compareTo(d(y)));
    return open.first;
  }

  // ------------------------------------------------------ offline queue ---
  Future<void> _retryNow() async {
    setState(() => _retrying = true);
    final sent = await _queue.flush();
    if (!mounted) return;
    setState(() => _retrying = false);
    if (sent > 0) {
      unawaited(_loadAreas());
    } else if (_queue.pending.value.isNotEmpty) {
      _toast(
        _queue.offline.value
            ? t('Still no signal. It keeps trying every 15 seconds.')
            : t(
                'The server is not taking it yet. It keeps trying every 15 seconds.',
              ),
      );
    }
  }

  Future<void> _call911() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '911'));
    } catch (_) {
      _toast(t('Could not open the dialler. Dial 911 directly.'));
    }
  }

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      // The map runs under the tab bar, and the SOS disc sits over it.
      extendBody: true,
      bottomNavigationBar: const AppNavBar(active: AppTab.map),
      body: BackdropGroup(
        child: Builder(
          // Under extendBody the body's bottom padding is the bar's height —
          // read here, below the Scaffold, not from the State's context.
          builder: (context) {
            final clearance = MediaQuery.paddingOf(context).bottom;
            return Stack(
              children: [
                Positioned.fill(child: _mapLayer()),
                const Positioned.fill(child: IgnorePointer(child: _Vignette())),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _sheet(clearance),
                ),
                Positioned(top: 0, left: 0, right: 0, child: _topControls()),
                if (_loading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- map ---
  Widget _mapLayer() {
    // The credit line lives in the areas sheet: the sheet covers the corner
    // where flutter_map would put it, and the credit is a licence condition.
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _pasayCenter,
        initialZoom: 13,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: context.pal.background,
        interactionOptions: kMapGestures,
        onMapEvent: _follow.onMapEvent,
      ),
      children: [
        MapTiles.layer(light: context.pal.isLight),
        if (_on.contains('risk'))
          PolygonLayer(
            polygons: [
              for (final r in _gis['risk'] ?? const <Map<String, dynamic>>[])
                ...MapAreas.riskZone(context.pal, r['area_geojson']),
            ],
          ),
        MarkerLayer(rotate: true, markers: _markers()),
        YouAreHereLayer(follow: _follow),
        MapLocationButtons(
          follow: _follow,
          alignment: const Alignment(1, -0.1),
        ),
      ],
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];

    if (_on.contains('evac')) {
      for (final s in _evac) {
        markers.add(
          Marker(
            point: LatLng(
              (s['latitude'] as num).toDouble(),
              (s['longitude'] as num).toDouble(),
            ),
            width: MapMarker.target,
            height: MapMarker.target,
            child: MapMarker(
              kind: MapMarkerKind.shelter,
              label: (s['name'] as String?) ?? t('Evacuation site'),
              // A shelter that is not open still marks the place, dimmed.
              dimmed: s['is_active'] == false,
              badge: s['outside_pasay'] == true
                  ? const OutsidePasayBadge()
                  : null,
              onTap: () => _showEvacSheet(s),
            ),
          ),
        );
      }
    }

    for (final layer in _gisLayers) {
      if (!_on.contains(layer.key)) continue;
      for (final row in _gis[layer.key] ?? const <Map<String, dynamic>>[]) {
        if (row[layer.latKey] == null || row[layer.lngKey] == null) continue;
        final point = LatLng(
          (row[layer.latKey] as num).toDouble(),
          (row[layer.lngKey] as num).toDouble(),
        );
        markers.add(
          Marker(
            point: point,
            width: MapMarker.target,
            height: MapMarker.target,
            // For a risk zone the drawn area is the zone; this is its handle.
            child: MapMarker(
              kind: layer.markerKind,
              label: (row['name'] as String?) ?? layer.label,
              onTap: () => _showGisSheet(layer, row),
            ),
          ),
        );
      }
    }

    if (_on.contains('incidents')) {
      for (final a in _areas) {
        markers.add(
          Marker(
            point: LatLng(
              (a['centroid_lat'] as num).toDouble(),
              (a['centroid_lng'] as num).toDouble(),
            ),
            width: MapMarker.target,
            height: MapMarker.target,
            // GET /areas carries no agencies, so every Area is the Incident
            // kind; its status is a word in the sheet and on the Area, and a
            // live one pulses (04 · Map marker, pass 3).
            child: MapMarker(
              kind: MapMarkerKind.incident,
              label: (a['designation'] as String?) ?? t('Incident area'),
              live: _isLive(a['status'] as String?),
              onTap: () => _openArea(a),
            ),
          ),
        );
      }
    }

    // "You are here" is YouAreHereLayer's: it also shows which way you face.
    return markers;
  }

  // --------------------------------------------------------- top overlay ---
  Widget _topControls() {
    final queued = _queue.pending.value;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Just the locality: "04 Map" has no avatar here - Profile is a
            // tab on the bar since the overhaul.
            Align(alignment: Alignment.centerLeft, child: _localityPill()),
            const SizedBox(height: 16),
            // "There's a new update!", while one is waiting: the map is the
            // resident's home screen.
            const UpdateBanner(padding: EdgeInsets.only(bottom: 16)),
            if (queued.isNotEmpty)
              _queueCard(queued)
            else ...[
              _chips(),
              const SizedBox(height: 16),
              _locationCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _localityPill() {
    final offline = _isOffline;
    final line = !offline
        ? t('WATCHING PASAY')
        : _queue.pending.value.isNotEmpty
        ? t('NO SIGNAL — QUEUED')
        : t('NO SIGNAL');
    return _Glass(
      radius: AppRadius.card,
      height: 48,
      padding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offline)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.pal.live,
                shape: BoxShape.circle,
              ),
            )
          else
            LiveDot(color: context.pal.accent),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('RESPONDERS'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.cardTitleSm,
                ),
                const SizedBox(height: 3),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Tertiary, never muted, on glass (04 · Map place card).
                  style: context.type.caption.copyWith(
                    color: context.pal.label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The Map layer chips (04 · pass 2) — the shared [MapLayerChip], so the
  /// staff maps' legends read the same.
  Widget _chips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _layers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final layer = _layers[i];
          return MapLayerChip(
            label: t(layer.label),
            tone: layer.colour(context.pal),
            on: _on.contains(layer.key),
            onTap: () => _toggle(layer),
          );
        },
      ),
    );
  }

  /// "Your location": the street you are on and how good the fix is. Tapping
  /// it brings the map back to you — the frame has no separate recentre button.
  Widget _locationCard() {
    final title = _myLoc == null
        ? t('LOCATING YOU')
        : (_street ?? t("You're here")).toUpperCase();
    final caption = _myLoc == null
        ? t('Showing Pasay City until a fix arrives')
        : _accuracy == null
        ? t('Location on')
        : t('GPS accurate to {m} m', {'m': _accuracy!.round()});
    return Semantics(
      button: true,
      label: '$title. $caption. Tap to center the map on you.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _recenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: _Glass(
            radius: AppRadius.panel,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoralPlate(
                  AppIcons.locationOn,
                  size: 44,
                  radius: AppRadius.control,
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.subtitle,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption.copyWith(
                          color: context.pal.textSoft,
                        ),
                      ),
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

  /// "1 report waiting" — takes the chips' place while anything is queued.
  Widget _queueCard(List<QueuedReport> queued) {
    final n = queued.length;
    return _Glass(
      radius: AppRadius.panel,
      color: MapGlass.strong(context),
      edge: context.pal.accent.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.pal.wellFor(context.pal.accent),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(
                  AppIcons.refresh,
                  size: 17,
                  color: context.pal.glyphOn(context.pal.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      n == 1
                          ? t('1 REPORT WAITING')
                          : t('{n} REPORTS WAITING', {'n': n}),
                      style: context.type.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _queue.offline.value
                          ? t('Retrying every 15 seconds')
                          : t(
                              'Waiting on the server — retrying every 15 seconds',
                            ),
                      style: context.type.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          Text(
            t(
              'Your report and photo are saved on this phone. They send '
              'themselves the second you get signal.',
            ),
            style: context.type.detail.copyWith(color: context.pal.label),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QueueAction(
                  label: t('Try now'),
                  busy: _retrying,
                  onTap: _retrying ? null : _retryNow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QueueAction(
                  label: t('Call 911'),
                  icon: AppIcons.call,
                  onTap: _call911,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- sheet ---
  /// "AREAS SHEET": drags down out of the way to just its title, so the map
  /// is clear, and back up — or tap the title to do either.
  Widget _sheet(double clearance) {
    final offline = _isOffline;
    final rows = offline ? _offlineRows() : _nearbyRows();
    return DragDownSheet(
      frame: (context, content) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        child: _MaybeBlur(
          child: Container(
            // Glass strong: the sheet carries status words and prose.
            color: MapGlass.strong(context),
            // The bar's height plus a little: the last row clears the SOS
            // disc, and a folded sheet's title sits just above the bar.
            padding: EdgeInsets.fromLTRB(24, 14, 24, clearance + 10),
            child: content,
          ),
        ),
      ),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SheetHandle(margin: EdgeInsets.zero),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  MapTiles.credit,
                  style: context.type.captionSm.copyWith(
                    fontSize: 9,
                    color: context.pal.faint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Eyebrow(
                  offline
                      ? t('Saved on this phone')
                      : t('Active areas near you'),
                  color: context.pal.accent,
                ),
              ),
              const SizedBox(width: 12),
              // A pulsing dot while the socket is up: what is on the map is
              // what the server has, this second.
              if (!offline && _live.live.value) ...[
                Semantics(
                  label: t('Live'),
                  child: LiveDot(size: 6, color: context.pal.ok),
                ),
                const SizedBox(width: 6),
              ],
              // The sheet only ever lists what is within 1.5 km: with no
              // fix it lists nothing, rather than the city under this name.
              Eyebrow(
                offline ? 'Offline' : t('Within 1.5 km'),
                color: context.pal.muted,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// Nothing is named until both answers are in: the server's areas and the
  /// phone's fix. Until then the sheet says it is checking; without a fix, or
  /// without the areas, it says which is missing.
  List<Widget> _nearbyRows() {
    if (_loading || (_myLoc == null && _locating)) {
      return [
        _sheetNote(t('Checking what is happening around you…')),
        const _CheckingRow(),
      ];
    }
    if (!_areasLoaded) {
      return [
        _sheetNote(
          t(
            'Active areas could not be loaded. The map tries again every 15 seconds.',
          ),
        ),
      ];
    }
    if (_myLoc == null) {
      return [
        _sheetNote(
          _locationProblem ??
              t(
                'Could not find your location yet. Move near a window or outdoors.',
              ),
        ),
      ];
    }
    final near = _nearbyAreas();
    final shelter = _nearestOpenShelter();
    return [
      if (near.isEmpty)
        _sheetNote(
          t('Nothing active within 1.5 km. That is the good outcome.'),
        ),
      for (final e in near) _areaRow(e.area, e.metres),
      if (shelter != null) _shelterRow(shelter),
    ];
  }

  Widget _sheetNote(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: context.type.bodySm),
  );

  Widget _areaRow(Map<String, dynamic> a, double metres) {
    final reported = a['status'] == 'reported';
    final id = a['id'] as String?;
    final street = id == null ? null : _areaStreets[id];
    final reports = (a['report_count'] as num?)?.toInt() ?? 0;
    // DAWI "AREA": a fire incident is coral — the brown well, a coral LIVE
    // and coral confidence bars — on the plain card edge.
    return _SheetRow(
      tint: context.pal.accent,
      asset: Art.incident,
      title: (a['designation'] as String?) ?? t('Incident area'),
      subtitle:
          street ?? t('{distance} away', {'distance': _formatDistance(metres)}),
      signal: _AreaSignal(
        label: reported ? t('Reported') : t('Live'),
        color: reported ? context.pal.warn : context.pal.accentInk,
        reports: reports,
        band: a['confidence_band'] as String?,
      ),
      onTap: () => _openArea(a),
    );
  }

  Widget _shelterRow(Map<String, dynamic> s) {
    final capacity = (s['capacity'] as num?)?.toInt();
    final name = (s['name'] as String?) ?? t('Evacuation site');
    return _SheetRow(
      tint: context.pal.ok,
      asset: Art.evac,
      title: t('Evacuation site open'),
      subtitle: s['outside_pasay'] == true ? '$name · ${s['city']}' : name,
      signal: capacity == null
          ? null
          : Text(
              t('SPACE FOR {n}', {'n': capacity}),
              style: context.type.tag.copyWith(color: context.pal.muted),
            ),
      onTap: () => _showEvacSheet(s),
    );
  }

  List<Widget> _offlineRows() {
    final queued = _queue.pending.value;
    final saved = _cacheSavedAt;
    return [
      for (final r in queued.take(2))
        _SheetRow(
          tint: context.pal.live,
          asset: Art.incident,
          title: t('{kind} report', {'kind': _agencyWord(r.agencies)}),
          subtitle: t('Queued at {time}', {
            'time': TimeOfDay.fromDateTime(r.queuedAt).format(context),
          }),
          edge: context.pal.accent.withValues(alpha: 0.45),
          signal: Text(
            t('QUEUED'),
            style: context.type.tag.copyWith(color: context.pal.accent),
          ),
        ),
      _SheetRow(
        tint: context.pal.accent,
        icon: AppIcons.layers,
        title: saved == null
            ? t('Map layers not saved yet')
            : t('Map layers cached'),
        subtitle: saved == null
            ? t('They save the next time the map has signal')
            : t('Downloaded {ago}', {'ago': _ago(saved)}),
        signal: saved == null
            ? null
            : Text(
                t('READY'),
                style: context.type.tag.copyWith(color: context.pal.ok),
              ),
      ),
      _SheetRow(
        tint: context.pal.ok,
        icon: AppIcons.call,
        title: t('All {n} hotlines', {'n': kHotlines.length}),
        subtitle: t('Dial without data'),
        onTap: () => AppNavBar.switchTo(context, AppTab.hotlines),
      ),
    ];
  }

  static String _agencyWord(List<String> agencies) =>
      switch (agencies.isEmpty ? '' : agencies.first) {
        'fire_volunteer' || 'bfp' => t('Fire'),
        'medical' => t('Medical'),
        'police' => t('Police'),
        'barangay' => t('Barangay'),
        _ => t('Emergency'),
      };

  static String _ago(DateTime at) => tAgo(at);

  // ----------------------------------------------------------- sheets ---
  /// An incident opens its own screen ("06 Area detail"); the reference
  /// layers keep their small sheets.
  void _openArea(Map<String, dynamic> a) {
    final id = a['id'] as String?;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailScreen(
          areaId: id,
          designation: a['designation'] as String?,
          here: _myLoc,
        ),
      ),
    );
  }

  void _showEvacSheet(Map<String, dynamic> s) {
    final capacity = (s['capacity'] as num?)?.toInt();
    final metres = _metresTo(
      (s['latitude'] as num).toDouble(),
      (s['longitude'] as num).toDouble(),
    );
    _detailSheet(
      accent: context.pal.ok,
      asset: Art.evac,
      tag: s['outside_pasay'] == true
          ? t('SHELTER · OUTSIDE PASAY')
          : t('SHELTER'),
      title: (s['name'] as String?) ?? t('Evacuation site'),
      rows: [
        _DetailRow(
          t('Open'),
          s['is_active'] == false ? t('Not at the moment') : t('Yes'),
        ),
        if (s['city'] != null) _DetailRow(t('City'), s['city'] as String),
        if (s['address'] != null)
          _DetailRow(t('Address'), s['address'] as String),
        if (capacity != null)
          _DetailRow(t('Capacity'), t('{n} people', {'n': capacity})),
        if (metres != null) _DetailRow(t('Distance'), _formatDistance(metres)),
        if (s['contact_info'] != null)
          _DetailRow(t('Contact'), s['contact_info'] as String),
      ],
    );
  }

  static String _pretty(Object? v) => v == null
      ? ''
      : v
            .toString()
            .split('_')
            .map(
              (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
            )
            .join(' ');

  void _showGisSheet(_Layer layer, Map<String, dynamic> r) {
    final lat = r[layer.latKey] as num?;
    final lng = r[layer.lngKey] as num?;
    final metres = lat == null || lng == null
        ? null
        : _metresTo(lat.toDouble(), lng.toDouble());
    final String title;
    final rows = <_DetailRow>[];
    switch (layer.key) {
      case 'risk':
        title = (r['name'] as String?) ?? 'Brgy. ${r['barangay']}';
        rows
          ..add(_DetailRow(t('Risk level'), _pretty(r['risk_level'])))
          ..add(_DetailRow(t('Barangay'), '${r['barangay']}'));
        if (r['description'] != null) {
          rows.add(_DetailRow(t('Notes'), r['description'] as String));
        }
      case 'hydrants':
        title = (r['code'] as String?) ?? t('Fire hydrant');
        rows.add(_DetailRow(t('Status'), _pretty(r['effective_status'])));
        if (r['address'] != null) {
          rows.add(_DetailRow(t('Address'), r['address'] as String));
        }
      case 'water':
        title = (r['name'] as String?) ?? t('Body of water');
        if (r['water_type'] != null) {
          rows.add(_DetailRow(t('Type'), r['water_type'] as String));
        }
        rows.add(
          _DetailRow(
            t('Access'),
            r['is_accessible'] == true ? t('Accessible') : t('Restricted'),
          ),
        );
      default:
        title =
            (r['name'] as String?) ??
            (r['code'] as String?) ??
            t('Underground cistern');
        rows.add(_DetailRow(t('Status'), _pretty(r['status'])));
        final litres = (r['capacity_liters'] as num?)?.toInt();
        if (litres != null) rows.add(_DetailRow(t('Capacity'), '$litres L'));
        if (r['address'] != null) {
          rows.add(_DetailRow(t('Address'), r['address'] as String));
        }
    }
    if (metres != null) {
      rows.add(_DetailRow(t('Distance'), _formatDistance(metres)));
    }
    _detailSheet(
      accent: layer.colour(context.pal),
      icon: layer.icon,
      asset: layer.asset,
      tag: t(layer.tag),
      title: title,
      rows: rows,
    );
  }

  void _detailSheet({
    required Color accent,
    IconData? icon,
    String? asset,
    required String tag,
    required String title,
    required List<_DetailRow> rows,
  }) {
    showAppSheet<void>(
      context: context,
      backgroundColor: context.pal.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              Row(
                children: [
                  IconWell(
                    tint: accent,
                    icon: icon,
                    asset: asset,
                    size: 48,
                    glyph: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Eyebrow(tag, color: accent),
                        const SizedBox(height: 6),
                        Text(title.toUpperCase(), style: context.type.title),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...rows.map(_detailRowTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRowTile(_DetailRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Eyebrow(row.label, color: context.pal.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.value,
              style: context.type.rowValue.copyWith(
                color: context.pal.onBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted glass: the backdrop blurred, the ground colour over it, a hairline
/// edge. Grouped, so the dozen of these over the map share one backdrop read.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = AppRadius.panel,
    this.padding = EdgeInsets.zero,
    this.color,
    this.edge,
    this.height,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  /// Defaults to the palette's glass over the map.
  final Color? color;

  /// Defaults to the palette's hairline.
  final Color? edge;

  /// The least height. The panel grows past it with its text — at 1.5×
  /// system font size a fixed height would cut the second line off.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: _MaybeBlur(
        child: Container(
          constraints: BoxConstraints(minHeight: height ?? 0),
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? MapGlass.glass(context),
            borderRadius: shape,
            border: Border.all(color: edge ?? context.pal.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The map's blur behind a glass panel, or none when the panel is solid
/// (the accessibility setting for more contrast — see [MapGlass]).
class _MaybeBlur extends StatelessWidget {
  const _MaybeBlur({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MapGlass.blurs(context)
      ? BackdropFilter.grouped(filter: MapGlass.blur, child: child)
      : child;
}

/// The map's top and bottom darkening: 80% at the top edge, clear through
/// the middle, 92% at the foot — so the overlays read over busy streets.
class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    final ground = context.pal.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ground.withValues(alpha: 0.8),
            ground.withValues(alpha: 0),
            ground.withValues(alpha: 0),
            ground.withValues(alpha: 0.92),
          ],
          stops: const [0, 0.26, 0.55, 1],
        ),
      ),
    );
  }
}

/// A rounded-square marker: a glyph on the near-black ground, edged in the
/// layer's colour. [outside] adds the "outside Pasay" arrow (v10 §2.4).
/// A map marker as "04 Map" draws it: a solid plate at the marker radius, a
/// 1px edge, and the glyph in white - so it reads the same over the dark and
/// the light basemap.
/// The corner sign on a shelter outside Pasay (PRD §4.4: such sites are
/// drawn with a distinct marker).
/// An Area still being responded to: its marker pulses.
bool _isLive(String? status) =>
    const {'reported', 'verified', 'en_route', 'arrived'}.contains(status);

/// One 56px row in the sheet: tinted glyph well, two lines, a signal column.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.tint,
    required this.title,
    required this.subtitle,
    this.asset,
    this.icon,
    this.signal,
    this.edge,
    this.onTap,
  });

  final Color tint;
  final String title;
  final String subtitle;
  final String? asset;
  final IconData? icon;
  final Widget? signal;
  final Color? edge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.card);
    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.pal.glass,
            borderRadius: shape,
            border: Border.all(color: edge ?? context.pal.line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.pal.wellFor(tint),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: asset != null
                    ? Image.asset(asset!, width: 15, height: 15)
                    : Icon(icon, size: 15, color: context.pal.glyphOn(tint)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.rowTitle.copyWith(
                        height: 15 / 12,
                        color: context.pal.isLight
                            ? null
                            : const Color(0xFFF3F3F3), // TEXT/grey-50
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption,
                    ),
                  ],
                ),
              ),
              if (signal != null) ...[const SizedBox(width: 12), signal!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A [_SheetRow]'s shape in placeholder bars, while the sheet checks: the
/// skeleton idiom of the summary card ("Lit's place and skeleton lines, not a
/// spinner alone"), still, so it reads the same with reduced motion.
class _CheckingRow extends StatelessWidget {
  const _CheckingRow();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget bar(double width) => Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: pal.pressed,
        borderRadius: BorderRadius.circular(5),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: pal.glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: pal.line),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: pal.pressed,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [bar(96), const SizedBox(height: 8), bar(150)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "LIVE / 3 REPORTS / ▬▬▭" — status word, corroboration, confidence band.
class _AreaSignal extends StatelessWidget {
  const _AreaSignal({
    required this.label,
    required this.color,
    required this.reports,
    required this.band,
  });

  final String label;
  final Color color;
  final int reports;
  final String? band;

  @override
  Widget build(BuildContext context) {
    final filled = switch (band) {
      'high' => 3,
      'medium' => 2,
      'low' => 1,
      _ => 0,
    };
    return Semantics(
      label: t('{area}, {n} reports, {band} confidence', {
        'area': label,
        'n': reports,
        'band': t(band ?? 'unknown'),
      }),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: context.type.tag.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Text(
            reports == 1 ? t('1 REPORT') : t('{n} REPORTS', {'n': reports}),
            style: context.type.tag.copyWith(color: context.pal.muted),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Container(
                  width: 9,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < filled
                        ? context.pal.accent
                        : context.pal.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// "TRY NOW" / "CALL 911" under the queue card.
class _QueueAction extends StatelessWidget {
  const _QueueAction({
    required this.label,
    this.icon,
    this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.control);
    return Material(
      color: context.pal.glass,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: context.pal.line),
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: context.pal.textSoft),
                      const SizedBox(width: 8),
                    ],
                    // Scales down rather than running past the button
                    // when the label is long (Tagalog, large text).
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label.toUpperCase(),
                          style: context.type.eyebrow.copyWith(
                            color: context.pal.textSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
}
