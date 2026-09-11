import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/fleet_unit.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../responder/responder_status.dart';

/// Send responders to an incident (Master Context v10 §2.5).
///
/// During a response only what runs it is captured: who is going. The truck
/// each person crewed, the driver and everyone's role are recorded once the
/// fire is out, in the Post-Incident Report. So this is one screen where there
/// used to be two, and nothing on it is required beyond choosing people. It
/// replaced a flow that would not dispatch anyone until every truck had a
/// driver and every crew member a role.
///
/// A unit can still be tagged when the captain already knows it — one tap —
/// and the report starts from whatever was tagged here.
///
/// Pops `true` once at least one responder was dispatched.
class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key, required this.areaId, this.designation, this.api});

  final String areaId;
  final String? designation;
  final ApiClient? api;

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  List<Map<String, dynamic>> _responders = [];
  List<FleetUnit> _fleet = const [];
  final Set<String> _selected = {};
  String? _unitId;

  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getAvailableResponders(widget.areaId),
        // The fleet is optional here; a failure just hides the unit row.
        _api.getEquipment().catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _responders = results[0].cast<Map<String, dynamic>>();
        // Real trucks only. Unlike the old two-step flow this does not fall
        // back to a demo fleet — tagging a unit is optional, so an empty
        // register simply means no unit row.
        _fleet = results[1]
            .cast<Map<String, dynamic>>()
            .where((e) => e['category'] == 'fire_truck')
            .map(FleetUnit.fromEquipment)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load responders. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  FleetUnit? get _unit => _fleet.where((u) => u.id == _unitId).firstOrNull;

  Future<void> _dispatch() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    final unit = _unit;
    var ok = 0;
    var failed = 0;
    for (final r in _responders.where((r) => _selected.contains(r['id']))) {
      try {
        await _api.dispatchResponder(
          widget.areaId,
          responderId: r['id'] as String,
          organizationId: r['organization_id'] as String?,
          vehicleName: unit?.name,
        );
        ok++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    if (ok == 0) {
      setState(() => _sending = false);
      _toast('Dispatch failed. Check your connection.');
      return;
    }
    _toast(failed == 0
        ? 'Dispatched $ok responder${ok == 1 ? '' : 's'}.'
        : '$ok dispatched, $failed failed.');
    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final n = _selected.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                children: [
                  ScreenHeader(eyebrow: 'Dispatch', title: widget.designation ?? "Who's going?"),
                  const SizedBox(height: 14),
                  Text(
                    'Choose who is going. Truck, driver and roles are recorded after '
                    'fire out, in the Post-Incident Report.',
                    style: AppText.body.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    )
                  else if (_error != null)
                    Text(_error!, style: AppText.meta.copyWith(color: AppColors.live))
                  else ...[
                    Eyebrow('Responders · $n selected', color: AppColors.label),
                    const SizedBox(height: 10),
                    if (_responders.isEmpty)
                      Text('No responders in your agency to dispatch.', style: AppText.meta),
                    for (final r in _responders) ...[
                      _responderRow(r),
                      const SizedBox(height: 8),
                    ],
                    if (_fleet.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Eyebrow('Unit · optional', color: AppColors.label),
                      const SizedBox(height: 10),
                      _unitChips(),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: AppButton(
                n == 0 ? 'Choose who is going' : 'Dispatch $n responder${n == 1 ? '' : 's'}',
                icon: Icons.send_rounded,
                busy: _sending,
                onPressed: n == 0 ? null : _dispatch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _responderRow(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final name = (r['full_name'] as String?) ?? 'Responder';
    final here = r['on_this_incident'] == true;
    final busy = r['is_busy'] == true && !here;
    final selected = _selected.contains(id);
    return Opacity(
      opacity: here ? 0.55 : 1,
      child: Panel(
        onTap: here
            ? null
            : () => setState(() => selected ? _selected.remove(id) : _selected.add(id)),
        radius: AppRadius.control,
        color: selected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.glassDim,
        border: selected ? AppColors.accent : AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.rowTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(responderAgencyLabel(r['agency_type'] as String?), style: AppText.meta),
                ],
              ),
            ),
            if (here)
              const Tag('Responding', color: AppColors.ok)
            else if (busy)
              const Tag('On another call', color: AppColors.warn),
            const SizedBox(width: 10),
            Icon(
              here
                  ? Icons.check_circle
                  : selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
              color: here || selected ? AppColors.accent : AppColors.lineStrong,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitChips() {
    Widget chip(String label, String? id) {
      final on = _unitId == id;
      return ChoiceChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => setState(() => _unitId = id),
        selectedColor: AppColors.accentTint,
        backgroundColor: AppColors.glass,
        side: BorderSide(color: on ? AppColors.accent : AppColors.line),
        labelStyle: TextStyle(
          color: on ? AppColors.accent : AppColors.textSoft,
          fontWeight: FontWeight.w700,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Not yet', null),
        for (final u in _fleet.where((u) => u.isAvailable)) chip(u.name, u.id),
      ],
    );
  }
}
