import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/map_cache.dart';
import '../api/report_queue.dart';
import '../models/hotline.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import '../widgets/map_tiles.dart';
import 'area_detail_screen.dart';

/// Pasay City centre — the map's home view when the user's GPS is unavailable.
const LatLng _pasayCenter = LatLng(14.5378, 121.0014);

/// How far "near you" reaches in the areas sheet: the frame's "Within 1.5 km".
const double _nearMetres = 1500;

/// The dark glass every overlay on the map sits on — #171717 at 72%, and at
/// 90% for the sheet and the offline card, which carry more text.
const Color _overlay = Color(0xB8171717);
const Color _overlayDense = Color(0xE6171717);

/// The ground under a map marker glyph: #131313 at 92%.
const Color _markerGround = Color(0xEB131313);

/// One chip in the "Map layers" row, and the layer it switches.
class _Layer {
  const _Layer(
    this.key,
    this.label,
    this.color, {
    this.tag = '',
    this.icon,
    this.asset,
    this.latKey = 'latitude',
    this.lngKey = 'longitude',
  });

  /// Endpoint and cache slot: incidents, evac, risk, hydrants, water, cisterns.
  final String key;
  final String label;
  final Color color;

  /// The eyebrow on this layer's detail sheet.
  final String tag;
  final IconData? icon;
  final String? asset;
  final String latKey;
  final String lngKey;

  bool get isGis => key != 'incidents' && key != 'evac';
}

// Chip dots and marker edges are the Figma's own colours for each layer.
const _incidents = _Layer('incidents', 'Incidents', AppColors.accent);
const _shelters = _Layer(
  'evac',
  'Shelters',
  AppColors.ok,
  tag: 'SHELTER',
  asset: Art.evac,
);
const _hydrants = _Layer(
  'hydrants',
  'Hydrants',
  AppColors.textSoft,
  tag: 'FIRE HYDRANT',
  asset: Art.hydrant,
);
const _risk = _Layer(
  'risk',
  'Risk zones',
  AppColors.live,
  tag: 'RISK AREA',
  icon: Icons.warning_amber_rounded,
  latKey: 'centroid_lat',
  lngKey: 'centroid_lng',
);
const _water = _Layer(
  'water',
  'Water',
  AppColors.coastguard,
  tag: 'BODY OF WATER',
  icon: Icons.waves_rounded,
);
const _cisterns = _Layer(
  'cisterns',
  'Cisterns',
  AppColors.warn,
  tag: 'UNDERGROUND CISTERN',
  icon: Icons.water_damage_outlined,
);

