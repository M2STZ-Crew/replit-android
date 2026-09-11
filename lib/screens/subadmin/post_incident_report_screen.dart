import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/fleet_unit.dart';
import '../../models/post_incident_report.dart';
import '../../theme.dart';
import '../../widgets/design.dart';

/// Things commonly taken off a unit, offered as one-tap additions so filing is
/// quick. Free text is always available — this list is a shortcut, not a
/// catalogue the backend knows about.
const List<String> kCommonEquipment = [
  'Hose line',
  'Nozzle',
  'SCBA',
  'Fire extinguisher',
  'Ladder',
  'Axe / Halligan',
  'First aid kit',
  'Hydrant key',
];

/// Right after fire out: offer the Post-Incident Report now, while the crew is
/// fresh in mind, or leave it in the Pending reports tray. Never blocking —
/// the response is over either way. Returns true if the report was filed.
///
/// Every place a coordinator can declare fire out calls this, so the offer is
/// the same from the command screen and from the review screen.
Future<bool> offerPostIncidentReport(
  BuildContext context, {
  required String areaId,
  String? designation,
  ApiClient? api,
}) async {
  final fileNow = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Fire out recorded',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      content: const Text(
        'File the Post-Incident Report now — truck, driver, roster and equipment? '
        'The incident closes when it is filed. You can also do it later from Pending reports.',
        style: TextStyle(color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(false),
          child: const Text('LATER', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(true),
          child: const Text('FILE NOW',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (fileNow == true) {
    final filed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostIncidentReportScreen(areaId: areaId, designation: designation, api: api),
      ),
    );
    return filed == true;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Fire out. The Post-Incident Report is waiting in Pending reports.')),
  );
  return false;
}

/// The Post-Incident Report form (Master Context v10 §2.5).
///
/// Filed by the responding team captain once the fire is out, for everyone who
/// went. It starts from what the dispatch log already knows — the truck, the
/// driver, the crew — so the captain confirms rather than re-types. It is
/// single-submit with no draft: the button only arms once every required field
/// is filled, and filing closes the incident. Pops `true` when filed.
class PostIncidentReportScreen extends StatefulWidget {
  const PostIncidentReportScreen({
    super.key,
    required this.areaId,
    this.designation,
    this.api,
  });

  final String areaId;
  final String? designation;
  final ApiClient? api;

  @override
  State<PostIncidentReportScreen> createState() => _PostIncidentReportScreenState();
}

class _PostIncidentReportScreenState extends State<PostIncidentReportScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  final _truck = TextEditingController();
  final _truckType = TextEditingController(text: 'Fire Truck');
  final _driver = TextEditingController();
  final _memberName = TextEditingController();
  final _memberRole = TextEditingController();
  final _equipmentItem = TextEditingController();
  final _notes = TextEditingController();

  List<FleetUnit> _fleet = const [];
  String? _truckEquipmentId;
  String? _driverUserId;
  final List<RosterMember> _roster = [];
  final List<String> _equipment = [];

  String? _designation;
  String? _resolvedAt;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _designation = widget.designation;
    for (final c in [_truck, _truckType, _driver]) {
      c.addListener(_changed);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _truck, _truckType, _driver, _memberName, _memberRole, _equipmentItem, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getIncident(widget.areaId).catchError((_) => <String, dynamic>{}),
        _api.getDispatches(widget.areaId).catchError((_) => <dynamic>[]),
        _api.getEquipment().catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      final incident = results[0] as Map<String, dynamic>;
      final dispatches = (results[1] as List).cast<Map<String, dynamic>>();
      final fleet = (results[2] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['category'] == 'fire_truck')
          .map(FleetUnit.fromEquipment)
          .toList();
      final prefill = PostIncidentPrefill.fromDispatches(dispatches);
      setState(() {
        _designation ??= incident['designation'] as String?;
        _resolvedAt = incident['resolved_at'] as String?;
        _fleet = fleet;
        if (prefill.truckLabel != null) _pickTruckByName(prefill.truckLabel!);
        if (prefill.driverName != null) {
          _driver.text = prefill.driverName!;
          _driverUserId = prefill.driverUserId;
        }
        _roster.addAll(prefill.roster);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickTruckByName(String name) {
    final unit = _fleet.where((u) => u.name == name).firstOrNull;
    _truck.text = name;
    _truckEquipmentId = unit?.id;
    if (unit != null) _truckType.text = unit.type;
  }

  void _pickUnit(FleetUnit unit) {
    setState(() {
      _truck.text = unit.name;
      _truckEquipmentId = unit.id;
      _truckType.text = unit.type;
    });
  }

  void _addMember() {
    final name = _memberName.text.trim();
    if (name.isEmpty) return;
    final role = _memberRole.text.trim();
    setState(() {
      _roster.add(RosterMember(name: name, role: role.isEmpty ? null : role));
      _memberName.clear();
      _memberRole.clear();
    });
  }

  void _addEquipment(String raw) {
    final item = raw.trim();
    if (item.isEmpty) return;
    final exists = _equipment.any((e) => e.toLowerCase() == item.toLowerCase());
    setState(() {
      if (!exists) _equipment.add(item);
      _equipmentItem.clear();
    });
  }

  List<String> get _missing => missingPostIncidentFields(
    truckLabel: _truck.text,
    truckType: _truckType.text,
    driverName: _driver.text,
    roster: _roster,
    equipment: _equipment,
  );

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('File and close?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'The report is saved once and cannot be edited. Filing it closes the incident.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('REVIEW', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('FILE REPORT',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      await _api.filePostIncidentReport(
        widget.areaId,
        // Set only by picking a fleet chip; typing a name clears it.
        truckEquipmentId: _truckEquipmentId,
        truckLabel: _truck.text.trim(),
        truckType: _truckType.text.trim(),
        driverName: _driver.text.trim(),
        driverUserId: _driverUserId,
        roster: _roster.map((m) => m.toJson()).toList(),
        equipmentTaken: List.of(_equipment),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      _toast('Post-Incident Report filed. Incident closed.');
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Could not file the report. Check your connection.');
      }
    }
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final missing = _missing;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  ScreenHeader(
                    eyebrow: 'Post-Incident Report',
                    title: _designation ?? 'Incident',
                  ),
                  const SizedBox(height: 18),
                  _intro(),
                  const SizedBox(height: 24),
                  _section('Unit'),
                  if (_fleet.isNotEmpty) ...[
                    _unitChips(),
                    const SizedBox(height: 12),
                  ],
                  _field(_truck, 'Unit name or plate', onChanged: (_) => _truckEquipmentId = null),
                  const SizedBox(height: 10),
                  _field(_truckType, 'Unit type'),
                  const SizedBox(height: 24),
                  _section('Driver'),
                  _field(_driver, 'Driver name', onChanged: (_) => _driverUserId = null),
                  const SizedBox(height: 24),
                  _section('Roster · ${_roster.length}'),
                  ..._roster.asMap().entries.map((e) => _memberRow(e.key, e.value)),
                  _addMemberRow(),
                  const SizedBox(height: 24),
                  _section('Equipment taken · ${_equipment.length}'),
                  _equipmentChips(),
                  const SizedBox(height: 10),
                  _suggestions(),
                  const SizedBox(height: 10),
                  _field(
                    _equipmentItem,
                    'Add an item',
                    onSubmitted: _addEquipment,
                    trailing: IconButton(
                      onPressed: () => _addEquipment(_equipmentItem.text),
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                      tooltip: 'Add item',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _section('Notes · optional'),
                  _field(_notes, 'Anything command should know', maxLines: 4),
                  const SizedBox(height: 28),
                  if (missing.isNotEmpty) ...[
                    Text(
                      'Still needed: ${missing.join(', ')}',
                      style: AppText.meta.copyWith(color: AppColors.warn, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AppButton(
                    'File report & close incident',
                    icon: Icons.task_alt_rounded,
                    busy: _submitting,
                    onPressed: missing.isEmpty ? _submit : null,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _intro() {
    final at = _resolvedAt == null ? null : DateTime.tryParse(_resolvedAt!)?.toLocal();
    final when = at == null
        ? null
        : '${at.hour % 12 == 0 ? 12 : at.hour % 12}:${at.minute.toString().padLeft(2, '0')} '
            '${at.hour < 12 ? 'AM' : 'PM'}';
    return Panel(
      color: AppColors.glassDim,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconWell(tint: AppColors.accent, icon: Icons.assignment_turned_in_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${when == null ? 'Fire out.' : 'Fire out at $when.'} File this once, for everyone '
              'who went. It closes the incident and cannot be edited afterwards.',
              style: AppText.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Eyebrow(label, color: AppColors.label),
  );

  Widget _field(
    TextEditingController c,
    String hint, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? trailing,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(hintText: hint, suffixIcon: trailing),
    );
  }

  Widget _unitChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final u in _fleet)
          ChoiceChip(
            label: Text(u.name),
            selected: _truckEquipmentId == u.id,
            onSelected: (_) => _pickUnit(u),
            selectedColor: AppColors.accentTint,
            backgroundColor: AppColors.glass,
            side: BorderSide(
              color: _truckEquipmentId == u.id ? AppColors.accent : AppColors.line,
            ),
            labelStyle: TextStyle(
              color: _truckEquipmentId == u.id ? AppColors.accent : AppColors.textSoft,
              fontWeight: FontWeight.w700,
            ),
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
      ],
    );
  }

  Widget _memberRow(int index, RosterMember m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        radius: AppRadius.control,
        color: AppColors.glassDim,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: AppText.rowTitle.copyWith(fontSize: 13)),
                  if (m.role != null && m.role!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(m.role!, style: AppText.meta),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _roster.removeAt(index)),
              icon: const Icon(Icons.close_rounded, color: AppColors.muted, size: 18),
              tooltip: 'Remove ${m.name}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _addMemberRow() {
    return Row(
      children: [
        Expanded(flex: 3, child: _field(_memberName, 'Name')),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _field(_memberRole, 'Role', onSubmitted: (_) => _addMember())),
        IconButton(
          onPressed: _addMember,
          icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.accent),
          tooltip: 'Add to roster',
        ),
      ],
    );
  }

  Widget _equipmentChips() {
    if (_equipment.isEmpty) {
      return Text('Nothing added yet.', style: AppText.meta);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in _equipment)
          InputChip(
            label: Text(item),
            onDeleted: () => setState(() => _equipment.remove(item)),
            backgroundColor: AppColors.glass,
            side: const BorderSide(color: AppColors.line),
            labelStyle: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600),
            deleteIconColor: AppColors.muted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
      ],
    );
  }

  Widget _suggestions() {
    final left = kCommonEquipment
        .where((s) => !_equipment.any((e) => e.toLowerCase() == s.toLowerCase()))
        .toList();
    if (left.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in left)
          ActionChip(
            label: Text('+ $s'),
            onPressed: () => _addEquipment(s),
            backgroundColor: Colors.transparent,
            side: const BorderSide(color: AppColors.line),
            labelStyle: const TextStyle(color: AppColors.label, fontSize: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
      ],
    );
  }
}
