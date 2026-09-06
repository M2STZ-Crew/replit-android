import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../api/api_client.dart';
import '../../api/push_service.dart';
import '../../api/session.dart';
import '../../models/facility.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/design.dart';
import '../../widgets/notification_bell.dart';
import '../login_screen.dart';
import 'responder_incident_screen.dart';
import 'responder_incidents_screen.dart';
import 'responder_status.dart';

const Color _bg = AppColors.background;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _red = AppColors.live;
const Color _orange = AppColors.accent;
const Color _green = AppColors.ok;
const Color _grey = AppColors.muted;
const Color _blue = AppColors.info;
const LatLng _pasay = LatLng(14.5378, 121.0014);

class _LayerDef {
  const _LayerDef(this.key, this.label, this.color, this.loader);
  final String key;
  final String label;
  final Color color;
  final Future<List<LatLng>> Function()? loader; // null → no backend layer
}

/// Responder dashboard — live counters + a layered operational map. Replaces the
/// plain feed: incidents are markers (tap → respond/advance), and the chips
/// toggle GIS layers (evacuation sites, hydrants, risk areas, etc.).
class ResponderHomeScreen extends StatefulWidget {
  const ResponderHomeScreen({super.key, required this.me});

  final Map<String, dynamic> me;

  @override
  State<ResponderHomeScreen> createState() => _ResponderHomeScreenState();
}

