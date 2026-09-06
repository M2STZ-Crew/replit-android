import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../models/facility.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'camera_capture_screen.dart';
import 'profile_screen.dart';

const Color _safeGreen = AppColors.ok;
const Color _fireRed = AppColors.live;
const Color _policeBlue = AppColors.crime;

/// Pasay City centre — the map's home view when the user's GPS is unavailable.
const LatLng _pasayCenter = LatLng(14.5378, 121.0014);

/// MAP tab — the home screen in the "General User App v2" hand-off.
///
/// Data sources are the citizen-readable endpoints only:
///  - GET /areas → active incident clusters, refreshed every 15 s.
///  - GET /map/evacuation-sites → shelters.
///
/// Two things the design shows are not drawn, because nothing produces them:
/// which units are on scene (dispatch detail is staff-only, and rightly so),
/// and a street name for an incident — there is no geocoder in the system, so
/// a cluster is named by its designation.
///
/// The Fire / Police chips draw the static reference list in
/// models/facility.dart; there is no station GIS table on the backend, and the
/// sheet says so rather than implying live data.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiClient _api = ApiClient();
  final MapController _map = MapController();

  Timer? _poll;
  bool _loading = true;
  bool _showEvac = true;
  bool _showFire = false;
  bool _showPolice = false;

  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _evac = [];
  LatLng? _myLoc;
  double? _accuracy;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _loadAreas());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadAreas(), _loadEvac()]);
    if (mounted) setState(() => _loading = false);
    await _locateQuietly(recenter: true);
  }

  Future<void> _loadAreas() async {
    try {
      final raw = await _api.getAreas();
      final areas = raw
          .cast<Map<String, dynamic>>()
          .where((a) => a['centroid_lat'] != null && a['centroid_lng'] != null)
          .toList();
      if (mounted) setState(() => _areas = areas);
    } catch (_) {
      // keep the last known incidents
    }
  }

  Future<void> _loadEvac() async {
    try {
      final raw = await _api.getEvacuationSites();
      final sites = raw
          .cast<Map<String, dynamic>>()
          .where((s) => s['latitude'] != null && s['longitude'] != null)
          .toList();
      if (mounted) setState(() => _evac = sites);
    } catch (_) {
      // leave evacuation sites empty
    }
  }

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

  void _openProfile() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));

  void _startSos() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const CameraCaptureScreen()));

  @override
  Widget build(BuildContext context) {
    final nearby = _nearby();
    final sheetHeight = 78.0 + (nearby.isEmpty ? 1 : nearby.length) * 64.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.map),
      body: Stack(
        children: [
          Positioned.fill(child: _mapLayer()),
          _topControls(),
          Positioned(
            right: 24,
            bottom: sheetHeight + 20,
            child: Column(
              children: [
                _recenterButton(),
                const SizedBox(height: 14),
                _sosButton(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _nearbySheet(nearby, sheetHeight),
          ),
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
      ),
    );
  }

  // ----------------------------------------------------------------- map ---
  Widget _mapLayer() {
    return ColorFiltered(
      // The design's map is the real street layer pulled toward the theme:
      // desaturated and darkened so the coral markers carry all the colour.
      // CARTO's dark_all basemap now serves an "API KEY REQUIRED" watermark
      // tile without a key, which is why this draws plain OSM and tints it.
      colorFilter: const ColorFilter.matrix(_kNightMatrix),
      child: FlutterMap(
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
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            // OpenStreetMap's tile policy requires a real identifying agent.
            userAgentPackageName: 'com.m2stz.replit',
            maxNativeZoom: 19,
          ),
          MarkerLayer(markers: _markers()),
          const RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [TextSourceAttribution('© OpenStreetMap')],
          ),
        ],
      ),
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];

    for (final a in _areas) {
      final lat = (a['centroid_lat'] as num).toDouble();
      final lng = (a['centroid_lng'] as num).toDouble();
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showIncidentSheet(a),
            child: _incidentDot(a),
          ),
        ),
      );
    }

    if (_showEvac) {
      for (final s in _evac) {
        final lat = (s['latitude'] as num).toDouble();
        final lng = (s['longitude'] as num).toDouble();
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 32,
            height: 32,
            child: GestureDetector(
              onTap: () => _showEvacSheet(s),
              child: _placePin(_safeGreen, Art.evac),
            ),
          ),
        );
      }
    }

    if (_showFire) {
      markers.addAll(
        _facilityMarkers(kFireStations, _fireRed, Icons.local_fire_department),
      );
    }
    if (_showPolice) {
      markers.addAll(
        _facilityMarkers(kPoliceStations, _policeBlue, Icons.local_police),
      );
    }

    if (_myLoc != null) {
      markers.add(
        Marker(point: _myLoc!, width: 26, height: 26, child: _myDot()),
      );
    }

    return markers;
  }

  List<Marker> _facilityMarkers(
    List<Facility> facilities,
    Color color,
    IconData icon,
  ) {
    return facilities
        .map(
          (f) => Marker(
            point: LatLng(f.lat, f.lng),
            width: 32,
            height: 32,
            child: GestureDetector(
              onTap: () => _showFacilitySheet(f, color, icon),
              child: _facilityPin(color, icon),
            ),
          ),
        )
        .toList();
  }

  Widget _facilityPin(Color color, IconData icon) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceSolid,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.5),
    ),
    padding: const EdgeInsets.all(5),
    child: Icon(icon, color: color, size: 15),
  );

  Widget _placePin(Color color, String art) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceSolid,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.5),
    ),
    padding: const EdgeInsets.all(5),
    child: Image.asset(art, fit: BoxFit.contain),
  );

  /// The marker carries its corroboration count, so a cluster several
  /// neighbours have confirmed reads differently from one unverified report.
  Widget _incidentDot(Map<String, dynamic> a) {
    final color = AppColors.forStatus(a['status'] as String?);
    final reports = (a['report_count'] as num?)?.toInt() ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$reports',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.onBackground,
        ),
      ),
    );
  }

  Widget _myDot() => Container(
    decoration: BoxDecoration(
      color: AppColors.accent,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.background, width: 3),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.5),
          blurRadius: 16,
        ),
      ],
    ),
  );

  // ------------------------------------------------------------ top bar ---
  Widget _topControls() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _locationCard()),
                const SizedBox(width: 12),
                AvatarWell(onTap: _openProfile),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _layerChip(
                    'Incidents',
                    AppColors.accent,
                    on: true,
                    count: _areas.length,
                    onTap: _loadAreas,
                  ),
                  const SizedBox(width: 8),
                  _layerChip(
                    'Shelters',
                    _safeGreen,
                    on: _showEvac,
                    count: _evac.length,
                    onTap: () => setState(() => _showEvac = !_showEvac),
                  ),
                  const SizedBox(width: 8),
                  _layerChip(
                    'Fire stations',
                    _fireRed,
                    on: _showFire,
                    count: kFireStations.length,
                    onTap: () => setState(() => _showFire = !_showFire),
                  ),
                  const SizedBox(width: 8),
                  _layerChip(
                    'Police',
                    _policeBlue,
                    on: _showPolice,
                    count: kPoliceStations.length,
                    onTap: () => setState(() => _showPolice = !_showPolice),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationCard() {
    return Panel(
      radius: AppRadius.card,
      color: AppColors.surfaceSolid.withValues(alpha: 0.86),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const LiveDot(color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _myLoc == null ? 'LOCATING YOU' : "YOU'RE HERE",
                  style: AppText.cardTitle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _myLoc == null
                      ? 'Showing Pasay City until a fix arrives'
                      : _accuracy == null
                      ? 'Location on'
                      : 'Accurate to ${_accuracy!.round()} m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerChip(
    String label,
    Color tint, {
    required bool on,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on
              ? tint.withValues(alpha: 0.14)
              : AppColors.surfaceSolid.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: on ? tint.withValues(alpha: 0.55) : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              '${label.toUpperCase()}${count > 0 ? '  $count' : ''}',
              style: AppText.tag.copyWith(
                letterSpacing: 1,
                color: on ? tint : AppColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- nearby sheet ---
  List<_Nearby> _nearby() {
    final out = <_Nearby>[];

    final incidents =
        _areas.map((a) {
          final lat = (a['centroid_lat'] as num).toDouble();
          final lng = (a['centroid_lng'] as num).toDouble();
          return (raw: a, metres: _metresTo(lat, lng));
        }).toList()
          ..sort((x, y) => (x.metres ?? 1e9).compareTo(y.metres ?? 1e9));

    for (final entry in incidents.take(2)) {
      final a = entry.raw;
      final status = ((a['status'] as String?) ?? 'pending').replaceAll(
        '_',
        ' ',
      );
      final reports = (a['report_count'] as num?)?.toInt() ?? 0;
      out.add(
        _Nearby(
          title: (a['designation'] as String?) ?? 'Incident area',
          subtitle: [
            if (entry.metres != null) _formatDistance(entry.metres!),
            status,
            '$reports ${reports == 1 ? 'report' : 'reports'}',
          ].join(' · '),
          tint: AppColors.forStatus(a['status'] as String?),
          art: Art.incident,
          live: true,
          onTap: () => _showIncidentSheet(a),
        ),
      );
    }

    if (_evac.isNotEmpty) {
      final sorted = _evac.toList()
        ..sort((x, y) {
          final dx =
              _metresTo(
                (x['latitude'] as num).toDouble(),
                (x['longitude'] as num).toDouble(),
              ) ??
              1e9;
          final dy =
              _metresTo(
                (y['latitude'] as num).toDouble(),
                (y['longitude'] as num).toDouble(),
              ) ??
              1e9;
          return dx.compareTo(dy);
        });
      final s = sorted.first;
      final metres = _metresTo(
        (s['latitude'] as num).toDouble(),
        (s['longitude'] as num).toDouble(),
      );
      final capacity = (s['capacity'] as num?)?.toInt();
      out.add(
        _Nearby(
          title: 'Shelter · ${(s['name'] as String?) ?? 'Evacuation site'}',
          subtitle: [
            if (metres != null) _formatDistance(metres),
            if (capacity != null) 'space for $capacity',
            if (s['address'] != null) s['address'] as String,
          ].join(' · '),
          tint: _safeGreen,
          art: Art.evac,
          live: false,
          onTap: () => _showEvacSheet(s),
        ),
      );
    }

    return out;
  }

  Widget _nearbySheet(List<_Nearby> items, double height) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Column(
        children: [
          const SheetHandle(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Eyebrow('Nearby right now', color: AppColors.accent),
              const Spacer(),
              Eyebrow(
                _areas.isEmpty
                    ? 'Pasay City'
                    : '${_areas.length} active in Pasay',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      _loading
                          ? 'Checking what is happening around you…'
                          : 'Nothing active in Pasay City right now. That is '
                                'the good outcome.',
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _nearbyRow(items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _nearbyRow(_Nearby item) {
    return Panel(
      radius: AppRadius.control,
      onTap: item.onTap,
      color: item.live ? AppColors.glass : AppColors.glassDim,
      border: item.live ? item.tint.withValues(alpha: 0.3) : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          IconWell(tint: item.tint, size: 32, glyph: 16, asset: item.art),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta,
                ),
              ],
            ),
          ),
          if (item.live) ...[
            const SizedBox(width: 8),
            Text(
              'LIVE',
              style: AppText.tag.copyWith(color: item.tint, letterSpacing: 0.8),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------- map buttons ---
  Widget _recenterButton() {
    final shape = BorderRadius.circular(AppRadius.card);
    return Material(
      color: AppColors.surfaceSolid.withValues(alpha: 0.9),
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: _recenter,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: AppColors.line),
          ),
          child: const Icon(
            Icons.my_location_rounded,
            size: 20,
            color: AppColors.onBackground,
          ),
        ),
      ),
    );
  }

  Widget _sosButton() {
    return Semantics(
      button: true,
      label: 'Send an SOS',
      child: GestureDetector(
        onTap: _startSos,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.sosGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 32,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'SOS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppColors.accentText,
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- sheets ---
  void _showIncidentSheet(Map<String, dynamic> a) {
    final status = ((a['status'] as String?) ?? 'pending')
        .replaceAll('_', ' ')
        .toUpperCase();
    final reports = (a['report_count'] as num?)?.toInt() ?? 0;
    final band = (a['confidence_band'] as String?)?.toUpperCase();
    final alarm = (a['alarm_level'] as String?)
        ?.replaceAll('_', ' ')
        .toUpperCase();
    final lat = (a['centroid_lat'] as num).toDouble();
    final lng = (a['centroid_lng'] as num).toDouble();
    final metres = _metresTo(lat, lng);
    _detailSheet(
      accent: AppColors.forStatus(a['status'] as String?),
      icon: Icons.local_fire_department,
      tag: 'ACTIVE INCIDENT',
      title: (a['designation'] as String?) ?? 'Incident area',
      rows: [
        _DetailRow('Status', status),
        _DetailRow(
          'Corroboration',
          '$reports ${reports == 1 ? 'report' : 'reports'}',
        ),
        if (band != null && band.isNotEmpty) _DetailRow('Confidence', band),
        if (alarm != null && alarm.isNotEmpty) _DetailRow('Alarm level', alarm),
        if (metres != null) _DetailRow('Distance', _formatDistance(metres)),
      ],
    );
  }

  void _showEvacSheet(Map<String, dynamic> s) {
    final capacity = (s['capacity'] as num?)?.toInt();
    final metres = _metresTo(
      (s['latitude'] as num).toDouble(),
      (s['longitude'] as num).toDouble(),
    );
    _detailSheet(
      accent: _safeGreen,
      icon: Icons.health_and_safety,
      tag: 'SHELTER',
      title: (s['name'] as String?) ?? 'Evacuation site',
      rows: [
        if (s['address'] != null) _DetailRow('Address', s['address'] as String),
        if (capacity != null) _DetailRow('Capacity', '$capacity people'),
        if (metres != null) _DetailRow('Distance', _formatDistance(metres)),
        if (s['contact_info'] != null)
          _DetailRow('Contact', s['contact_info'] as String),
      ],
    );
  }

  void _showFacilitySheet(Facility f, Color accent, IconData icon) {
    final metres = _metresTo(f.lat, f.lng);
    _detailSheet(
      accent: accent,
      icon: icon,
      tag: f.kind == FacilityKind.fire ? 'FIRE STATION' : 'POLICE STATION',
      title: f.name,
      rows: [
        _DetailRow('Details', f.subtitle),
        if (metres != null) _DetailRow('Distance', _formatDistance(metres)),
        const _DetailRow(
          'Note',
          'Approximate reference location, held in the app — not a live feed.',
        ),
      ],
    );
  }

  void _detailSheet({
    required Color accent,
    required IconData icon,
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
                  IconWell(tint: accent, icon: icon, size: 48, glyph: 24),
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
          SizedBox(width: 110, child: Eyebrow(row.label, color: AppColors.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.value,
              style: const TextStyle(
                fontSize: 13,
                height: 17 / 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desaturate and darken OSM's daylight tiles so they sit under a #131313 UI.
const List<double> _kNightMatrix = <double>[
  0.42, 0.28, 0.10, 0, -14, //
  0.36, 0.34, 0.10, 0, -14, //
  0.33, 0.28, 0.19, 0, -12, //
  0, 0, 0, 1, 0, //
];

/// One row in the "nearby right now" sheet, already measured against the user.
class _Nearby {
  const _Nearby({
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.art,
    required this.live,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color tint;
  final String art;
  final bool live;
  final VoidCallback onTap;
}

class _DetailRow {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
}
