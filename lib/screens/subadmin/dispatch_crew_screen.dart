import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/fleet_unit.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../../widgets/app_logo.dart';
import '../responder/responder_status.dart';

const Color _bg = AppColors.background;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _inner = AppColors.canvas;
const Color _row = AppColors.glassDim;
const Color _orangeTint = AppColors.accentTint;
const Color _avatarTint = Color(0x21FF9066);
const Color _muted = AppColors.muted;
const Color _roleGrey = AppColors.muted;
const Color _label = AppColors.label;
const Color _red = AppColors.live;
const Color _white40 = AppColors.muted;

const String _kDriverRole = 'Driver / Pump Op';
const List<String> _kCrewRoles = [
  'Team Lead',
  'Safety Officer',
  'Nozzleman',
  'Hose Tender',
  'Pump Operator',
  'Ventilation',
  'Search & Rescue',
  'Medic',
];

/// One person assigned to a unit, with their fireground role.
class _Assignment {
  _Assignment(this.responder, this.role);
  final Map<String, dynamic> responder;
  String role;

  String get id => responder['id'] as String;
  String get name => (responder['full_name'] as String?) ?? 'Responder';
  String? get organizationId => responder['organization_id'] as String?;
}

/// Per-unit crew built up before dispatch: one required driver + optional crew.
class _UnitCrew {
  _Assignment? driver;
  final List<_Assignment> crew = [];
}

/// Step 2 of 2 of the sub-admin dispatch flow: assign a driver (required) and
/// optional crew — each with a fireground role — to every selected truck, then
/// DISPATCH.
///
/// Each assigned responder becomes one POST /incidents/{id}/dispatch, with the
/// truck + role recorded in the dispatch notes (the backend has no truck-based
/// dispatch nor a crew-role field). On success pops `true`.
class DispatchCrewScreen extends StatefulWidget {
  const DispatchCrewScreen({
    super.key,
    required this.areaId,
    required this.units,
    this.api,
  });

  final String areaId;
  final List<FleetUnit> units;
  final ApiClient? api;

  @override
  State<DispatchCrewScreen> createState() => _DispatchCrewScreenState();
}