class _ResponderHomeScreenState extends State<ResponderHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();
  final ApiClient _api = ApiClient();
  final MapController _map = MapController();
  Timer? _poll;

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _incidents = [];
  final Set<String> _enabled = {'incidents'};
  final Map<String, List<LatLng>> _cache = {};

  String get _myId => widget.me['id'] as String? ?? '';

  late final List<_LayerDef> _layers = [
    const _LayerDef('incidents', 'Incidents', _red, null),
    _LayerDef('evac', 'Evacuation Sites', _green,
        () async => _points(await _api.getEvacuationSites(), 'latitude', 'longitude')),
    _LayerDef('risk', 'Risk Areas', _orange,
        () async => _points(await _api.getRiskZones(), 'centroid_lat', 'centroid_lng')),
    const _LayerDef('teams', 'Response Teams', _orange, null),
    _LayerDef('hydrants', 'Fire Hydrants', _grey,
        () async => _points(await _api.getHydrants(), 'latitude', 'longitude')),
    _LayerDef('water', 'Bodies of Water', _grey,
        () async => _points(await _api.getBodiesOfWater(), 'latitude', 'longitude')),
    _LayerDef('fire', 'Fire Department', _red,
        () async => kFireStations.map((f) => LatLng(f.lat, f.lng)).toList()),
    _LayerDef('police', 'Police Department', _blue,
        () async => kPoliceStations.map((f) => LatLng(f.lat, f.lng)).toList()),
    const _LayerDef('hospital', 'Hospital', _grey, null),
    const _LayerDef('barangay', 'Barangay Hall', _grey, null),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.getIncidentStats(), _api.getIncidents()]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _incidents = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // keep last known data
    }
  }

  List<LatLng> _points(List<dynamic> raw, String latKey, String lngKey) {
    final out = <LatLng>[];
    for (final e in raw) {
      final m = e as Map<String, dynamic>;
      final la = (m[latKey] as num?)?.toDouble();
      final ln = (m[lngKey] as num?)?.toDouble();
      if (la != null && ln != null) out.add(LatLng(la, ln));
    }
    return out;
  }

  Future<void> _toggleLayer(_LayerDef layer) async {
    if (layer.loader == null && layer.key != 'incidents') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${layer.label} layer is not in this build yet.')),
      );
      return;
    }
    if (_enabled.contains(layer.key)) {
      setState(() => _enabled.remove(layer.key));
      return;
    }
    setState(() => _enabled.add(layer.key));
    if (layer.loader != null && !_cache.containsKey(layer.key)) {
      try {
        final pts = await layer.loader!();
        if (mounted) setState(() => _cache[layer.key] = pts);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load ${layer.label}.')),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await PushService.instance.unregister();
    await _api.logout();
    await Session.instance.clear();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffold,
      backgroundColor: _bg,
      endDrawer: _drawer(),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: _statsGrid(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _mapCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _panelBorder)),
      ),
      child: Row(
        children: [
          const AppLogo(),
          const Spacer(),
          const NotificationBell(),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _scaffold.currentState?.openEndDrawer(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawer() {
    final name =
        (widget.me['full_name'] as String?) ?? (widget.me['email'] as String?) ?? 'Responder';
    return Drawer(
      backgroundColor: AppColors.surfaceSolid,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(),
                  const SizedBox(height: 16),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(responderAgencyLabel(widget.me['agency_type'] as String?),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Divider(color: _panelBorder, height: 1),
            _navTile(Icons.dashboard_outlined, 'Dashboard', () => Navigator.of(context).pop()),
            _navTile(Icons.list_alt_outlined, 'Incidents', () {
              Navigator.of(context).pop();
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => ResponderIncidentsScreen(me: widget.me)))
                  .then((_) {
                if (mounted) _load();
              });
            }),
            const Spacer(),
            const Divider(color: _panelBorder, height: 1),
            _navTile(Icons.logout, 'Log out', () {
              Navigator.of(context).pop();
              _logout();
            }, color: _red),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _navTile(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  // ------------------------------------------------------------ stats ---
  Widget _statsGrid() {
    final s = _stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard('${s?['active_incidents'] ?? '–'}', 'Active Incidents',
                  'In progress now', _red, Icons.warning_amber_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard('${s?['pending_verify'] ?? '–'}', 'Pending Verify',
                  'Awaiting review', _orange, Icons.fact_check_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard('${s?['units_deployed'] ?? '–'}', 'Units Deployed',
                  'On the way or on site', _orange, Icons.local_shipping_outlined),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard('${s?['units_standby'] ?? '–'}', 'Units Standby',
                  'Ready to respond', _grey, Icons.groups_outlined),
            ),
          ],
        ),
      ],
    );
  }

  /// A dashboard figure. The design's stat is the number first and heavy,
  /// with the label beneath — a responder glancing at this needs the count,
  /// not the caption.
  Widget _statCard(
    String value,
    String title,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      color: AppColors.glassDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.numeral.copyWith(fontSize: 30, color: color),
                ),
              ),
              const SizedBox(width: 8),
              IconWell(tint: color, icon: icon, size: 30, glyph: 15),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.meta,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- map card ---
  Widget _mapCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE MAP',
                        style: AppText.cardTitle.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Real-time incidents across Pasay City',
                        style: AppText.meta,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const LiveDot(color: _orange, size: 6),
                    const SizedBox(width: 8),
                    const Eyebrow('Updating live', color: _orange),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 38, child: _chipRow()),
          const SizedBox(height: 10),
          Expanded(child: _mapLayer()),
        ],
      ),
    );
  }

  Widget _chipRow() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _layers.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => _chip(_layers[i]),
    );
  }

  Widget _chip(_LayerDef layer) {
    final on = _enabled.contains(layer.key);
    return GestureDetector(
      onTap: () => _toggleLayer(layer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? layer.color.withValues(alpha: 0.12) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? layer.color : const Color(0xFF2A2A2A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: layer.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              layer.label,
              style: TextStyle(
                color: on ? Colors.white : Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapLayer() {
    return FlutterMap(
      mapController: _map,
      options: const MapOptions(
        initialCenter: _pasay,
        initialZoom: 13,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.m2stz.replit',
        ),
        MarkerLayer(markers: _markers()),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('© OpenStreetMap, © CARTO')],
        ),
      ],
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];

    // GIS layer points (small coloured dots).
    for (final layer in _layers) {
      if (layer.key == 'incidents' || !_enabled.contains(layer.key)) continue;
      final pts = _cache[layer.key];
      if (pts == null) continue;
      for (final p in pts) {
        markers.add(
          Marker(
            point: p,
            width: 16,
            height: 16,
            child: Container(
              decoration: BoxDecoration(
                color: layer.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
              ),
            ),
          ),
        );
      }
    }

    // Incidents (status-coloured, tappable) — drawn on top.
    if (_enabled.contains('incidents')) {
      for (final inc in _incidents) {
        final lat = (inc['centroid_lat'] as num?)?.toDouble();
        final lng = (inc['centroid_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final color = responderStatusColor((inc['status'] as String?) ?? 'pending');
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: () => _incidentSheet(inc),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14)],
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 15),
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  void _incidentSheet(Map<String, dynamic> inc) {
    final status = (inc['status'] as String?) ?? 'pending';
    final color = responderStatusColor(status);
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (inc['designation'] as String?) ?? 'Incident',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(responderStatusLabel(status),
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${(inc['report_count'] as num?)?.toInt() ?? 0} reports • '
                '${(inc['active_dispatch_count'] as num?)?.toInt() ?? 0} responding',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResponderIncidentScreen(
                        incidentId: inc['id'] as String,
                        myId: _myId,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Text(
                    'OPEN INCIDENT',
                    style: TextStyle(
                      color: AppColors.accentText,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
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
