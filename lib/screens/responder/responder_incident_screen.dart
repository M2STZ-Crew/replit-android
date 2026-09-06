import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../api/api_client.dart';
import '../../models/fleet_unit.dart';
import '../../theme.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/design.dart';

const Color _bg = AppColors.background;
const Color _sheet = AppColors.surfaceSolid;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _rowBg = AppColors.glassDim;
const Color _orangeTint = AppColors.accentTint;
const Color _muted = AppColors.muted;
const Color _crewGrey = AppColors.muted;
const Color _youGreen = AppColors.ok;
const Color _otherBlue = AppColors.info;
const Color _red = AppColors.live;

/// The responder's active-incident command screen: live map (incident + other
/// responders + my GPS), address + route ETA, my unit/crew, the respond →
/// en-route → arrived progression with 5 s GPS streaming, the field escalations
/// (Need Water / Need Assistance / Escalate to BFP), and REQUEST FIRE OUT
/// (signals command via the Fire-Out code; the sub-admin resolves).
class ResponderIncidentScreen extends StatefulWidget {
  const ResponderIncidentScreen({super.key, required this.incidentId, required this.myId});

  final String incidentId;
  final String myId;

  @override
  State<ResponderIncidentScreen> createState() => _ResponderIncidentScreenState();
}

class _ResponderIncidentScreenState extends State<ResponderIncidentScreen> {
  final ApiClient _api = ApiClient();
  final MapController _map = MapController();
  Timer? _poll;
  Timer? _gps;

  Map<String, dynamic>? _incident;
  List<Map<String, dynamic>> _responders = [];
  List<Map<String, dynamic>> _dispatches = [];
  Map<String, dynamic>? _myDispatch;
  final Map<String, FleetUnit> _fleetByName = {};
  final Map<String, String> _fireCodeIds = {};

  LatLng? _myPos;
  String? _address;
  String? _etaText;

