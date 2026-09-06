import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/fleet_unit.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../../widgets/app_logo.dart';
import 'dispatch_crew_screen.dart';

const Color _bg = AppColors.background;
const Color _panel = AppColors.glassDim;
const Color _panelBorder = AppColors.line;
const Color _orangeTint = AppColors.accentTint;
const Color _green = Color(0xFF00D492);
const Color _red = AppColors.live;
const Color _muted = AppColors.muted;
const Color _white40 = AppColors.muted;

/// Step 1 of 2 of the sub-admin dispatch flow: pick which fire trucks (units)
/// to deploy to a verified incident.
///
/// The fleet loads from GET /equipment (fire trucks only); if [fleet] is passed
/// it overrides the fetch, and a fetch failure/empty result falls back to
/// [kDemoFleet] so the screen still works in a demo. `CONTINUE` advances to
/// Step 2 (assign crew) when launched with an incident, else pops the selection.
class DispatchUnitsScreen extends StatefulWidget {
  const DispatchUnitsScreen({
    super.key,
    this.areaId,
    this.fleet,
    this.preselected = const {},
    this.api,
  });

  /// The incident (area) being dispatched to, if launched from one.
  final String? areaId;

  /// Explicit fleet override; when null the fleet loads from GET /equipment.
  final List<FleetUnit>? fleet;

  /// Unit ids to pre-tick (e.g. coming back from Step 2).
  final Set<String> preselected;

  final ApiClient? api;

  @override
  State<DispatchUnitsScreen> createState() => _DispatchUnitsScreenState();
}

class _DispatchUnitsScreenState extends State<DispatchUnitsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final Set<String> _selected = {...widget.preselected};

  late List<FleetUnit> _fleet = widget.fleet ?? const [];
  bool _loading = false;

  int get _availableCount => _fleet.where((u) => u.isAvailable).length;
  int get _engagedCount => _fleet.where((u) => !u.isAvailable).length;

  @override
  void initState() {
    super.initState();
    if (widget.fleet == null) {
      _loading = true;
      _loadFleet();
    }
  }

  Future<void> _loadFleet() async {
    try {
      final raw = await _api.getEquipment();
      final units = raw
          .cast<Map<String, dynamic>>()
          .where((e) => e['category'] == 'fire_truck')
          .map(FleetUnit.fromEquipment)
          .toList();
      if (!mounted) return;
      setState(() {
        _fleet = units.isNotEmpty ? units : kDemoFleet;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fleet = kDemoFleet; // fallback keeps the screen usable offline/in demo
        _loading = false;
      });
    }
  }

  void _toggle(FleetUnit unit) {
    if (!unit.isAvailable) return;
    setState(() {
      if (_selected.contains(unit.id)) {
        _selected.remove(unit.id);
      } else {
        _selected.add(unit.id);
      }
    });
  }

  Future<void> _continue() async {
    if (_selected.isEmpty) return;
    final chosen = _fleet.where((u) => _selected.contains(u.id)).toList();
    // Standalone/preview (no incident): just hand the selection back.
    if (widget.areaId == null) {
      Navigator.of(context).pop(chosen);
      return;
    }
    // Real flow: continue to Step 2 (assign crew) for this incident.
    final dispatched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DispatchCrewScreen(areaId: widget.areaId!, units: chosen),
      ),
    );
    if (dispatched == true && mounted) Navigator.of(context).pop(true);
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
                    const Text(
                      'STEP 1 OF 2',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.80,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select fire trucks',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose one or more units to deploy',
                      style: TextStyle(color: _white40, fontSize: 11, height: 1.64),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            count: _availableCount,
                            title: 'Available',
                            subtitle: 'Ready to deploy',
                            icon: Icons.check_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            count: _engagedCount,
                            title: 'Engaged',
                            subtitle: 'Currently on call',
                            icon: Icons.local_fire_department_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'FLEET',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.80,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final unit in _fleet) ...[
                      _fleetCard(unit),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            _continueBar(),
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

  Widget _statCard({
    required int count,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: AppText.numeral.copyWith(fontSize: 32),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _orangeTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppText.rowTitle.copyWith(fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _white40, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _fleetCard(FleetUnit unit) {
    final selected = _selected.contains(unit.id);
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.accent : _panelBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                Text(
                  unit.subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                Text(
                  unit.isAvailable ? 'AVAILABLE' : 'ON CALL',
                  style: TextStyle(
                    color: unit.isAvailable ? _green : _red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _selectionCircle(selected),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => _toggle(unit),
      behavior: HitTestBehavior.opaque,
      // On-call units are dimmed + non-selectable (Figma's 50% overlay).
      child: unit.isAvailable ? card : Opacity(opacity: 0.5, child: card),
    );
  }

  Widget _selectionCircle(bool selected) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected
            ? const LinearGradient(
                begin: Alignment(0.47, -0.47),
                end: Alignment(0.53, 1.47),
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              )
            : null,
        border: selected ? null : Border.all(color: _panelBorder),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: AppColors.accentText, size: 18)
          : null,
    );
  }

  Widget _continueBar() {
    final enabled = _selected.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: enabled ? _continue : null,
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
            child: const Text(
              'CONTINUE',
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
    );
  }
}
