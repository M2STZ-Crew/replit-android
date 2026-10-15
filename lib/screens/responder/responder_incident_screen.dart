import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../api/api_client.dart';
import '../../api/live_refresh.dart';
import '../../location/live_position.dart';
import '../../location/place_names.dart';
import '../../location/responder_tracker.dart';
import '../../models/area_view.dart';
import '../../models/fleet_unit.dart';
import '../../navigation/routing_service.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/area_map_preview.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_shell.dart' show StaffAccount;
import '../coordinator/area_decision_screen.dart' show openRouteToArea;
import '../coordinator/report_detail_screen.dart';
import 'responder_status.dart';

/// One Area, as a responder sees it (REPLIT (MAIN) 07).
///
/// Not on it: the brief (R03) — where it is, how sure, who reported it, what
/// they asked for — and "I am going" (R04), which verifies a Reported Area
/// first and then puts this responder on the way (v12 §2.5.2), straight into
/// the route choice (R05).
///
/// On it: the run — on the way, on scene (R09) or stood down after fire out
/// (R10) — with what happens next, the crew, Mark arrived (R08) and the codes
/// a crew sends command (Need water, Need assistance, Escalate to BFP, Fire
/// out). RUN on the bar shows this view of the current run ([embedded]).
///
/// It follows the Area on the live socket ([LiveRefresh]), so a verify,
/// respond or reject by someone else shows at once. Location sharing is
/// [ResponderTracker]'s, not this screen's: it starts here when the responder
/// has an active dispatch and carries on after they leave, until the dispatch
/// ends ("5 s while dispatched", §6).
///
/// Response Teams exist in all five agencies. [agency] decides which codes
/// are offered: water and fire out to fire crews, the BFP escalation to Fire
/// Volunteer responders only — the server refuses anyone else (§2.7.1).
class ResponderIncidentScreen extends StatefulWidget {
  const ResponderIncidentScreen({
    super.key,
    required this.incidentId,
    required this.myId,
    this.agency,
    this.orgId,
    this.unit,
    this.api,
    this.tracker,
    this.embedded = false,
    this.onBackToDuty,
  });

  final String incidentId;
  final String myId;
  final String? agency;
  final String? orgId;

  /// The unit the responder goes as ("Tanker 1"); their team, when not given.
  final String? unit;
  final ApiClient? api;
  final ResponderTracker? tracker;

  /// RUN's view of the current run: a tab, so no Back.
  final bool embedded;

  /// "Back to duty" once the run is over; Back, when not given.
  final VoidCallback? onBackToDuty;

  @override
  State<ResponderIncidentScreen> createState() =>
      _ResponderIncidentScreenState();
}

