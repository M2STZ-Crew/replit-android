import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../location/place_names.dart';
import '../../models/fleet_unit.dart';
import '../../models/post_incident_report.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import 'report_filed_screen.dart';

export '../../models/post_incident_report.dart' show kCommonEquipment;

/// Equipment-register categories that are units rather than things carried.
const Set<String> _unitCategories = {'fire_truck', 'vehicle', 'truck'};

/// Right after fire out: offer the Post-Incident Report now, while the crew is
/// fresh in mind, or leave it in the queue's To file. Never blocking — the
/// response is over either way. Returns true if the report was filed.
///
/// Every place a coordinator can declare fire out calls this, so the offer is
/// the same from LIVE and from the Area.
Future<bool> offerPostIncidentReport(
  BuildContext context, {
  required String areaId,
  String? designation,
  ApiClient? api,
}) async {
  final fileNow = await showFrameSheet<bool>(
    context,
    builder: (sheet) => SheetFrame(
      children: [
        const SheetTitles(
          eyebrow: 'Fire out recorded',
          title: 'File the report now?',
          body:
              'The trucks, the driver, the crew and what came off the units — '
              'while the crew is fresh in mind. The Area closes when it is '
              'filed. It also waits in the queue, under To file.',
        ),
        const SizedBox(height: 16),
        AppButton(
          'File the report',
          run: true,
          onPressed: () => Navigator.of(sheet).pop(true),
        ),
        const SizedBox(height: 10),
        AppButton.secondary(
          'Later',
          onPressed: () => Navigator.of(sheet).pop(false),
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
      content: Text('Fire out. The report waits in the queue, under To file.'),
    ),
  );
  return false;
}

/// The Post-Incident Report (Master Context v10 §2.5; REPLIT (MAIN) 06 · C13).
///
/// Filed by each responding team's captain once the fire is out, for everyone
/// on their team who went. The first report closes the incident; another
/// team's captain adds theirs afterwards.
///
/// The outcome, the trucks, the driver, the crew and the equipment are picked
/// from the organisation's own register and members, starting from what the
/// response recorded (the unit named on an Accept, who responded). Notes are
/// the one thing typed: optional, except for a false alarm, which must say
/// what the team found — a quick pick does, or the notes. The AI summary
/// reads them. The two times start as the system recorded them and change
/// with a picker. It is single-submit with no draft: the button only arms
/// once everything is picked, and filing closes the incident. Pops `true`
/// when filed.
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
  final TextEditingController _notes = TextEditingController();

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
  /// what they found, so "false alarm" is never an unexplained tick.
  bool _falseAlarm = false;
  String? _falseAlarmReason;

  String? _designation;
  String? _street;
  bool _loading = true;
  bool _submitting = false;

  /// The team could not be fetched — as opposed to fetched and empty, which
  /// means the captain's account is in no organisation.
  bool _teamFailed = false;

  @override
  void initState() {
    super.initState();
    _designation = widget.designation;
    _notes.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
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
      final lat = (incident['centroid_lat'] as num?)?.toDouble();
      final lng = (incident['centroid_lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final place = await PlaceNames.of(lat, lng);
        if (mounted) setState(() => _street = place.street);
      }
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
    return '${months[t.month - 1]} ${t.day}, ${t.year} · ${_clock(t)}';
  }

  static String _clock(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String get _areaName {
    final d = _designation ?? 'Incident';
    return d.toLowerCase().startsWith('area') ? d : 'Area $d';
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

  /// One driver. Whoever drives went, so they join the crew too.
  void _pickDriver(OrgMember member) => setState(() {
    _driverId = member.id;
    _rosterIds.add(member.id);
  });

  void _toggleRoster(OrgMember member) => setState(() {
    if (_rosterIds.remove(member.id)) {
      // Taken off the crew, they cannot still be the driver.
      if (_driverId == member.id) _driverId = null;
    } else {
      _rosterIds.add(member.id);
    }
  });

  void _toggleEquipment(String item) => setState(() {
    if (!_equipment.remove(item)) _equipment.add(item);
  });

  /// What a false alarm says the team found: the quick pick, the notes, or
  /// both.
  String? get _falseAlarmNote {
    final notes = _notes.text.trim();
    final parts = [?_falseAlarmReason, if (notes.isNotEmpty) notes];
    return parts.isEmpty ? null : parts.join('. ');
  }

  List<String> get _missing => missingPostIncidentFields(
    units: _units.length,
    hasDriver: _driverId != null,
    roster: _rosterIds.length,
    equipment: _equipment.length,
    incidentAt: _incidentAt,
    fireOutAt: _fireOutAt,
    falseAlarm: _falseAlarm,
    falseAlarmReason: _falseAlarmNote,
  );

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// The units, in a sheet: every one that went.
  Future<void> _chooseUnits() async {
    await showFrameSheet<void>(
      context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) => SheetFrame(
          children: [
            const SheetTitles(
              eyebrow: 'Truck',
              title: 'Which vehicles went?',
              body: 'Pick every unit that went to this fire.',
            ),
            const SizedBox(height: 12),
            for (final u in _unitChoices)
              CheckRow(
                label: _unitLabel(u),
                checked: _units.contains(u.key),
                onTap: () => set(() => _toggleUnit(u)),
              ),
            const SizedBox(height: 12),
            AppButton(
              'Done',
              run: true,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// The driver, in a sheet: one of the team.
  Future<void> _chooseDriver() async {
    if (_members.isEmpty) return;
    await showFrameSheet<void>(
      context,
      builder: (sheet) => SheetFrame(
        children: [
          const SheetTitles(
            eyebrow: 'Driver',
            title: 'Who drove?',
            body: 'Whoever drove went, so they join the crew too.',
          ),
          const SizedBox(height: 12),
          for (final m in _members)
            RadioRow(
              label: m.name,
              selected: _driverId == m.id,
              onTap: () {
                _pickDriver(m);
                Navigator.of(sheet).pop();
              },
            ),
        ],
      ),
    );
  }

  static String _unitLabel(ReportUnit u) {
    final type = u.type?.trim();
    return type == null ||
            type.isEmpty ||
            type.toLowerCase() == u.name.toLowerCase()
        ? u.name
        : '${u.name} · ${type.toLowerCase()}';
  }

  Future<void> _submit() async {
    final confirm = await showFrameSheet<bool>(
      context,
      builder: (sheet) => SheetFrame(
        children: [
          SheetTitles(
            eyebrow: 'Confirm · can\'t be undone',
            title: 'Submit and close $_areaName?',
            body:
                'The report saves once and cannot be edited. Filing it closes '
                'the Area.',
          ),
          const SizedBox(height: 16),
          AppButton(
            'Submit and close Area',
            run: true,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            'Review',
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final driver = _members.firstWhere((m) => m.id == _driverId);
    final notes = _notes.text.trim();
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
        notes: notes.isEmpty ? null : notes,
        falseAlarm: _falseAlarm,
        falseAlarmNote: _falseAlarm ? _falseAlarmNote : null,
      );
      if (!mounted) return;
      // 06 · C14: what filing did, and the narrative being written. Whoever
      // opened the form still hears that it was filed.
      await navigator.pushReplacement<bool, bool>(
        MaterialPageRoute(
          builder: (_) => ReportFiledScreen(
            areaId: widget.areaId,
            designation: _designation,
            api: _api,
          ),
        ),
        result: true,
      );
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
    final out = _fireOutAt;
    return Scaffold(
      backgroundColor: context.pal.background,
      bottomNavigationBar: _loading
          ? null
          : ActionBar(
              children: [
                if (missing.isNotEmpty)
                  Text(
                    'Still needed: ${missing.join(', ')}',
                    textAlign: TextAlign.center,
                    style: context.type.caption.copyWith(
                      color: context.pal.warn,
                    ),
                  ),
                AppButton(
                  'Submit and close Area',
                  run: true,
                  busy: _submitting,
                  onPressed: missing.isEmpty ? _submit : null,
                ),
              ],
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(
              eyebrow: [_areaName, ?_street].join(' · '),
              title: 'Post-incident report',
              subtitle: out == null ? null : 'Fire out ${_clock(out)}',
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.pal.accent,
                      ),
                    )
                  : ScrollFade(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          kScrollFadeEndPadding,
                        ),
                        children: _form(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _form() {
    const gap = SizedBox(height: 16);
    final chosenUnits = [
      for (final u in _unitChoices)
        if (_units.contains(u.key)) u,
    ];
    final driver = _members.where((m) => m.id == _driverId).firstOrNull;
    return [
      const InlineAlert(
        tone: AlertTone.warning,
        body:
            'Fill it in one go. There is no draft — the Area closes when this '
            'saves.',
      ),
      gap,
      const SectionHeader('Outcome'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          PickChip(
            label: 'Fire attended',
            selected: !_falseAlarm,
            onTap: () => setState(() {
              _falseAlarm = false;
              _falseAlarmReason = null;
            }),
          ),
          PickChip(
            label: 'False alarm',
            selected: _falseAlarm,
            onTap: () => setState(() => _falseAlarm = true),
          ),
        ],
      ),
      Text(
        'False alarm means the team arrived and found nothing — a prank, a '
        'wrong address, or already out. It must say what they found.',
        style: context.type.caption.copyWith(color: context.pal.label),
      ),
      if (_falseAlarm) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final reason in kFalseAlarmReasons)
              PickChip(
                label: reason,
                selected: _falseAlarmReason == reason,
                onTap: () => setState(
                  () => _falseAlarmReason = _falseAlarmReason == reason
                      ? null
                      : reason,
                ),
              ),
          ],
        ),
      ],
      gap,
      _SelectField(
        label: 'Truck',
        value: chosenUnits.isEmpty
            ? null
            : chosenUnits.map(_unitLabel).join(', '),
        placeholder: 'Pick the units that went',
        helper: chosenUnits.length > 1
            ? 'Which vehicles went'
            : 'Which vehicle went',
        onTap: _chooseUnits,
      ),
      gap,
      if (_members.isEmpty)
        _noTeam()
      else
        _SelectField(
          label: 'Driver',
          value: driver?.name,
          placeholder: 'Pick the driver',
          onTap: _chooseDriver,
        ),
      gap,
      SectionHeader(
        'Crew who went out',
        meta: _members.isEmpty ? null : '${_rosterIds.length} selected',
      ),
      const SizedBox(height: 4),
      if (_members.isEmpty)
        Text(
          'Your team has to load before you can pick.',
          style: context.type.bodySm,
        )
      else
        for (final m in _members)
          CheckRow(
            label: m.id == _driverId ? '${m.name} — Driver' : m.name,
            checked: _rosterIds.contains(m.id),
            onTap: () => _toggleRoster(m),
          ),
      gap,
      Text(
        'Equipment taken',
        style: context.type.label.copyWith(color: context.pal.textSoft),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          for (final item in _equipmentChoices)
            PickChip(
              label: item,
              selected: _equipment.contains(item),
              onTap: () => _toggleEquipment(item),
            ),
        ],
      ),
      Text(
        'Only what left the unit.',
        style: context.type.detail.copyWith(color: context.pal.label),
      ),
      gap,
      LabeledField(
        label: 'Notes',
        builder: (focus) => TextField(
          controller: _notes,
          focusNode: focus,
          minLines: 4,
          maxLines: 10,
          maxLength: 2000,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: context.type.input,
          decoration: const InputDecoration(counterText: ''),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _falseAlarm
            ? 'Required for a false alarm unless you picked what the team '
                  'found. The AI summary turns this into the formal narrative.'
            : 'Optional. The AI summary turns this into the formal narrative.',
        style: context.type.detail.copyWith(color: context.pal.label),
      ),
      gap,
      const SectionHeader('Times'),
      const SizedBox(height: 12),
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
    ];
  }

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
      child: ListRow(
        leading: const IconPlate(AppIcons.schedule),
        title: label,
        subtitle: value == null ? 'Tap to set' : _when(value),
        trailing: Text(
          'Change',
          style: context.type.label.copyWith(color: context.pal.accentInk),
        ),
        onTap: onTap,
      ),
    );
  }

  /// Nobody to pick: the team did not load, or this captain's account is in
  /// no organisation. Say which, and offer the one thing that can fix it here.
  Widget _noTeam() {
    return InlineAlert(
      tone: _teamFailed ? AlertTone.danger : AlertTone.warning,
      title: _teamFailed ? 'Could not load your team' : 'No team to pick from',
      body: _teamFailed
          ? 'Could not load your team. Check your connection.'
          : 'Your account is not in an organization yet, so there is nobody '
                'to pick. Ask the admin to add you to your team.',
      action: 'Try again',
      onAction: _load,
    );
  }
}

/// A picked value in the Text field's frame (label above, 54px inset field,
/// helper under): tapping opens the picker.
class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.helper,
  });

  final String label;
  final String? value;
  final String placeholder;
  final String? helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final shape = BorderRadius.circular(AppRadius.control);
    return Semantics(
      button: true,
      label: '$label: ${value ?? placeholder}',
      excludeSemantics: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: context.type.label.copyWith(color: pal.textSoft)),
          const SizedBox(height: 8),
          Material(
            color: pal.inputBg,
            borderRadius: shape,
            child: InkWell(
              borderRadius: shape,
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: shape,
                  border: Border.all(color: pal.lineStrong),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value ?? placeholder,
                        style: context.type.input.copyWith(
                          color: value == null
                              ? pal.placeholder
                              : pal.onBackground,
                        ),
                      ),
                    ),
                    Icon(
                      AppIcons.keyboardArrowDown,
                      size: 20,
                      color: pal.label,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 8),
            Text(
              helper!,
              style: context.type.detail.copyWith(color: pal.label),
            ),
          ],
        ],
      ),
    );
  }
}
