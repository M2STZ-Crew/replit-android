import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../api/api_client.dart';
import '../../api/push_service.dart';
import '../../api/session.dart';
import '../../models/facility.dart';
import '../../theme.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/design.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/notification_bell.dart';
import '../login_screen.dart';
import '../responder/responder_status.dart';
import 'bfp_alarm_requests_screen.dart';

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
  final Future<List<LatLng>> Function()? loader;
}

/// BFP sub-admin dashboard — situational awareness (live counters + layered map)
/// plus the entry to the alarm-request review queue (BFP's exclusive authority,
/// master context v8 §6). BFP cannot verify/dispatch, so incident markers open a
/// read-only info sheet, not the verify/command screens.
class BfpDashboardScreen extends StatefulWidget {
  const BfpDashboardScreen({super.key, required this.me});

  final Map<String, dynamic> me;

  @override
  State<BfpDashboardScreen> createState() => _BfpDashboardScreenState();
}

class _BfpDashboardScreenState extends State<BfpDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();
  final ApiClient _api = ApiClient();
  final MapController _map = MapController();
  Timer? _poll;

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _incidents = [];
  int _pendingAlarms = 0;
  final Set<String> _enabled = {'incidents'};
  final Map<String, List<LatLng>> _cache = {};

  late final List<_LayerDef> _layers = [
    const _LayerDef('incidents', 'Incidents', _red, null),
    _LayerDef('evac', 'Evacuation Sites', _green,
        () async => _points(await _api.getEvacuationSites(), 'latitude', 'longitude')),
    _LayerDef('risk', 'Risk Areas', _orange,
        () async => _points(await _api.getRiskZones(), 'centroid_lat', 'centroid_lng')),
    _LayerDef('hydrants', 'Fire Hydrants', _grey,
        () async => _points(await _api.getHydrants(), 'latitude', 'longitude')),
    _LayerDef('water', 'Bodies of Water', _grey,
        () async => _points(await _api.getBodiesOfWater(), 'latitude', 'longitude')),
    _LayerDef('fire', 'Fire Department', _red,
        () async => kFireStations.map((f) => LatLng(f.lat, f.lng)).toList()),
    _LayerDef('police', 'Police Department', _blue,
        () async => kPoliceStations.map((f) => LatLng(f.lat, f.lng)).toList()),
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
      final results = await Future.wait([
        _api.getIncidentStats(),
        _api.getIncidents(),
        _api.getAlarmRequests(status: 'pending').catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _incidents = (results[1] as List).cast<Map<String, dynamic>>();
        _pendingAlarms = (results[2] as List).length;
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

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggleLayer(_LayerDef layer) async {
    if (layer.loader == null && layer.key != 'incidents') {
      _toast('${layer.label} layer is not in this build yet.');
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
        if (mounted) _toast('Could not load ${layer.label}.');
      }
    }
  }

  Future<void> _openAlarmRequests() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BfpAlarmRequestsScreen()));
    if (mounted) _load();
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: _statsGrid(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: _alarmCard(),
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
        (widget.me['full_name'] as String?) ?? (widget.me['email'] as String?) ?? 'BFP';
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
                  const Text('Sub-Admin • BFP',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Divider(color: _panelBorder, height: 1),
            _navTile(Icons.dashboard_outlined, 'Dashboard', () => Navigator.of(context).pop()),
            _navTile(Icons.campaign_outlined, 'Alarm Requests', () {
              Navigator.of(context).pop();
              _openAlarmRequests();
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
    return Row(
      children: [
        Expanded(
          child: _statCard('${s?['active_incidents'] ?? '–'}', 'Active Incidents',
              'In progress now', _red, Icons.warning_amber_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard('${s?['units_deployed'] ?? '–'}', 'Units Deployed',
              'On the way or on site', _orange, Icons.local_shipping_outlined),
        ),
      ],
    );
  }

  /// A dashboard figure. The design's stat leads with the number, heavy and
  /// tightly tracked, and puts the caption underneath — someone scanning a
  /// console needs the count first.
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

  Widget _alarmCard() {
    return GestureDetector(
      onTap: _openAlarmRequests,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pendingAlarms > 0 ? _red.withValues(alpha: 0.5) : _panelBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x23EF4444),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.campaign_outlined, color: _red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alarm Requests',
                      style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    _pendingAlarms > 0
                        ? '$_pendingAlarms pending • review & execute'
                        : 'No pending requests',
                    style: const TextStyle(color: Color(0xFF71717B), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (_pendingAlarms > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _red.withValues(alpha: 0.5)),
                ),
                child: Text('$_pendingAlarms',
                    style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w800)),
              )
            else
              const Icon(Icons.chevron_right, color: _grey, size: 20),
          ],
        ),
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
                      const Text('Live Map',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('Real-time incidents across Pasay City',
                          style: AppText.meta),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Updating live', style: TextStyle(color: _orange, fontSize: 10)),
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
            Text(layer.label,
                style: TextStyle(
                  color: on ? Colors.white : Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
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
        interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        MapTiles.layer(),
        MarkerLayer(markers: _markers()),
        MapTiles.attribution(),
      ],
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];
    for (final layer in _layers) {
      if (layer.key == 'incidents' || !_enabled.contains(layer.key)) continue;
      final pts = _cache[layer.key];
      if (pts == null) continue;
      for (final p in pts) {
        markers.add(Marker(
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
        ));
      }
    }
    if (_enabled.contains('incidents')) {
      for (final inc in _incidents) {
        final lat = (inc['centroid_lat'] as num?)?.toDouble();
        final lng = (inc['centroid_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final color = responderStatusColor((inc['status'] as String?) ?? 'pending');
        markers.add(Marker(
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
        ));
      }
    }
    return markers;
  }

  // Read-only incident info (BFP cannot verify/dispatch).
  void _incidentSheet(Map<String, dynamic> inc) {
    final status = (inc['status'] as String?) ?? 'pending';
    final color = responderStatusColor(status);
    final alarm = (inc['alarm_level'] as String?)?.replaceAll('_', ' ');
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
                    child: Text((inc['designation'] as String?) ?? 'Incident',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
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
              if (alarm != null && alarm.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.campaign_outlined, color: _red, size: 16),
                    const SizedBox(width: 8),
                    Text('Alarm: ${alarm.toUpperCase()}',
                        style: const TextStyle(color: _red, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const Text('BFP has read-only view of incidents. Use Alarm Requests to escalate.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
