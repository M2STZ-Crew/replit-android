import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/fleet_unit.dart';
import '../../models/post_incident_report.dart';
import '../../theme.dart';
import '../../widgets/design.dart';

export '../../models/post_incident_report.dart' show kCommonEquipment;

/// Equipment-register categories that are units rather than things carried.
const Set<String> _unitCategories = {'fire_truck', 'vehicle', 'truck'};

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
      backgroundColor: context.pal.surface,
      title: const Text(
        'Fire out recorded',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: Text(
        'File the Post-Incident Report now — units, driver, roster and equipment? '
        'The incident closes when it is filed. You can also do it later from Pending reports.',
        style: TextStyle(color: context.pal.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(false),
          child: Text('LATER', style: TextStyle(color: context.pal.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(true),
          child: Text(
            'FILE NOW',
            style: TextStyle(
              color: context.pal.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (fileNow == true) {
    final filed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostIncidentReportScreen(
          areaId: areaId,
          designation: designation,
          api: api,
        ),
      ),
    );
    return filed == true;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Fire out. The Post-Incident Report is waiting in Pending reports.',
      ),
    ),
  );
  return false;
}

/// The Post-Incident Report form (Master Context v10 §2.5).
///
/// Filed by each responding team's captain once the fire is out, for everyone
/// on their team who went. The first report closes the incident; another
/// team's captain adds theirs afterwards. Nothing on it is typed: the two times start from what the system
/// recorded and are changed with a picker, and the units, the driver, the
/// roster and the equipment are picked from the organisation's own register
/// and members. It is single-submit with no draft: the button only arms once
/// everything is picked, and filing closes the incident. Pops `true` when
/// filed.
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
  State<PostIncidentReportScreen> createState() =>
      _PostIncidentReportScreenState();
}

class _PostIncidentReportScreenState extends State<PostIncidentReportScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  /// When it happened and when the fire was out. They start as the system
  /// recorded them — the first report, and the Fire out press.
  DateTime? _incidentAt;
  DateTime? _fireOutAt;

  List<ReportUnit> _unitChoices = const [];
  final Set<String> _units = {};

  List<OrgMember> _members = const [];
  String? _driverId;
  final Set<String> _rosterIds = {};

  List<String> _equipmentChoices = kCommonEquipment;
  final Set<String> _equipment = {};

  /// v11 §2.5.3: the team reached the scene and found nothing. It must say
  /// what they found, so "false alarm" is never an unexplained tick — here by
  /// picking which of the cases it was.
  bool _falseAlarm = false;
  String? _falseAlarmReason;

  String? _designation;
  bool _loading = true;
  bool _submitting = false;

  /// The team could not be fetched — as opposed to fetched and empty, which
  /// means the captain's account is in no organisation.
  bool _teamFailed = false;

  @override
  void initState() {
    super.initState();
    _designation = widget.designation;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object?>([
        _api.getIncident(widget.areaId).catchError((_) => <String, dynamic>{}),
        _api.getDispatches(widget.areaId).catchError((_) => <dynamic>[]),
        _api.getEquipment().catchError((_) => <dynamic>[]),
        _api
            .getMyOrgMembers()
            .then<List<dynamic>?>((v) => v)
            .catchError((_) => null),
      ]);
      if (!mounted) return;
      final incident = results[0] as Map<String, dynamic>;
      final dispatches = (results[1] as List).cast<Map<String, dynamic>>();
      final register = (results[2] as List).cast<Map<String, dynamic>>();
      final prefill = PostIncidentPrefill.fromDispatches(dispatches);

      final fleet = [
        for (final e in register)
          if (_unitCategories.contains(e['category']))
            ReportUnit.fromFleet(FleetUnit.fromEquipment(e)),
      ];
      // A unit registered twice under one name is one choice.
      final units = <String, ReportUnit>{
        for (final u in fleet) u.name.toLowerCase(): u,
      }.values.toList();

      final carried = <String>[
        for (final e in register)
          if (!_unitCategories.contains(e['category']))
            ((e['name'] as String?) ?? '').trim(),
      ].where((n) => n.isNotEmpty);
      final equipment = <String>[];
      for (final item in [...carried, ...kCommonEquipment]) {
        if (!equipment.any((e) => e.toLowerCase() == item.toLowerCase())) {
          equipment.add(item);
        }
      }

      // The coordinator's own organisation, and nobody else: a captain files
      // for their team, and another team's people belong on that team's report.
      final fetched = results[3] as List<dynamic>?;
      final members = [
        for (final m in (fetched ?? const []).cast<Map<String, dynamic>>())
          OrgMember.fromJson(m),
      ];

      setState(() {
        _designation ??= incident['designation'] as String?;
        _incidentAt ??= _parse(incident['reported_at']);
        _fireOutAt ??= _parse(incident['resolved_at']);
        _unitChoices = units.isEmpty ? kGenericUnits : units;
        _equipmentChoices = equipment;
        _members = members;
        _teamFailed = fetched == null;

        // Start from what the response already recorded.
        final truck = prefill.truckLabel?.toLowerCase();
        for (final u in _unitChoices) {
          if (u.name.toLowerCase() == truck) _units.add(u.key);
        }
        // Of those who responded, the ones on this captain's team.
        for (final r in prefill.roster) {
          if (members.any((m) => m.id == r.userId)) _rosterIds.add(r.userId!);
        }
        final driver = prefill.driverUserId;
        if (driver != null && members.any((m) => m.id == driver)) {
          _driverId = driver;
          _rosterIds.add(driver);
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static DateTime? _parse(Object? iso) =>
      iso is String ? DateTime.tryParse(iso)?.toLocal() : null;

  static String _when(DateTime t) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '${months[t.month - 1]} ${t.day}, ${t.year} · '
        '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Change a time with the date and time pickers — picked, not typed.
  Future<void> _pickTime({required bool fireOut}) async {
    final now = DateTime.now();
    final current = (fireOut ? _fireOutAt : _incidentAt) ?? now;
    final start = current.isAfter(now) ? now : current;
    final floor = now.subtract(const Duration(days: 30));
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: start.isBefore(floor) ? start : floor,
      lastDate: now,
      helpText: fireOut ? 'Day the fire was out' : 'Day of the incident',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      helpText: fireOut ? 'Time the fire was out' : 'Time of the incident',
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isAfter(DateTime.now())) {
      _toast('That time has not happened yet.');
      return;
    }
    setState(() {
      if (fireOut) {
        _fireOutAt = picked;
      } else {
        _incidentAt = picked;
      }
    });
  }

  void _toggleUnit(ReportUnit unit) => setState(() {
    if (!_units.remove(unit.key)) _units.add(unit.key);
  });

  /// One driver. Whoever drives went, so they join the roster too.
  void _pickDriver(OrgMember member) => setState(() {
    _driverId = member.id;
    _rosterIds.add(member.id);
  });

  void _toggleRoster(OrgMember member) => setState(() {
    if (_rosterIds.remove(member.id)) {
      // Taken off the roster, they cannot still be the driver.
      if (_driverId == member.id) _driverId = null;
    } else {
      _rosterIds.add(member.id);
    }
  });

  void _toggleEquipment(String item) => setState(() {
    if (!_equipment.remove(item)) _equipment.add(item);
  });

  List<String> get _missing => missingPostIncidentFields(
    units: _units.length,
    hasDriver: _driverId != null,
    roster: _rosterIds.length,
    equipment: _equipment.length,
    incidentAt: _incidentAt,
    fireOutAt: _fireOutAt,
    falseAlarm: _falseAlarm,
    falseAlarmReason: _falseAlarmReason,
  );

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text(
          'File and close?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'The report is saved once and cannot be edited. Filing it closes the incident.',
          style: TextStyle(color: context.pal.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('REVIEW', style: TextStyle(color: context.pal.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(
              'FILE REPORT',
              style: TextStyle(
                color: context.pal.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final driver = _members.firstWhere((m) => m.id == _driverId);
    try {
      await _api.filePostIncidentReport(
        widget.areaId,
        incidentAt: _incidentAt,
        fireOutAt: _fireOutAt,
        units: [
          for (final u in _unitChoices)
            if (_units.contains(u.key)) u.toJson(),
        ],
        driverName: driver.name,
        driverUserId: driver.id,
        roster: [
          for (final m in _members)
            if (_rosterIds.contains(m.id))
              RosterMember(name: m.name, userId: m.id).toJson(),
        ],
        equipmentTaken: [
          for (final item in _equipmentChoices)
            if (_equipment.contains(item)) item,
        ],
        falseAlarm: _falseAlarm,
        falseAlarmNote: _falseAlarm ? _falseAlarmReason : null,
      );
      if (!mounted) return;
      _toast('Post-Incident Report filed.');
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
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: context.pal.accent),
              )
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
                  _section('When'),
                  _timeRow(
                    label: 'Time of the incident',
                    value: _incidentAt,
                    onTap: () => _pickTime(fireOut: false),
                  ),
                  const SizedBox(height: 8),
                  _timeRow(
                    label: 'Time the fire was out',
                    value: _fireOutAt,
                    onTap: () => _pickTime(fireOut: true),
                  ),
                  const SizedBox(height: 24),
                  _section('Units · ${_units.length}'),
                  _hint('Pick every unit that went.'),
                  _chips([
                    for (final u in _unitChoices)
                      _chip(
                        u.name,
                        selected: _units.contains(u.key),
                        onTap: () => _toggleUnit(u),
                      ),
                  ]),
                  const SizedBox(height: 24),
                  _section('Driver'),
                  if (_members.isEmpty)
                    _noTeam()
                  else ...[
                    _hint('Pick one.'),
                    _chips([
                      for (final m in _members)
                        _chip(
                          m.name,
                          selected: _driverId == m.id,
                          onTap: () => _pickDriver(m),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  _section('Roster · ${_rosterIds.length}'),
                  if (_members.isNotEmpty) ...[
                    _hint('Pick everyone who went, the driver included.'),
                    _chips([
                      for (final m in _members)
                        _chip(
                          m.name,
                          selected: _rosterIds.contains(m.id),
                          onTap: () => _toggleRoster(m),
                        ),
                    ]),
                  ] else
                    _hint('Your team has to load before you can pick.'),
                  const SizedBox(height: 24),
                  _section('Equipment taken · ${_equipment.length}'),
                  _hint('Pick everything that came off the units.'),
                  _chips([
                    for (final item in _equipmentChoices)
                      _chip(
                        item,
                        selected: _equipment.contains(item),
                        onTap: () => _toggleEquipment(item),
                      ),
                  ]),
                  const SizedBox(height: 24),
                  _section('False alarm'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _falseAlarm,
                    onChanged: (v) => setState(() {
                      _falseAlarm = v;
                      if (!v) _falseAlarmReason = null;
                    }),
                    activeThumbColor: context.pal.accent,
                    title: Text(
                      'We arrived and found nothing',
                      style: context.type.body,
                    ),
                    subtitle: Text(
                      'A prank, a fire already out, or the wrong address.',
                      style: context.type.meta,
                    ),
                  ),
                  if (_falseAlarm) ...[
                    const SizedBox(height: 8),
                    _hint('What did the team find? Pick one.'),
                    _chips([
                      for (final reason in kFalseAlarmReasons)
                        _chip(
                          reason,
                          selected: _falseAlarmReason == reason,
                          onTap: () =>
                              setState(() => _falseAlarmReason = reason),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 28),
                  if (missing.isNotEmpty) ...[
                    Text(
                      'Still needed: ${missing.join(', ')}',
                      style: context.type.meta.copyWith(
                        color: context.pal.warn,
                        height: 1.4,
                      ),
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
    return Panel(
      color: context.pal.glassDim,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconWell(
            tint: context.pal.accent,
            icon: Icons.assignment_turned_in_outlined,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Fire out. File this once, for everyone who went — just tap to '
              'pick. It closes the incident and cannot be edited afterwards.',
              style: context.type.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Eyebrow(label, color: context.pal.label),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: context.type.meta),
  );

  /// A time as the system has it, and a tap to change it.
  Widget _timeRow({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label. ${value == null ? 'Not set' : _when(value)}. Change.',
      excludeSemantics: true,
      child: Panel(
        radius: AppRadius.control,
        color: context.pal.glassDim,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.type.meta),
                  const SizedBox(height: 4),
                  Text(
                    value == null ? 'Tap to set' : _when(value),
                    style: context.type.rowTitle.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.schedule_rounded, color: context.pal.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _chips(List<Widget> chips) =>
      Wrap(spacing: 8, runSpacing: 8, children: chips);

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: context.pal.accentTint,
      backgroundColor: context.pal.glass,
      side: BorderSide(color: selected ? context.pal.accent : context.pal.line),
      labelStyle: TextStyle(
        color: selected ? context.pal.accent : context.pal.textSoft,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
    );
  }

  /// Nobody to pick: the team did not load, or this captain's account is in
  /// no organisation. Say which, and offer the one thing that can fix it here.
  Widget _noTeam() {
    return Panel(
      radius: AppRadius.control,
      color: context.pal.glassDim,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _teamFailed
                  ? 'Could not load your team. Check your connection.'
                  : 'Your account is not in an organization yet, so there is '
                        'nobody to pick. Ask the admin to add you to your team.',
              style: context.type.meta,
            ),
          ),
          TextButton(
            onPressed: _load,
            child: Text(
              'TRY AGAIN',
              style: TextStyle(
                color: context.pal.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