class _ResponderIncidentScreenState extends State<ResponderIncidentScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ResponderTracker _tracker =
      widget.tracker ?? ResponderTracker.instance;
  final DriveTime _driveTime = DriveTime();
  Timer? _poll;
  late final LiveRefresh _live = LiveRefresh([
    incidentChannel(widget.incidentId),
  ], () => _load(silent: true));

  Map<String, dynamic>? _incident;
  List<Map<String, dynamic>> _dispatches = [];
  Map<String, dynamic>? _myDispatch;
  final Map<String, FleetUnit> _fleetByName = {};
  final Map<String, String> _fireCodeIds = {};

  String? _etaText;
  DateTime? _lastEta;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _tracker.position.addListener(_onTracker);
    _tracker.sharingFor.addListener(_onTracker);
    _load();
    _loadStatics();
    _live.start();
    _poll = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_live.dispose());
    // The tracker keeps sharing after this screen closes — that is the point.
    _tracker.position.removeListener(_onTracker);
    _tracker.sharingFor.removeListener(_onTracker);
    super.dispose();
  }

  // ------------------------------------------------------------- state ---
  AreaView? get _area => _incident == null ? null : AreaView(_incident!);
  String get _status => (_incident?['status'] as String?) ?? 'reported';
  bool get _hasActiveDispatch => _myDispatch != null;
  bool get _streaming => _tracker.sharingFor.value == widget.incidentId;
  bool get _onGround => const {'en_route', 'arrived'}.contains(_status);
  bool get _shouldStream => _hasActiveDispatch && _onGround;
  bool get _fireCrew => isFireCrew(widget.agency);

  /// This responder went: any dispatch of theirs on it, ended or not.
  bool get _wentToIt =>
      _dispatches.any((d) => d['responder_id'] == widget.myId);

  /// The run view: on the way or on scene, or stood down from it.
  bool get _onRun =>
      _hasActiveDispatch || (_wentToIt && kAfterFireOut.contains(_status));

  String get _unit {
    final given = widget.unit?.trim();
    if (given != null && given.isNotEmpty) return given;
    final team = (StaffAccount.current?['organization_name'] as String?)
        ?.trim();
    if (team != null && team.isNotEmpty) return team;
    return agencyLabel(widget.agency);
  }

  LatLng? get _here {
    final p = _tracker.position.value;
    if (p != null) return LatLng(p.latitude, p.longitude);
    return LivePosition.instance.here.value;
  }

  void _onTracker() {
    if (!mounted) return;
    setState(() {});
    // The route ETA is a network call; once every 15 s is plenty.
    final now = DateTime.now();
    if (_lastEta == null ||
        now.difference(_lastEta!) > const Duration(seconds: 15)) {
      _lastEta = now;
      _computeEta();
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _incident == null) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getIncident(widget.incidentId),
        _api.getDispatches(widget.incidentId),
      ]);
      final incident = results[0] as Map<String, dynamic>;
      final dispatches = (results[1] as List).cast<Map<String, dynamic>>();
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
        _myDispatch = mine;
        _loading = false;
        _error = null;
      });
      _syncStreaming();
      _computeEta();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Keep showing what was there; say so only when there is nothing.
        if (_incident == null) {
          _error = e is ApiException
              ? e.message
              : 'Could not load this Area. Check your signal.';
        }
      });
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
      // The crew row just says "Fire truck".
    }
    try {
      final codes = await _api.getFireCodes();
      for (final c in codes.cast<Map<String, dynamic>>()) {
        final n = c['code_number'] as String?;
        final id = c['id'] as String?;
        if (n != null && id != null) _fireCodeIds[n] = id;
      }
    } catch (_) {
      // The code rows say they are unavailable when pressed.
    }
    if (mounted) setState(() {});
  }

  /// Start sharing when this responder has an active dispatch on an Area on
  /// the ground; stop when the read shows it has ended here (fire out). The
  /// tracker also stops itself when the server refuses a point.
  void _syncStreaming() {
    final dispatchId = _myDispatch?['id'] as String?;
    if (_shouldStream && dispatchId != null) {
      _tracker.start(incidentId: widget.incidentId, dispatchId: dispatchId);
    } else if (!_shouldStream && _streaming) {
      _tracker.stop();
    }
  }

  Future<void> _computeEta() async {
    final to = _area?.centre;
    final from = _here;
    if (to == null || from == null || _status != 'en_route') {
      if (mounted && _etaText != null) setState(() => _etaText = null);
      return;
    }
    // By road, traffic-aware, as the directions route it; else at 30 km/h.
    final secs =
        await _driveTime.seconds(from, to) ??
        metresBetween(from, to) / (30000 / 3600);
    final s = secs.round();
    if (mounted) {
      setState(
        () => _etaText = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
      );
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ----------------------------------------------------------- actions ---
  Future<void> _action(Future<Object?> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      if (mounted) _toast(done);
    } on ApiException catch (e) {
      // Refused because the screen was behind (someone acted first): the
      // read below shows what is true now.
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('That did not go through. Check your signal.');
    } finally {
      await _load(silent: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// R04 — Go to Area 1.2? Then R05, the route choice.
  Future<void> _go(AreaView area) async {
    final reported = area.status == 'reported';
    final yes = await showFrameSheet<bool>(
      context,
      builder: (context) => SheetFrame(
        children: [
          SheetTitles(
            eyebrow: '${area.name} — ${LifecycleChip.word(area.status)}',
            title: 'Go to ${area.name}?',
            body:
                'You go as $_unit. Your position is shared every 5 seconds '
                'until the Captain marks fire out.',
          ),
          if (reported) ...[
            const SizedBox(height: 16),
            const InlineAlert(
              body:
                  'This Area is still Reported. Going now verifies it for '
                  'every agency — Coordinators can still reject it later.',
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            'I am going',
            run: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            'Cancel, go back',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      // Verify first: responding is only open once an Area is verified.
      if (reported) await _api.verifyIncident(widget.incidentId);
      await _api.selfDispatch(widget.incidentId);
      await _load(silent: true);
      if (!mounted) return;
      _toast('You are going. Your location is shared while you go.');
      setState(() => _busy = false);
      await _navigate();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
      await _load(silent: true);
    } catch (_) {
      if (mounted) _toast('That did not go through. Check your signal.');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  void _verifyOnly() => _action(
    () => _api.verifyIncident(widget.incidentId),
    'Verified. Go from here if you are going.',
  );

  /// Turn-by-turn to the Area (R05, R06). While on the way, arriving ends
  /// the navigation and marks this responder arrived (R08).
  Future<void> _navigate() async {
    final area = _area;
    if (area == null) return;
    await openRouteToArea(
      context,
      area,
      markArrived: _hasActiveDispatch && _status == 'en_route'
          ? () => _api.markArrived(widget.incidentId)
          : null,
    );
    if (mounted) await _load(silent: true);
  }

  /// R08 — Mark arrived?
  Future<void> _markArrived(AreaView area) async {
    final yes = await showFrameSheet<bool>(
      context,
      builder: (context) => SheetFrame(
        children: [
          SheetTitles(
            eyebrow: '${area.name} — ${LifecycleChip.word(area.status)}',
            title: 'Mark arrived?',
            body:
                'Command and the other units see you on scene. It is the last '
                'status you set; the Captain marks fire out.',
          ),
          const SizedBox(height: 20),
          AppButton(
            'Mark arrived',
            run: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            'Not yet',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _action(
      () => _api.markArrived(widget.incidentId),
      'Marked on scene.',
    );
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
      if (mounted) _toast('Could not send. Check your signal.');
    } finally {
      if (mounted) setState(() => _pressing = false);
    }
  }

  Future<void> _escalateBfp(AreaView area) async {
    const levels = <(String, String)>[
      ('positive_fire_alarm', 'Positive fire alarm'),
      ('first_alarm', 'First alarm'),
      ('second_alarm', 'Second alarm'),
      ('general_alarm', 'General alarm'),
    ];
    final level = await showFrameSheet<String>(
      context,
      builder: (context) => SheetFrame(
        children: [
          SheetTitles(
            eyebrow: area.name,
            title: 'Ask BFP to raise the alarm',
            body: 'BFP reviews the request and sets the level.',
          ),
          const SizedBox(height: 16),
          for (final (value, label) in levels) ...[
            ListRow(
              title: label,
              chevron: true,
              onTap: () => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
    if (level == null || !mounted) return;
    try {
      await _api.createAlarmRequest(
        areaId: widget.incidentId,
        alarmLevel: level,
      );
      if (mounted) _toast('Alarm request sent to BFP.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not send the request. Check your signal.');
    }
  }

  /// Every report in the Area, each opening as staff see it.
  Future<void> _openReports(AreaView area) async {
    List<Map<String, dynamic>> reports;
    try {
      reports = (await _api.getIncidentReports(
        widget.incidentId,
      )).cast<Map<String, dynamic>>();
    } catch (_) {
      if (mounted) _toast('Could not load the reports. Check your signal.');
      return;
    }
    if (!mounted) return;
    await showFrameSheet<void>(
      context,
      builder: (sheet) => SheetFrame(
        children: [
          SheetTitles(
            eyebrow: area.name,
            title: reports.length == 1
                ? '1 report'
                : '${reports.length} reports',
            body: 'Photos are for staff only.',
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Text('No reports could be read.', style: context.type.bodySm),
          for (final (i, r) in reports.indexed) ...[
            _reportRow(r, i, sheet),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _reportRow(Map<String, dynamic> r, int i, BuildContext sheet) {
    final pct = (r['user_verified_percent'] as num?)?.toInt() ?? 0;
    final at = parseTime(r['created_at']);
    final photo = r['photo_url'] is String;
    return ListRow(
      leading: IconPlate(photo ? AppIcons.photo : AppIcons.person),
      title: 'Resident · $pct% verified',
      subtitle: [if (at != null) clockText(at), if (photo) 'photo'].join(' · '),
      chevron: true,
      onTap: () => Navigator.of(sheet).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportDetailScreen(report: r, number: i + 1),
        ),
      ),
    );
  }

  void _backToDuty() {
    final back = widget.onBackToDuty;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final area = _area;
    final Widget body;
    if (area == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(title: 'Area'),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: context.pal.accent),
                  )
                : EmptyState(
                    icon: AppIcons.cloudOff,
                    tone: context.pal.live,
                    title: 'Could not load this Area',
                    body: _error ?? 'Check your signal and try again.',
                    action: AppButton.secondary(
                      'Try again',
                      onPressed: () => _load(),
                    ),
                  ),
          ),
        ],
      );
    } else {
      body = AreaPlace(
        area: area,
        builder: (context, place) =>
            _onRun ? _run(area, place) : _brief(area, place),
      );
    }
    if (widget.embedded) return SafeArea(bottom: false, child: body);
    return Scaffold(
      backgroundColor: context.pal.background,
      bottomNavigationBar: area == null || _onRun ? null : _briefActions(area),
      body: SafeArea(bottom: _onRun || area == null, child: body),
    );
  }

  Widget _header({required String title, String? eyebrow, String? subtitle}) =>
      widget.embedded
      ? TabHeader(title: title, eyebrow: eyebrow, subtitle: subtitle)
      : DetailHeader(title: title, eyebrow: eyebrow, subtitle: subtitle);

  Widget _list(List<Widget> children) => Expanded(
    child: ScrollFade(
      child: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            (widget.embedded ? MediaQuery.paddingOf(context).bottom : 0) +
                kScrollFadeEndPadding,
          ),
          children: children,
        ),
      ),
    ),
  );

  // --------------------------------------------------- R03 Area brief ---
  Widget _brief(AreaView area, PlaceName place) {
    final pal = context.pal;
    final here = _here;
    final centre = area.centre;
    final away = here == null || centre == null
        ? null
        : '${formatDistance(metresBetween(here, centre))} from you';
    final subtitle = [?place.line, ?away].join(' — ');
    final reported = area.reportedAt;
    final asked = askedFor(area.requested);
    final routing = routingLabel(
      area.raw,
      agency: widget.agency,
      orgId: widget.orgId,
    );
    final verifier = verifierLine(area.raw);
    const gap = SizedBox(height: 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          eyebrow: area.name,
          title: place.street ?? area.name,
          subtitle: subtitle.isEmpty ? null : subtitle,
        ),
        _list([
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LifecycleChip(area.status),
              if (routing != null) Tag(routing, color: pal.ok, dot: true),
            ],
          ),
          const SizedBox(height: 16),
          if (centre != null) ...[
            AreaMapPreview(centres: [centre], label: area.name),
            const SizedBox(height: 16),
          ],
          ConfidenceMeter(area: area),
          const SizedBox(height: 16),
          ListRow(
            title: 'Reports',
            trailing: RowValue(
              area.reports == 1 ? '1 resident' : '${area.reports} residents',
              color: pal.onBackground,
            ),
            chevron: true,
            onTap: () => _openReports(area),
          ),
          gap,
          ListRow(
            title: 'First reported',
            trailing: RowValue(
              reported == null ? '—' : clockText(reported),
              color: pal.onBackground,
            ),
          ),
          gap,
          ListRow(
            title: 'Agencies asked',
            trailing: RowValue(
              asked.isEmpty ? '—' : asked,
              color: pal.onBackground,
            ),
          ),
          if (verifier != null) ...[
            gap,
            ListRow(title: 'Verified by', subtitle: verifier),
          ],
          if (centre != null && area.active) ...[
            gap,
            ListRow(
              leading: const IconPlate(AppIcons.directions),
              title: 'Route to the Area',
              subtitle: 'Directions only — going is I am going',
              chevron: true,
              onTap: _navigate,
            ),
          ],
          if (!area.toDecide && !area.active) ...[
            const SizedBox(height: 16),
            InlineAlert(
              tone: area.status == 'rejected' || area.status == 'merged'
                  ? AlertTone.danger
                  : AlertTone.info,
              title: switch (area.status) {
                'rejected' => '${area.name} was rejected',
                'merged' => '${area.name} was merged',
                _ => '${area.name} is over',
              },
              body: switch (area.status) {
                'rejected' => 'A coordinator rejected it. Nobody goes.',
                'merged' =>
                  'Its reports joined a neighbouring Area. Go from that one.',
                _ =>
                  'The fire is out. Nothing is asked of a unit that did not '
                      'go.',
              },
            ),
          ],
        ]),
      ],
    );
  }

  Widget _briefActions(AreaView area) {
    final open = area.toDecide || area.active;
    return ActionBar(
      children: [
        if (open)
          AppButton(
            'I am going',
            run: true,
            busy: _busy,
            onPressed: _busy ? null : () => _go(area),
          ),
        if (area.toDecide)
          AppButton.secondary(
            'Verify, without going',
            onPressed: _busy ? null : _verifyOnly,
          )
        else
          AppButton.secondary('Back to duty', onPressed: _backToDuty),
      ],
    );
  }

  // ------------------------------------------------- R09 / R10 the run ---
  Widget _run(AreaView area, PlaceName place) {
    final over = kAfterFireOut.contains(_status);
    final out = area.at('resolved_at');
    final title = switch (_status) {
      'en_route' => 'On the way',
      'arrived' => 'On scene',
      'rejected' => 'Rejected',
      _ => 'Stood down',
    };
    final subtitle = over && out != null
        ? 'Fire out at ${clockText(out)}.'
        : [
            ?place.line,
            if (_status == 'en_route' && _etaText != null) 'ETA $_etaText',
          ].join(' — ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          eyebrow: '${area.name} — ${LifecycleChip.word(_status)}',
          title: title,
          subtitle: subtitle.isEmpty ? null : subtitle,
        ),
        _list([
          if (_status == 'rejected')
            InlineAlert(
              tone: AlertTone.danger,
              title: '${area.name} was rejected',
              body:
                  'A coordinator rejected it while you were going. Your '
                  'location sharing has stopped.',
            )
          else
            LifecycleRail(status: _status),
          const SizedBox(height: 16),
          _sharingAlert(over),
          if (_status == 'en_route') ...[
            const SizedBox(height: 16),
            AppButton(
              'Navigate',
              run: true,
              icon: AppIcons.directions,
              onPressed: _busy ? null : _navigate,
            ),
            const SizedBox(height: 10),
            AppButton.secondary(
              'Mark arrived',
              onPressed: _busy ? null : () => _markArrived(area),
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(over ? 'What happened' : 'What happens next'),
          const SizedBox(height: 4),
          ..._steps(area),
          if (_crew() case final crew?) ...[
            const SizedBox(height: 16),
            const SectionHeader('Your unit'),
            const SizedBox(height: 12),
            crew,
          ],
          if (_hasActiveDispatch && _onGround) ...[
            const SizedBox(height: 20),
            SectionHeader(_fireCrew ? 'Codes to command' : 'Call for help'),
            const SizedBox(height: 12),
            ..._codes(area),
          ],
          if (over || _status == 'rejected') ...[
            const SizedBox(height: 20),
            AppButton.secondary('Back to duty', onPressed: _backToDuty),
          ],
        ]),
      ],
    );
  }

  Widget _sharingAlert(bool over) {
    if (over || _status == 'rejected') {
      return const InlineAlert(
        tone: AlertTone.success,
        title: 'Location sharing stopped',
        body: 'Nothing more is asked of you for this Area.',
      );
    }
    if (!_streaming) {
      return const InlineAlert(
        tone: AlertTone.warning,
        title: 'Your location is not going out',
        body:
            'Allow RepLiT to use your location, so command can see you while '
            'you are on this run.',
      );
    }
    return InlineAlert(
      title: _status == 'arrived'
          ? 'Your location is still shared'
          : 'Your location is shared',
      body: _status == 'arrived'
          ? 'It stops on its own when the Captain marks fire out.'
          : 'Every 5 seconds while you go. It stops when the Captain marks '
                'fire out.',
    );
  }

  /// What happens next on a run (R09), and what has (R10): real times from
  /// the Area, never an invented one.
  List<Widget> _steps(AreaView area) {
    final arrived = area.at('arrived_at');
    final out = area.at('resolved_at');
    final closed = _status == 'closed';
    final filed = area.at('closed_at');
    return [
      ProgressStep(
        state: arrived == null ? ProgressState.pending : ProgressState.done,
        title: arrived == null ? 'Arrived' : 'Arrived ${clockText(arrived)}',
        detail: arrived == null
            ? 'Marked on its own when you reach the Area, or by you'
            : 'The Area was marked arrived',
      ),
      ProgressStep(
        state: out == null ? ProgressState.pending : ProgressState.done,
        title: out == null ? 'Fire out' : 'Fire out ${clockText(out)}',
        detail: 'The Captain calls it on scene',
      ),
      ProgressStep(
        state: out == null ? ProgressState.pending : ProgressState.done,
        title: out == null ? 'Stood down' : 'Stood down ${clockText(out)}',
        detail: out == null
            ? 'Location sharing stops'
            : 'Your location is no longer shared',
      ),
      ProgressStep(
        state: closed ? ProgressState.done : ProgressState.pending,
        title: closed && filed != null
            ? 'Post-incident report ${clockText(filed)}'
            : 'Post-incident report',
        detail: 'The Captain files it for the whole team — not yours to do',
      ),
    ];
  }

  /// The unit this responder is on and who crews it, from the dispatches.
  Widget? _crew() {
    final mine =
        _myDispatch ??
        _dispatches.where((d) => d['responder_id'] == widget.myId).firstOrNull;
    final vehicle = (mine?['vehicle_name'] as String?)?.trim();
    if (vehicle == null || vehicle.isEmpty) return null;
    final crew = _dispatches
        .where((d) => (d['vehicle_name'] as String?)?.trim() == vehicle)
        .toList();
    String? driver;
    for (final c in crew) {
      final role = (c['crew_role'] as String?)?.toLowerCase() ?? '';
      if (role.contains('driver')) {
        driver = c['responder_name'] as String?;
        break;
      }
    }
    final kind = _fleetByName[vehicle]?.subtitle ?? 'Fire truck';
    return ListRow(
      leading: const IconPlate(AppIcons.fireTruck),
      title: vehicle,
      subtitle: [
        kind,
        if (driver != null) 'Driver $driver',
        crew.length == 1 ? '1 on it' : '${crew.length} on it',
      ].join(' · '),
    );
  }

  List<Widget> _codes(AreaView area) {
    final pal = context.pal;
    Widget code(
      IconData icon,
      Color tint,
      String title,
      String subtitle,
      VoidCallback onTap,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListRow(
        leading: IconPlate(icon, tint: tint),
        title: title,
        subtitle: subtitle,
        chevron: true,
        onTap: _pressing ? null : onTap,
      ),
    );
    return [
      if (_fireCrew)
        code(
          AppIcons.waterDrop,
          pal.water,
          'Need water',
          'More water supply to this Area',
          () => _pressCode('FC-6', 'Need water'),
        ),
      code(
        AppIcons.groupAdd,
        pal.warn,
        'Need assistance',
        'Backup responders to this Area',
        () => _pressCode('FC-7', 'Need assistance'),
      ),
      if (mayRequestAlarm(widget.agency))
        code(
          AppIcons.campaign,
          pal.live,
          'Escalate to BFP',
          'Ask BFP to raise the alarm',
          () => _escalateBfp(area),
        ),
      // Fire out is the Captain's to mark; a crew on scene tells command.
      if (_fireCrew && _status == 'arrived')
        code(
          AppIcons.flag,
          pal.ok,
          'Fire is out',
          'Tell command — the Captain marks it',
          () => _pressCode('FC-3', 'Fire out'),
        ),
    ];
  }
}
