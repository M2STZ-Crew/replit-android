import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../api/api_client.dart';
import '../../api/push_service.dart';
import '../../api/session.dart';
import '../../models/fleet_unit.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/placeholder_box.dart';
import '../login_screen.dart';

const Color _bg = AppColors.background;
const Color _sheet = AppColors.surfaceSolid;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _rowBg = AppColors.glassDim;
const Color _orangeTint = AppColors.accentTint;
const Color _muted = AppColors.muted;
const Color _crewGrey = AppColors.muted;
const Color _red = AppColors.live;

/// Sub-admin command screen for an ACTIVE (dispatched/en_route/arrived) incident:
/// live map + responder GPS, address + route ETA, the dispatched unit/crew, and
/// the escalation actions (Need Water / Need Assistance = fire codes; Escalate to
/// BFP = alarm request; FIRE OUT = resolve).
class SubAdminIncidentCommandScreen extends StatefulWidget {
  const SubAdminIncidentCommandScreen({
    super.key,
    required this.areaId,
    required this.me,
    this.api,
  });

  final String areaId;
  final Map<String, dynamic> me;
  final ApiClient? api;

  @override
  State<SubAdminIncidentCommandScreen> createState() =>
      _SubAdminIncidentCommandScreenState();
}

class _SubAdminIncidentCommandScreenState extends State<SubAdminIncidentCommandScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  Timer? _poll;
  final MapController _map = MapController();

  Map<String, dynamic>? _incident;
  List<Map<String, dynamic>> _responders = [];
  List<Map<String, dynamic>> _dispatches = [];
  final Map<String, FleetUnit> _fleetByName = {};
  final Map<String, String> _fireCodeIds = {}; // code_number -> id

  String? _address;
  String? _etaText;
  bool _loading = true;
  bool _busy = false;

  LatLng? get _centroid {
    final i = _incident;
    final lat = (i?['centroid_lat'] as num?)?.toDouble();
    final lng = (i?['centroid_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String get _status => (_incident?['status'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _api.getIncident(widget.areaId),
        _api.getDispatches(widget.areaId),
        _api.getResponderLocations(widget.areaId),
        _api.getEquipment().catchError((_) => <dynamic>[]),
        _api.getFireCodes().catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      _incident = results[0] as Map<String, dynamic>;
      _dispatches = (results[1] as List).cast<Map<String, dynamic>>();
      _responders = (results[2] as List).cast<Map<String, dynamic>>();
      for (final e in (results[3] as List).cast<Map<String, dynamic>>()) {
        final u = FleetUnit.fromEquipment(e);
        _fleetByName[u.name] = u;
      }
      for (final c in (results[4] as List).cast<Map<String, dynamic>>()) {
        final num = c['code_number'] as String?;
        final id = c['id'] as String?;
        if (num != null && id != null) _fireCodeIds[num] = id;
      }
      setState(() => _loading = false);
      final c = _centroid;
      if (c != null) _reverseGeocode(c);
      _computeEta();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _api.getIncident(widget.areaId),
        _api.getDispatches(widget.areaId),
        _api.getResponderLocations(widget.areaId),
      ]);
      if (!mounted) return;
      setState(() {
        _incident = results[0] as Map<String, dynamic>;
        _dispatches = (results[1] as List).cast<Map<String, dynamic>>();
        _responders = (results[2] as List).cast<Map<String, dynamic>>();
      });
      _computeEta();
    } catch (_) {
      // keep last good data
    }
  }

  Future<void> _reverseGeocode(LatLng p) async {
    try {
      final marks = await geo.placemarkFromCoordinates(p.latitude, p.longitude);
      if (marks.isEmpty) return;
      final m = marks.first;
      final parts = [m.street, m.subLocality, m.locality]
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
      if (mounted && parts.isNotEmpty) setState(() => _address = parts.take(2).join(', '));
    } catch (_) {
      // address stays null
    }
  }

  static double _haversineM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
  }

  String _fmtDuration(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  // Live route ETA from the nearest responder to the incident (OSRM, free/no key;
  // falls back to a straight-line estimate at ~30 km/h).
  Future<void> _computeEta() async {
    final c = _centroid;
    final locs = [
      for (final r in _responders)
        if ((r['lat'] as num?) != null && (r['lng'] as num?) != null)
          LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
    ];
    if (c == null || locs.isEmpty) {
      if (mounted) setState(() => _etaText = null);
      return;
    }
    LatLng nearest = locs.first;
    double best = double.infinity;
    for (final l in locs) {
      final d = _haversineM(l, c);
      if (d < best) {
        best = d;
        nearest = l;
      }
    }
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${nearest.longitude},${nearest.latitude};${c.longitude},${c.latitude}'
          '?overview=false';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final dur = (routes.first as Map)['duration'] as num;
        if (mounted) setState(() => _etaText = _fmtDuration(dur.toDouble()));
        return;
      }
    } catch (_) {
      // fall through to straight-line estimate
    }
    if (mounted) setState(() => _etaText = _fmtDuration(best / (30000 / 3600)));
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ----------------------------------------------------------- actions ---
  Future<void> _pressCode(String codeNumber, String label) async {
    final id = _fireCodeIds[codeNumber];
    if (id == null) {
      _toast('$label is unavailable.');
      return;
    }
    try {
      await _api.pressFireCode(id, areaId: widget.areaId);
      if (mounted) _toast('$label broadcast to units.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not broadcast. Check your connection.');
    }
  }

  Future<void> _escalateBfp() async {
    const levels = <(String, String)>[
      ('positive_fire_alarm', 'Positive Fire Alarm'),
      ('first_alarm', 'First Alarm'),
      ('second_alarm', 'Second Alarm'),
      ('general_alarm', 'General Alarm'),
    ];
    final level = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request alarm escalation',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Sent to BFP for review.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 14),
              for (final (value, label) in levels)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: _muted),
                  onTap: () => Navigator.of(context).pop(value),
                ),
            ],
          ),
        ),
      ),
    );
    if (level == null) return;
    try {
      await _api.createAlarmRequest(areaId: widget.areaId, alarmLevel: level);
      if (mounted) _toast('Alarm escalation requested.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not request escalation.');
    }
  }

  Future<void> _fireOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Fire out?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Mark this incident resolved and stop the response.',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('FIRE OUT',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await _api.resolveIncident(widget.areaId);
      if (!mounted) return;
      _toast('Incident resolved.');
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not resolve. Check your connection.');
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
    final resolved = _status == 'resolved' || _status == 'rejected';
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                SizedBox(height: 280, child: _mapHeader()),
                Expanded(child: _panelContent()),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: _fireOutButton(resolved),
              ),
            ),
    );
  }

  Widget _mapHeader() {
    final c = _centroid;
    return Stack(
      children: [
        Positioned.fill(
          child: c == null
              ? const PlaceholderBox(
                  width: double.infinity, height: double.infinity, label: 'NO LOCATION')
              : FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: c,
                    initialZoom: 15.5,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.m2stz.replit',
                    ),
                    MarkerLayer(markers: _markers(c)),
                  ],
                ),
        ),
        SafeArea(bottom: false, child: _topBar()),
      ],
    );
  }

  List<Marker> _markers(LatLng centroid) {
    final markers = <Marker>[
      Marker(
        point: centroid,
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: _red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x7FFF544E), blurRadius: 14)],
          ),
          child: const Icon(Icons.local_fire_department, color: Colors.white, size: 15),
        ),
      ),
    ];
    for (final r in _responders) {
      final lat = (r['lat'] as num?)?.toDouble();
      final lng = (r['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x7FFF9066), blurRadius: 12)],
          ),
          child: const Icon(Icons.local_shipping, color: Colors.white, size: 12),
        ),
      ));
    }
    return markers;
  }

  Widget _topBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          const AppLogo(),
          const Spacer(),
          GestureDetector(
            onTap: _accountSheet,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _accountSheet() {
    final name =
        (widget.me['full_name'] as String?) ?? (widget.me['email'] as String?) ?? 'Sub-Admin';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout, color: _red),
              title: const Text('Log out', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _panelContent() {
    final groups = _groupedDispatches();
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        decoration: const BoxDecoration(
          color: _sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _addressCard(),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                _emptyUnits()
              else
                for (final entry in groups.entries) ...[
                  _unitCard(entry.key, entry.value),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 8),
              const Text('Escalate alarm',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Broadcast a fire code to all responding units',
                  style: TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 12),
              _escalationRow(
                icon: Icons.water_drop_outlined,
                tint: const Color(0x1E3B82F6),
                iconColor: AppColors.info,
                title: 'Need Water',
                subtitle: 'Request additional water supply',
                onTap: () => _pressCode('FC-6', 'Need Water'),
              ),
              const SizedBox(height: 10),
              _escalationRow(
                icon: Icons.group_add_outlined,
                tint: const Color(0x1EF59E0B),
                iconColor: const Color(0xFFF59E0B),
                title: 'Need Assistance',
                subtitle: 'Request backup responders',
                onTap: () => _pressCode('FC-7', 'Need Assistance'),
              ),
              const SizedBox(height: 10),
              _escalationRow(
                icon: Icons.campaign_outlined,
                tint: const Color(0x23EF4444),
                iconColor: AppColors.live,
                title: 'Escalate to BFP',
                subtitle: 'Request alarm escalation to BFP',
                onTap: _escalateBfp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _orangeTint, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.location_on_outlined, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Live',
                        style: TextStyle(color: AppColors.accent, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _address ?? 'Locating incident…',
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.2),
                ),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'ETA', style: TextStyle(color: _muted, fontSize: 16)),
                    TextSpan(
                      text: _etaText == null ? ' —' : ' $_etaText',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Group active dispatches by truck; null vehicle (self-dispatch) under one key.
  Map<String, List<Map<String, dynamic>>> _groupedDispatches() {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final d in _dispatches) {
      if (d['status'] != 'active') continue;
      final v = (d['vehicle_name'] as String?)?.trim();
      m.putIfAbsent(v == null || v.isEmpty ? 'Self-dispatched' : v, () => []).add(d);
    }
    return m;
  }

  Widget _emptyUnits() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: const Text('No active units on this incident.',
          style: TextStyle(color: AppColors.muted, fontSize: 13)),
    );
  }

  Widget _unitCard(String vehicleName, List<Map<String, dynamic>> crew) {
    final unit = _fleetByName[vehicleName];
    final subtitle = unit?.subtitle ?? 'Fire Truck';
    Map<String, dynamic>? driver;
    final others = <Map<String, dynamic>>[];
    for (final d in crew) {
      final role = (d['crew_role'] as String?)?.toLowerCase() ?? '';
      if (driver == null && role.contains('driver')) {
        driver = d;
      } else {
        others.add(d);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(color: _orangeTint, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.fire_truck_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicleName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(subtitle,
                        style: const TextStyle(color: _muted, fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _driverBox(driver)),
              const SizedBox(width: 12),
              Expanded(child: _crewBox(others)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _driverBox(Map<String, dynamic>? driver) {
    return Container(
      height: 87,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.local_taxi_outlined, color: _crewGrey, size: 14),
              SizedBox(width: 6),
              Text('Driver', style: TextStyle(color: _crewGrey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            driver == null ? '—' : ((driver['responder_name'] as String?) ?? 'Responder'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            driver == null ? '' : ((driver['crew_role'] as String?) ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _crewBox(List<Map<String, dynamic>> crew) {
    return Container(
      height: 87,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_outlined, color: _crewGrey, size: 14),
              const SizedBox(width: 6),
              Text('Crew · ${crew.length}', style: const TextStyle(color: _crewGrey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          crew.isEmpty
              ? const Text('—', style: TextStyle(color: _muted, fontSize: 13))
              : _avatarStack(crew),
        ],
      ),
    );
  }

  Widget _avatarStack(List<Map<String, dynamic>> crew) {
    final shown = crew.take(4).toList();
    return SizedBox(
      height: 28,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: _rowBg),
                ),
                child: Text(
                  _initial((shown[i]['responder_name'] as String?) ?? '?'),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.split(RegExp(r'\s+')).last[0].toUpperCase();
  }

  Widget _escalationRow({
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _rowBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _fireOutButton(bool resolved) {
    if (resolved) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('INCIDENT RESOLVED',
            style: TextStyle(
                color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
      );
    }
    return Opacity(
      opacity: _busy ? 0.5 : 1,
      child: GestureDetector(
        onTap: _busy ? null : _fireOut,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: const [
              BoxShadow(color: AppColors.accentTint, blurRadius: 32, offset: Offset(0, 8)),
            ],
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentText),
                )
              : const Text('FIRE OUT',
                  style: TextStyle(
                    color: AppColors.accentText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  )),
        ),
      ),
    );
  }
}