class _DispatchCrewScreenState extends State<DispatchCrewScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  late final Map<String, _UnitCrew> _assign = {
    for (final u in widget.units) u.id: _UnitCrew(),
  };

  List<Map<String, dynamic>> _responders = [];
  bool _loading = true;
  bool _dispatching = false;

  int get _readyCount =>
      widget.units.where((u) => _assign[u.id]?.driver != null).length;
  bool get _allReady => _readyCount == widget.units.length;

  @override
  void initState() {
    super.initState();
    _loadResponders();
  }

  Future<void> _loadResponders() async {
    try {
      final raw = await _api.getAvailableResponders(widget.areaId);
      if (!mounted) return;
      setState(() {
        _responders = raw.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // Ids already assigned (driver or crew) anywhere in this session.
  Set<String> _assignedIds() {
    final ids = <String>{};
    for (final c in _assign.values) {
      if (c.driver != null) ids.add(c.driver!.id);
      for (final a in c.crew) {
        ids.add(a.id);
      }
    }
    return ids;
  }

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.split(RegExp(r'\s+')).last[0].toUpperCase();
  }

  // ----------------------------------------------------------- assignment ---
  Future<void> _assignDriver(FleetUnit unit) async {
    final r = await _pickResponder();
    if (r != null && mounted) {
      setState(() => _assign[unit.id]!.driver = _Assignment(r, _kDriverRole));
    }
  }

  Future<void> _addCrew(FleetUnit unit) async {
    final r = await _pickResponder();
    if (r == null || !mounted) return;
    final role = await _pickRole();
    if (role == null || !mounted) return;
    setState(() => _assign[unit.id]!.crew.add(_Assignment(r, role)));
  }

  Future<Map<String, dynamic>?> _pickResponder() async {
    final taken = _assignedIds();
    final choices = _responders
        .where((r) => r['on_this_incident'] != true && !taken.contains(r['id']))
        .toList();
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabber(),
              const SizedBox(height: 16),
              const Text('Select responder',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (choices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No available responders to assign.',
                      style: TextStyle(color: AppColors.muted)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: choices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _responderRow(choices[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickRole() async {
    return showModalBottomSheet<String>(
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
              _grabber(),
              const SizedBox(height: 16),
              const Text('Assign role',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in _kCrewRoles)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(role),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _inner,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _panelBorder),
                        ),
                        child: Text(role,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grabber() => Center(
        child: const SheetHandle(),
      );

  Widget _responderRow(Map<String, dynamic> r) {
    final name = (r['full_name'] as String?) ?? 'Responder';
    final agency = responderAgencyLabel(r['agency_type'] as String?);
    final busy = r['is_busy'] == true;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _inner,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: _panelBorder),
        ),
        child: Row(
          children: [
            _avatar(name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(agency, style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
            if (busy)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _red.withValues(alpha: 0.4)),
                ),
                child: const Text('BUSY',
                    style: TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _avatarTint, shape: BoxShape.circle),
      child: Text(_initial(name),
          style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // -------------------------------------------------------------- dispatch ---
  Future<void> _dispatch() async {
    if (!_allReady || _dispatching) return;
    setState(() => _dispatching = true);

    // Flatten every assignment into one dispatch call each (truck + role).
    final calls = <(_Assignment, String)>[];
    for (final u in widget.units) {
      final c = _assign[u.id]!;
      if (c.driver != null) calls.add((c.driver!, u.name));
      for (final a in c.crew) {
        calls.add((a, u.name));
      }
    }

    var ok = 0;
    var failed = 0;
    for (final (a, vehicle) in calls) {
      try {
        await _api.dispatchResponder(
          widget.areaId,
          responderId: a.id,
          organizationId: a.organizationId,
          vehicleName: vehicle,
          crewRole: a.role,
          notes: '$vehicle · ${a.role}',
        );
        ok++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    if (failed == 0) {
      _toast('Dispatched $ok responder${ok == 1 ? '' : 's'}.');
      Navigator.of(context).pop(true);
    } else if (ok > 0) {
      _toast('$ok dispatched, $failed failed.');
      Navigator.of(context).pop(true);
    } else {
      setState(() => _dispatching = false);
      _toast('Dispatch failed. Check your connection.');
    }
  }

  // ---------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(),
                          const SizedBox(height: 16),
                          for (final unit in widget.units) ...[
                            _unitCard(unit),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
            ),
            _bottomBar(),
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
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'STEP 2 OF 2',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.80,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 6),
              Text('Assign crew',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              SizedBox(height: 6),
              Text('Each unit needs an assigned driver',
                  style: TextStyle(color: _white40, fontSize: 11, height: 1.64)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _panelBorder),
          ),
          child: Text(
            'READY  $_readyCount/${widget.units.length}',
            style: const TextStyle(
              color: _label,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _unitCard(FleetUnit unit) {
    final c = _assign[unit.id]!;
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Truck header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _orangeTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fire_truck_rounded, color: AppColors.accent, size: 30),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.5)),
                    Text(unit.subtitle,
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _driverBox(unit, c),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.groups_outlined, color: _label, size: 18),
              const SizedBox(width: 8),
              Text('CREW - ${c.crew.length}',
                  style: const TextStyle(
                      color: _label, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const Spacer(),
              _addResponderPill(() => _addCrew(unit)),
            ],
          ),
          const SizedBox(height: 12),
          _crewBox(unit, c),
        ],
      ),
    );
  }

  Widget _driverBox(FleetUnit unit, _UnitCrew c) {
    final driver = c.driver;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _inner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_taxi_outlined, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Text('DRIVER',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 10),
          if (driver == null)
            GestureDetector(
              onTap: () => _assignDriver(unit),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: const [
                  Icon(Icons.add, color: _red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Assign a driver to dispatch this unit',
                        style:
                            TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            )
          else
            _memberRow(driver, () => setState(() => c.driver = null)),
        ],
      ),
    );
  }

  Widget _crewBox(FleetUnit unit, _UnitCrew c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _inner,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: c.crew.isEmpty
          ? const Text('No crew assigned yet',
              style: TextStyle(color: Color(0x7FADAAAA), fontSize: 12, fontWeight: FontWeight.w500))
          : Column(
              children: [
                for (var i = 0; i < c.crew.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _memberRow(c.crew[i], () => setState(() => c.crew.removeAt(i))),
                ],
              ],
            ),
    );
  }

  Widget _memberRow(_Assignment a, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _row,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          _avatar(a.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(a.role, style: const TextStyle(color: _roleGrey, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.close, color: _muted, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _addResponderPill(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x1EFF8A5C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF8A5C), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add, color: AppColors.accent, size: 14),
            SizedBox(width: 6),
            Text('ADD RESPONDER',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final enabled = _allReady && !_dispatching;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _dispatching ? null : () => Navigator.of(context).pop(),
            child: Container(
              width: 57,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line, width: 0.8),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: GestureDetector(
                onTap: enabled ? _dispatch : null,
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
                  child: _dispatching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.accentText),
                        )
                      : const Text(
                          'DISPATCH',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.accentText,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.50,
                            letterSpacing: 1.60,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