const List<_Layer> _layers = [
  _incidents,
  _shelters,
  _hydrants,
  _risk,
  _water,
  _cisterns,
];
const List<_Layer> _gisLayers = [_risk, _hydrants, _water, _cisterns];

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
  const MapScreen({super.key, this.api});

  /// Stands in for the server in tests.
  final ApiClient? api;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final MapController _map = MapController();
  final ReportQueue _queue = ReportQueue.instance;

  Timer? _poll;
  bool _loading = true;

  /// The last /areas call could not reach the server.
  bool _offline = false;
  bool _retrying = false;

  final Set<String> _on = {'incidents', 'evac'};
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _evac = [];
  final Map<String, List<Map<String, dynamic>>> _gis = {};
  DateTime? _cacheSavedAt;

  LatLng? _myLoc;
  double? _accuracy;
  String? _street;

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
    _bootstrap();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _loadAreas());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _queue.pending.removeListener(_rebuild);
    _queue.offline.removeListener(_rebuild);
    _queue.lastRejection.removeListener(_onRejection);
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
    _toast('A saved report was turned down: $message');
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
      _toast('Could not load ${layer.label.toLowerCase()}.');
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
  Future<void> _locateQuietly({required bool recenter}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _myLoc = here;
        _accuracy = pos.accuracy;
      });
      if (recenter) _map.move(here, 15.2);
      _street = await _streetAt(here);
      if (mounted) setState(() {});
      _lookUpAreaStreets();
    } catch (_) {
      // ignore — map stays on its current view
    }
  }

  void _recenter() {
    if (_myLoc != null) {
      _map.move(_myLoc!, 15.2);
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

  static String _formatDistance(double metres) => metres < 1000
      ? '${metres.round()} m'
      : '${(metres / 1000).toStringAsFixed(1)} km';

  /// Areas within 1.5 km, nearest first. With no fix nothing can be measured,
  /// so the newest two stand in (the list arrives newest first).
  List<({Map<String, dynamic> area, double? metres})> _nearbyAreas() {
    final measured = [
      for (final a in _areas)
        (
          area: a,
          metres: _metresTo(
            (a['centroid_lat'] as num).toDouble(),
            (a['centroid_lng'] as num).toDouble(),
          ),
        ),
    ];
    if (_myLoc == null) return measured.take(2).toList();
    return (measured.where((e) => e.metres! <= _nearMetres).toList()
          ..sort((x, y) => x.metres!.compareTo(y.metres!)))
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
            ? 'Still no signal. It keeps trying every 15 seconds.'
            : 'The server is not taking it yet. It keeps trying every 15 seconds.',
      );
    }
  }

  Future<void> _call911() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '911'));
    } catch (_) {
      _toast('Could not open the dialler. Dial 911 directly.');
    }
  }

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
      options: const MapOptions(
        initialCenter: _pasayCenter,
        initialZoom: 13,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: AppColors.background,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        MapTiles.layer(),
        if (_on.contains('risk')) PolygonLayer(polygons: _riskPolygons()),
        MarkerLayer(markers: _markers()),
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
            width: 28,
            height: 28,
            child: GestureDetector(
              onTap: () => _showEvacSheet(s),
              child: Opacity(
                // A shelter that is not open still marks the place, dimmed.
                opacity: s['is_active'] == false ? 0.5 : 1,
                child: Center(
                  child: _MarkerSquare(
                    size: 24,
                    edge: AppColors.ok.withValues(alpha: 0.4),
                    asset: Art.evac,
                    glyph: 15,
                    outside: s['outside_pasay'] == true,
                  ),
                ),
              ),
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
            width: 24,
            height: 24,
            child: GestureDetector(
              onTap: () => _showGisSheet(layer, row),
              child: Center(
                child: layer == _risk
                    // The zone is the drawn area; this is its handle.
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.live.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.live),
                        ),
                      )
                    : _MarkerSquare(
                        size: 22,
                        edge: layer.color,
                        asset: layer.asset,
                        icon: layer.icon,
                        iconColor: layer.color,
                        glyph: 13,
                      ),
              ),
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
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: () => _openArea(a),
              child: _AreaMarker(status: a['status'] as String?),
            ),
          ),
        );
      }
    }

    if (_myLoc != null) {
      markers.add(
        Marker(
          point: _myLoc!,
          width: 34,
          height: 34,
          child: const _YouAreHere(),
        ),
      );
    }
    return markers;
  }

  List<Polygon> _riskPolygons() => [
    for (final r in _gis['risk'] ?? const <Map<String, dynamic>>[])
      for (final shape in _shapes(r['area_geojson']))
        Polygon(
          points: shape.outer,
          holePointsList: shape.holes,
          color: AppColors.live.withValues(alpha: 0.08),
          borderColor: AppColors.live.withValues(alpha: 0.45),
          borderStrokeWidth: 1,
        ),
  ];

  /// Polygon and MultiPolygon GeoJSON, as the server's ST_AsGeoJSON sends it.
  static List<({List<LatLng> outer, List<List<LatLng>> holes})> _shapes(
    Object? geojson,
  ) {
    try {
      final g = geojson is String ? jsonDecode(geojson) : geojson;
      if (g is! Map) return const [];
      final coords = g['coordinates'] as List;
      final polygons = switch (g['type']) {
        'Polygon' => [coords],
        'MultiPolygon' => coords,
        _ => const <dynamic>[],
      };
      List<LatLng> ring(dynamic r) => [
        for (final c in r as List)
          LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
      return [
        for (final p in polygons.cast<List>())
          (outer: ring(p.first), holes: [for (final h in p.skip(1)) ring(h)]),
      ];
    } catch (_) {
      return const [];
    }
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
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _localityPill(),
                  ),
                ),
                const SizedBox(width: 12),
                _avatar(),
              ],
            ),
            const SizedBox(height: 16),
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
        ? 'WATCHING PASAY'
        : _queue.pending.value.isNotEmpty
        ? 'NO SIGNAL — QUEUED'
        : 'NO SIGNAL';
    return _Glass(
      radius: AppRadius.card,
      height: 48,
      padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offline)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.live,
                shape: BoxShape.circle,
              ),
            )
          else
            const LiveDot(color: AppColors.accent),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BARANGAY 76',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitleSm,
                ),
                const SizedBox(height: 3),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tag.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Semantics(
      button: true,
      label: 'Your profile',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => AppNavBar.switchTo(context, AppTab.profile),
        child: _Glass(
          radius: AppRadius.card,
          width: 48,
          height: 48,
          edge: AppColors.lineStrong,
          child: Center(
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(Art.avatar, width: 28, height: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chips() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _layers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final layer = _layers[i];
          final on = _on.contains(layer.key);
          return Semantics(
            button: true,
            toggled: on,
            label: layer.label,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _toggle(layer),
              child: _Glass(
                radius: AppRadius.chip,
                blur: 9,
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: on ? layer.color.withValues(alpha: 0.16) : _overlay,
                edge: on ? layer.color.withValues(alpha: 0.45) : AppColors.line,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: layer.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      layer.label.toUpperCase(),
                      style: AppText.tag.copyWith(
                        color: on ? layer.color : AppColors.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// "Your location": the street you are on and how good the fix is. Tapping
  /// it brings the map back to you — the frame has no separate recentre button.
  Widget _locationCard() {
    final title = _myLoc == null
        ? 'LOCATING YOU'
        : (_street ?? "You're here").toUpperCase();
    final caption = _myLoc == null
        ? 'Showing Pasay City until a fix arrives'
        : _accuracy == null
        ? 'Location on'
        : 'GPS accurate to ${_accuracy!.round()} m';
    return Semantics(
      button: true,
      label: '$title. $caption. Tap to centre the map on you.',
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.accentText,
                  ),
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
                        style: AppText.subtitle,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: AppColors.label),
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
      color: _overlayDense,
      edge: AppColors.accent.withValues(alpha: 0.45),
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
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 17,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$n REPORT${n == 1 ? '' : 'S'} WAITING',
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _queue.offline.value
                          ? 'Retrying every 15 seconds'
                          : 'Waiting on the server — retrying every 15 seconds',
                      style: AppText.caption,
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
            'Your report and photo are saved on this phone. They send '
            'themselves the second you get signal.',
            style: AppText.detail.copyWith(color: AppColors.label),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QueueAction(
                  label: 'Try now',
                  busy: _retrying,
                  onTap: _retrying ? null : _retryNow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QueueAction(
                  label: 'Call 911',
                  icon: Icons.call_outlined,
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
  Widget _sheet(double clearance) {
    final offline = _isOffline;
    final rows = offline ? _offlineRows() : _nearbyRows();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: _overlayDense,
          // The bar's height plus a little: the last row clears the SOS disc.
          padding: EdgeInsets.fromLTRB(24, 10, 24, clearance + 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.label.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      MapTiles.credit,
                      style: AppText.captionSm.copyWith(
                        fontSize: 9,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Eyebrow(
                      offline ? 'Saved on this phone' : 'Active areas near you',
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Eyebrow(
                    offline
                        ? 'Offline'
                        : _myLoc == null
                        ? 'Pasay City'
                        : 'Within 1.5 km',
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _nearbyRows() {
    final near = _nearbyAreas();
    final shelter = _nearestOpenShelter();
    return [
      if (near.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _loading
                ? 'Checking what is happening around you…'
                : _myLoc == null
                ? 'Nothing active in Pasay City right now. That is the good outcome.'
                : 'Nothing active within 1.5 km. That is the good outcome.',
            style: AppText.bodySm,
          ),
        ),
      for (final e in near) _areaRow(e.area, e.metres),
      if (shelter != null) _shelterRow(shelter),
    ];
  }

  Widget _areaRow(Map<String, dynamic> a, double? metres) {
    final pending = a['status'] == 'pending';
    final id = a['id'] as String?;
    final street = id == null ? null : _areaStreets[id];
    final reports = (a['report_count'] as num?)?.toInt() ?? 0;
    return _SheetRow(
      tint: pending ? AppColors.accent : AppColors.live,
      asset: Art.incident,
      title: (a['designation'] as String?) ?? 'Incident area',
      subtitle:
          street ??
          (metres != null
              ? '${_formatDistance(metres)} away'
              : 'In Pasay City'),
      edge: pending ? null : AppColors.live.withValues(alpha: 0.45),
      signal: _AreaSignal(
        label: pending ? 'Pending' : 'Live',
        color: pending ? AppColors.warn : AppColors.live,
        reports: reports,
        band: a['confidence_band'] as String?,
      ),
      onTap: () => _openArea(a),
    );
  }

  Widget _shelterRow(Map<String, dynamic> s) {
    final capacity = (s['capacity'] as num?)?.toInt();
    final name = (s['name'] as String?) ?? 'Evacuation site';
    return _SheetRow(
      tint: AppColors.ok,
      asset: Art.evac,
      title: 'Evacuation site open',
      subtitle: s['outside_pasay'] == true ? '$name · ${s['city']}' : name,
      signal: capacity == null
          ? null
          : Text(
              'SPACE FOR $capacity',
              style: AppText.tag.copyWith(color: AppColors.muted),
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
          tint: AppColors.live,
          asset: Art.incident,
          title: '${_agencyWord(r.agencies)} report',
          subtitle:
              'Queued at ${TimeOfDay.fromDateTime(r.queuedAt).format(context)}',
          edge: AppColors.accent.withValues(alpha: 0.45),
          signal: Text(
            'QUEUED',
            style: AppText.tag.copyWith(color: AppColors.accent),
          ),
        ),
      _SheetRow(
        tint: AppColors.accent,
        icon: Icons.layers_outlined,
        title: saved == null ? 'Map layers not saved yet' : 'Map layers cached',
        subtitle: saved == null
            ? 'They save the next time the map has signal'
            : 'Downloaded ${_ago(saved)}',
        signal: saved == null
            ? null
            : Text('READY', style: AppText.tag.copyWith(color: AppColors.ok)),
      ),
      _SheetRow(
        tint: AppColors.ok,
        icon: Icons.call_outlined,
        title: 'All ${kHotlines.length} hotlines',
        subtitle: 'Dial without data',
        onTap: () => AppNavBar.switchTo(context, AppTab.hotlines),
      ),
    ];
  }

  static String _agencyWord(List<String> agencies) =>
      switch (agencies.isEmpty ? '' : agencies.first) {
        'fire_volunteer' || 'bfp' => 'Fire',
        'medical' => 'Medical',
        'police' => 'Police',
        'barangay' => 'Barangay',
        _ => 'Emergency',
      };

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) {
      return '${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
  }

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
      accent: AppColors.ok,
      asset: Art.evac,
      tag: s['outside_pasay'] == true ? 'SHELTER · OUTSIDE PASAY' : 'SHELTER',
      title: (s['name'] as String?) ?? 'Evacuation site',
      rows: [
        _DetailRow(
          'Open',
          s['is_active'] == false ? 'Not at the moment' : 'Yes',
        ),
        if (s['city'] != null) _DetailRow('City', s['city'] as String),
        if (s['address'] != null) _DetailRow('Address', s['address'] as String),
        if (capacity != null) _DetailRow('Capacity', '$capacity people'),
        if (metres != null) _DetailRow('Distance', _formatDistance(metres)),
        if (s['contact_info'] != null)
          _DetailRow('Contact', s['contact_info'] as String),
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
          ..add(_DetailRow('Risk level', _pretty(r['risk_level'])))
          ..add(_DetailRow('Barangay', '${r['barangay']}'));
        if (r['description'] != null) {
          rows.add(_DetailRow('Notes', r['description'] as String));
        }
      case 'hydrants':
        title = (r['code'] as String?) ?? 'Fire hydrant';
        rows.add(_DetailRow('Status', _pretty(r['effective_status'])));
        if (r['address'] != null) {
          rows.add(_DetailRow('Address', r['address'] as String));
        }
      case 'water':
        title = (r['name'] as String?) ?? 'Body of water';
        if (r['water_type'] != null) {
          rows.add(_DetailRow('Type', r['water_type'] as String));
        }
        rows.add(
          _DetailRow(
            'Access',
            r['is_accessible'] == true ? 'Accessible' : 'Restricted',
          ),
        );
      default:
        title =
            (r['name'] as String?) ??
            (r['code'] as String?) ??
            'Underground cistern';
        rows.add(_DetailRow('Status', _pretty(r['status'])));
        final litres = (r['capacity_liters'] as num?)?.toInt();
        if (litres != null) rows.add(_DetailRow('Capacity', '$litres L'));
        if (r['address'] != null) {
          rows.add(_DetailRow('Address', r['address'] as String));
        }
    }
    if (metres != null) {
      rows.add(_DetailRow('Distance', _formatDistance(metres)));
    }
    _detailSheet(
      accent: layer.color,
      icon: layer.icon,
      asset: layer.asset,
      tag: layer.tag,
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
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
                        Text(title.toUpperCase(), style: AppText.title),
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
            child: Eyebrow(row.label, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.value,
              style: AppText.rowValue.copyWith(color: AppColors.onBackground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted dark glass: the backdrop blurred, #171717 over it, a hairline edge.
/// Grouped, so the dozen of these over the map share one backdrop read.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = AppRadius.panel,
    this.padding = EdgeInsets.zero,
    this.color = _overlay,
    this.edge = AppColors.line,
    this.blur = 12,
    this.width,
    this.height,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color color;
  final Color edge;
  final double blur;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: shape,
            border: Border.all(color: edge),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The map's top and bottom darkening: 80% at the top edge, clear through
/// the middle, 92% at the foot — so the overlays read over busy streets.
class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xCC131313),
          Color(0x00131313),
          Color(0x00131313),
          Color(0xEB131313),
        ],
        stops: [0, 0.26, 0.55, 1],
      ),
    ),
  );
}

/// A rounded-square marker: a glyph on the near-black ground, edged in the
/// layer's colour. [outside] adds the "outside Pasay" arrow (v10 §2.4).
class _MarkerSquare extends StatelessWidget {
  const _MarkerSquare({
    required this.size,
    required this.edge,
    required this.glyph,
    this.asset,
    this.icon,
    this.iconColor,
    this.outside = false,
  });

  final double size;
  final Color edge;
  final double glyph;
  final String? asset;
  final IconData? icon;
  final Color? iconColor;
  final bool outside;

  @override
  Widget build(BuildContext context) {
    final square = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _markerGround,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: edge),
      ),
      alignment: Alignment.center,
      child: asset != null
          ? Opacity(
              opacity: 0.92,
              child: Image.asset(asset!, width: glyph, height: glyph),
            )
          : Icon(icon, size: glyph, color: iconColor),
    );
    if (!outside) return square;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        square,
        Positioned(
          right: -5,
          top: -5,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.ok,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceSolid, width: 1.5),
            ),
            child: const Icon(
              Icons.north_east_rounded,
              size: 8,
              color: AppColors.surfaceSolid,
            ),
          ),
        ),
      ],
    );
  }
}

/// An incident area: a 30px square in its status colour with the flame.
class _AreaMarker extends StatelessWidget {
  const _AreaMarker({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.forStatus(status),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      border: Border.all(color: const Color(0xE6171717)),
    ),
    alignment: Alignment.center,
    child: Image.asset(Art.incident, width: 17, height: 17),
  );
}

/// You: a coral dot ringed in the sheet colour, inside a soft coral disc.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.28),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceSolid, width: 3),
      ),
    ),
  );
}

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
            color: AppColors.glass,
            borderRadius: shape,
            border: Border.all(color: edge ?? AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                alignment: Alignment.center,
                child: asset != null
                    ? Image.asset(asset!, width: 16, height: 16)
                    : Icon(icon, size: 16, color: tint),
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
                      style: AppText.rowTitle.copyWith(height: 15 / 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
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
      label:
          '$label, $reports ${reports == 1 ? 'report' : 'reports'}, '
          '${band ?? 'unknown'} confidence',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppText.tag.copyWith(color: color)),
          const SizedBox(height: 6),
          Text(
            '$reports ${reports == 1 ? 'REPORT' : 'REPORTS'}',
            style: AppText.tag.copyWith(color: AppColors.muted),
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
                    color: i < filled ? AppColors.accent : AppColors.lineStrong,
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
      color: AppColors.glass,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: AppColors.line),
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
                      Icon(icon, size: 14, color: AppColors.textSoft),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label.toUpperCase(),
                      style: AppText.eyebrow.copyWith(
                        color: AppColors.textSoft,
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