  bool _loading = true;
  bool _busy = false;
  bool _streaming = false;
  bool _pressing = false;
  bool _geocoded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStatics();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _gps?.cancel();
    super.dispose();
  }

  String get _status => (_incident?['status'] as String?) ?? 'pending';
  bool get _hasActiveDispatch => _myDispatch != null;
  bool get _active => const {'dispatched', 'en_route', 'arrived'}.contains(_status);
  bool get _shouldStream => _hasActiveDispatch && _active;

  LatLng? get _centroid {
    final i = _incident;
    final lat = (i?['centroid_lat'] as num?)?.toDouble();
    final lng = (i?['centroid_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getIncident(widget.incidentId),
        _api.getDispatches(widget.incidentId),
        _api.getResponderLocations(widget.incidentId),
      ]);
      final incident = results[0] as Map<String, dynamic>;
      final dispatches = (results[1] as List).cast<Map<String, dynamic>>();
      final responders = (results[2] as List).cast<Map<String, dynamic>>();
      Map<String, dynamic>? mine;
      for (final d in dispatches) {
        if (d['responder_id'] == widget.myId && d['status'] == 'active') {
          mine = d;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _incident = incident;
        _dispatches = dispatches;
        _responders = responders;
        _myDispatch = mine;
        _loading = false;
      });
      _syncStreaming();
      final c = _centroid;
      if (c != null && !_geocoded) {
        _geocoded = true;
        _reverseGeocode(c);
      }
      _computeEta();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStatics() async {
    try {
      final eq = await _api.getEquipment();
      for (final e in eq.cast<Map<String, dynamic>>()) {
        final u = FleetUnit.fromEquipment(e);
        _fleetByName[u.name] = u;
      }
    } catch (_) {
      // unit subtitle just falls back to "Fire Truck"
    }
    try {
      final codes = await _api.getFireCodes();
      for (final c in codes.cast<Map<String, dynamic>>()) {
        final n = c['code_number'] as String?;
        final id = c['id'] as String?;
        if (n != null && id != null) _fireCodeIds[n] = id;
      }
    } catch (_) {
      // escalation buttons will report unavailable
    }
    if (mounted) setState(() {});
  }

  // ----------------------------------------------------------- streaming ---
  void _syncStreaming() {
    if (_shouldStream && _gps == null) {
      _gps = Timer.periodic(const Duration(seconds: 5), (_) => _postGps());
      _postGps();
    } else if (!_shouldStream && _gps != null) {
      _gps?.cancel();
      _gps = null;
      if (mounted) setState(() => _streaming = false);
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _postGps() async {
    final pos = await _currentPosition();
    if (pos == null || !mounted) return;
    setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
    _computeEta();
    final dispatch = _myDispatch;
    if (dispatch == null) return;
    try {
      await _api.postResponderLocation(
        widget.incidentId,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy >= 0 ? pos.accuracy : null,
        speedMps: pos.speed >= 0 ? pos.speed : null,
        headingDeg: (pos.heading >= 0 && pos.heading < 360) ? pos.heading : null,
        dispatchId: dispatch['id'] as String?,
      );
      if (mounted) setState(() => _streaming = true);
    } catch (_) {
      // retry next tick
    }
  }

  // -------------------------------------------------------------- helpers ---
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
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _computeEta() async {
    final c = _centroid;
    if (c == null) {
      if (mounted) setState(() => _etaText = null);
      return;
    }
    LatLng? from = _myPos;
    if (from == null) {
      double best = double.infinity;
      for (final r in _responders) {
        final lat = (r['lat'] as num?)?.toDouble();
        final lng = (r['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final p = LatLng(lat, lng);
        final d = _haversineM(p, c);
        if (d < best) {
          best = d;
          from = p;
        }
      }
    }
    if (from == null) {
      if (mounted) setState(() => _etaText = null);
      return;
    }
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};${c.longitude},${c.latitude}?overview=false';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
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
    final secs = _haversineM(from, c) / (30000 / 3600);
    if (mounted) setState(() => _etaText = _fmtDuration(secs));
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ------------------------------------------------------------- actions ---
  Future<void> _action(Future<Map<String, dynamic>> Function() call, String ok) async {
    setState(() => _busy = true);
    try {
      await call();
      if (mounted) _toast(ok);
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Action failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _respond() => _action(() => _api.selfDispatch(widget.incidentId), 'You are now responding.');
  void _enRoute() => _action(() => _api.markEnRoute(widget.incidentId), 'Marked en route.');
  void _arrived() => _action(() => _api.markArrived(widget.incidentId), 'Marked on scene.');

  void _withdraw() {
    final d = _myDispatch;
    if (d == null) return;
    _action(() => _api.withdrawDispatch(widget.incidentId, d['id'] as String),
        'You withdrew from this incident.');
  }

  Future<void> _pressCode(String codeNumber, String label) async {
    if (_pressing) return;
    final id = _fireCodeIds[codeNumber];
    if (id == null) {
      _toast('$label is unavailable.');
      return;
    }
    setState(() => _pressing = true);
    try {
      await _api.pressFireCode(id, areaId: widget.incidentId);
      if (mounted) _toast('$label sent to command.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not send. Check your connection.');
    } finally {
      if (mounted) setState(() => _pressing = false);
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
      await _api.createAlarmRequest(areaId: widget.incidentId, alarmLevel: level);
      if (mounted) _toast('Alarm escalation requested.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not request escalation.');
    }
  }

  void _requestFireOut() {
    // The Fire-Out code (FC-3) broadcasts to command; the sub-admin resolves.
    _pressCode('FC-3', 'Fire out');
  }

  // --------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
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
                child: _fireOutButton(),
              ),
            ),
    );
  }

  Widget _mapHeader() {
    final c = _centroid ?? const LatLng(14.5378, 121.0014);
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: c,
              initialZoom: 15,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              MapTiles.layer(),
              MarkerLayer(markers: _markers(c)),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const BackWell(),
                const Spacer(),
                if (_streaming) _streamingPill(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _streamingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE6171717),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _youGreen),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location, color: _youGreen, size: 14),
          SizedBox(width: 6),
          Text('SHARING LOCATION',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
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
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x99FF544E), blurRadius: 14)],
          ),
          child: const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
        ),
      ),
    ];
    for (final r in _responders) {
      if (r['responder_id'] == widget.myId) continue;
      final lat = (r['lat'] as num?)?.toDouble();
      final lng = (r['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: _otherBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.local_shipping, color: Colors.white, size: 12),
        ),
      ));
    }
    if (_myPos != null) {
      markers.add(Marker(
        point: _myPos!,
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: _youGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x8022C55E), blurRadius: 12)],
          ),
        ),
      ));
    }
    return markers;
  }

  Widget _panelContent() {
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
              _myUnitCard(),
              const SizedBox(height: 16),
              _lifecycle(),
              ..._escalationsBlock(),
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
                    const Text('Live', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(_address ?? 'Locating incident…',
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.2)),
                const SizedBox(height: 5),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'ETA', style: TextStyle(color: _muted, fontSize: 16)),
                  TextSpan(
                    text: _etaText == null ? ' —' : ' $_etaText',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _myUnitCard() {
    final d = _myDispatch;
    final vehicle = (d?['vehicle_name'] as String?)?.trim();
    if (vehicle == null || vehicle.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _panelBorder),
        ),
        child: Text(
          _hasActiveDispatch ? 'You are responding (no unit assigned).' : 'No unit assigned to you.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    // Everyone crewing my vehicle on this incident.
    final crew = _dispatches
        .where((x) => x['status'] == 'active' && (x['vehicle_name'] as String?)?.trim() == vehicle)
        .toList();
    Map<String, dynamic>? driver;
    final others = <Map<String, dynamic>>[];
    for (final c in crew) {
      final role = (c['crew_role'] as String?)?.toLowerCase() ?? '';
      if (driver == null && role.contains('driver')) {
        driver = c;
      } else {
        others.add(c);
      }
    }
    final subtitle = _fleetByName[vehicle]?.subtitle ?? 'Fire Truck';

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
                    Text(vehicle,
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
              Expanded(child: _crewSlot('Driver', driver == null ? null : [driver])),
              const SizedBox(width: 12),
              Expanded(child: _crewSlot('Crew', others)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _crewSlot(String label, List<Map<String, dynamic>>? members) {
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
          Text(label == 'Crew' ? 'Crew · ${members?.length ?? 0}' : label,
              style: const TextStyle(color: _crewGrey, fontSize: 11)),
          const SizedBox(height: 8),
          if (members == null || members.isEmpty)
            const Text('—', style: TextStyle(color: _muted, fontSize: 13))
          else if (label == 'Driver')
            Text(
              (members.first['responder_name'] as String?) ?? 'Responder',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            )
          else
            _avatarStack(members),
        ],
      ),
    );
  }

  Widget _avatarStack(List<Map<String, dynamic>> members) {
    final shown = members.take(4).toList();
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

  // The respond → en-route → arrived progression + withdraw.
  Widget _lifecycle() {
    if (_status == 'resolved' || _status == 'rejected') {
      return _infoBox(
        Icons.flag_outlined,
        _status == 'resolved'
            ? 'This incident has been resolved. Stand down.'
            : 'This incident was rejected by command.',
      );
    }
    if (_status == 'pending') {
      return _infoBox(Icons.hourglass_empty,
          'Awaiting verification by command before responders can be assigned.');
    }

    final children = <Widget>[];
    if (!_hasActiveDispatch) {
      children.add(_gradientButton('RESPOND TO THIS INCIDENT', _respond));
    } else {
      if (_status == 'dispatched') {
        children.add(_gradientButton('MARK EN ROUTE', _enRoute));
      } else if (_status == 'en_route') {
        children.add(_gradientButton('MARK ARRIVED', _arrived));
      } else if (_status == 'arrived') {
        children.add(_infoBox(Icons.check_circle_outline, 'You are on scene.'));
      }
      children.add(const SizedBox(height: 8));
      children.add(Center(
        child: TextButton(
          onPressed: _busy ? null : _withdraw,
          child: const Text('Withdraw from incident',
              style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  List<Widget> _escalationsBlock() {
    if (!_hasActiveDispatch || !_active) return const [];
    return [
      const SizedBox(height: 16),
      const Text('Escalate alarm', style: TextStyle(color: Colors.white, fontSize: 16)),
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
    ];
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
      onTap: _pressing ? null : onTap,
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

  Widget _gradientButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: const [BoxShadow(color: AppColors.accentTint, blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentText),
              )
            : Text(label,
                style: const TextStyle(
                    color: AppColors.accentText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2)),
      ),
    );
  }

  Widget _infoBox(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.muted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _fireOutButton() {
    final enabled = _hasActiveDispatch && _status == 'arrived' && !_pressing;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? _requestFireOut : null,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: const [BoxShadow(color: AppColors.accentTint, blurRadius: 32, offset: Offset(0, 8))],
          ),
          child: const Text('REQUEST FIRE OUT',
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
