import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/report_queue.dart';
import '../models/active_report.dart';
import '../models/resident_status.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'live_update_screen.dart';

/// "09 Submitting" from the REPLIT-OVERHAUL Figma — "Getting you help" — and
/// the screen a resident stays on until the fire is out.
///
/// The frame is drawn mid-upload and stops at a coordinator's confirmation.
/// Here it carries on: once someone has reported an emergency, their report is
/// what the app is for, so this screen follows it the whole way —
///
///   1. received — the photo and fix are stored (the 201 itself);
///   2. matched — clustered into an area, joined or first;
///   3. notified — Barangay 76 has it, and neighbours within 300 m were asked;
///   4. accepted — a coordinator or agency accepted it and responders are on
///      the way, then on scene (v11: one Accept sends everyone);
///   5. fire out — and then it says so, plainly, and the report is done.
///
/// Leaving is allowed — the map is one Back away — but the report is not
/// lost: pressing SOS again, or reopening the app, comes back here
/// ([ActiveReportStore]). It lets go when the resident presses Done, and until
/// then it is the only report they can have: the dial does not start a second
/// one, and the server refuses it.
class ReportStatusScreen extends StatefulWidget {
  const ReportStatusScreen({
    super.key,
    required this.designation,
    required this.lat,
    required this.lng,
    required this.submittedAt,
    this.message,
    this.areaId,
    this.reportId,
    this.selectedAgencies = const [],
    this.api,
  });

  /// The screen for a report in progress.
  ReportStatusScreen.of(ActiveReport report, {Key? key, ApiClient? api})
    : this(
        key: key,
        designation: report.designation,
        lat: report.lat,
        lng: report.lng,
        submittedAt: report.submittedAt,
        message: report.message,
        areaId: report.areaId,
        reportId: report.reportId,
        selectedAgencies: report.agencies,
        api: api,
      );

  final String designation;
  final double lat;
  final double lng;
  final DateTime submittedAt;
  final String? message;
  final String? areaId;
  final String? reportId;
  final List<String> selectedAgencies;
  final ApiClient? api;

  static int _showing = 0;

  /// True while this screen is on the stack, so nothing opens a second one.
  static bool get isShowing => _showing > 0;

  static const String routeName = '/report-in-progress';

  /// The route for a report in progress, named so it can be found again.
  static MaterialPageRoute<void> route(ActiveReport report) =>
      MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => ReportStatusScreen.of(report),
      );

  /// Bring the resident back to their report: to the front if it is already
  /// open underneath something else, otherwise opened fresh.
  static Future<void> open(BuildContext context, ActiveReport report) async {
    final nav = Navigator.of(context);
    if (isShowing) {
      nav.popUntil(ModalRoute.withName(routeName));
      return;
    }
    await nav.push(route(report));
  }

  /// One report at a time: a resident who already has one out is taken to
  /// it instead of starting another — or, while it still waits on the phone
  /// for a signal, to the map, which shows it. True when they were sent on.
  static bool redirectIfReporting(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final report = ActiveReportStore.mine;
    if (report != null) {
      showOverMap(context, report);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'You already have a report in progress. It stays open until the '
            'fire is out.',
          ),
        ),
      );
      return true;
    }
    if (ReportQueue.instance.pending.value.isNotEmpty) {
      AppNavBar.switchTo(context, AppTab.map);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your report is saved on this phone. It sends itself when the '
            'signal is back.',
          ),
        ),
      );
      return true;
    }
    return false;
  }

  /// The report with only the map under it, so Back is the map — never the
  /// SOS dial or the form it was sent from.
  static void showOverMap(BuildContext context, ActiveReport report) {
    final nav = Navigator.of(context);
    AppNavBar.switchTo(context, AppTab.map);
    nav.push(route(report));
  }

  @override
  State<ReportStatusScreen> createState() => _ReportStatusScreenState();
}

enum _Step { done, now, later }

class _ReportStatusScreenState extends State<ReportStatusScreen>
    with WidgetsBindingObserver {
  late final ApiClient _api = widget.api ?? ApiClient();
  late String? _areaId = widget.areaId;
  Timer? _poll;

  /// The area as last read; null until it answers (or with no area id).
  Map<String, dynamic>? _area;

  @override
  void initState() {
    super.initState();
    ReportStatusScreen._showing++;
    WidgetsBinding.instance.addObserver(this);
    if (_areaId != null) {
      _load();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  @override
  void dispose() {
    ReportStatusScreen._showing--;
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  // Back from the background: read it now rather than on the next tick, so
  // the first thing a returning resident sees is where their report is.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_over) _load();
  }

  Future<void> _load() async {
    final id = _areaId;
    if (id == null) return;
    try {
      final area = await _api.getArea(id);
      if (!mounted) return;
      setState(() => _area = area);
      if ('${area['status']}' == 'merged') {
        await _followMerge();
        return;
      }
      if (_over) _poll?.cancel();
    } catch (_) {
      // Keep the last reading; the next tick tries again.
    }
  }

  /// The area was folded into a neighbouring one. The report went with it, and
  /// the server says where: `/reports/mine` names each report's live area.
  Future<void> _followMerge() async {
    final reportId = widget.reportId;
    if (reportId == null) return;
    try {
      final mine = await _api.getMyReports();
      for (final raw in mine) {
        final r = raw as Map<String, dynamic>;
        if (r['id'] != reportId) continue;
        final next = r['area_id'] as String?;
        if (next == null || next == _areaId) return;
        _areaId = next;
        final active = ActiveReportStore.mine;
        if (active != null && active.reportId == reportId) {
          await ActiveReportStore.start(
            active.movedTo(
              areaId: next,
              designation: r['area_designation'] as String?,
            ),
          );
        }
        await _load();
        return;
      }
    } catch (_) {
      // Stay on the last area; the next tick tries again.
    }
  }

  /// Where the report is, as a resident would say it.
  String get _stage => residentStatus(_area?['status'] as String?);

  bool get _fireOut => _stage == 'fire_out';

  bool get _refused => _stage == 'rejected';

  /// Nothing more is coming: out, or not confirmed.
  bool get _over => _fireOut || _refused;

  bool get _accepted =>
      const {'verified', 'en_route', 'arrived', 'fire_out'}.contains(_stage);

  bool get _onScene => const {'arrived', 'fire_out'}.contains(_stage);

  int? get _reports => (_area?['report_count'] as num?)?.toInt();

  void _follow() {
    final id = _areaId;
    if (id == null) return;
    // Everything asked for so far — at the SOS and on earlier visits to Live
    // tracking — so none of it is offered again.
    final active = ActiveReportStore.mine;
    final asked = active != null && active.reportId == widget.reportId
        ? active.agencies
        : widget.selectedAgencies;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveUpdateScreen(
          areaId: id,
          lat: widget.lat,
          lng: widget.lng,
          alreadySelected: asked,
        ),
      ),
    );
  }

  /// The report is finished with: stop following it and go to the map.
  Future<void> _done() async {
    final active = ActiveReportStore.mine;
    if (active == null ||
        active.reportId == widget.reportId ||
        active.areaId == _areaId) {
      await ActiveReportStore.finish();
    }
    if (!mounted) return;
    AppNavBar.switchTo(context, AppTab.map);
  }

  /// A different emergency while this one is live: not a second report,
  /// which the server refuses, but a call.
  void _callHotline() => AppNavBar.switchTo(context, AppTab.hotlines);

  @override
  Widget build(BuildContext context) {
    final designation =
        (_area?['designation'] as String?) ?? widget.designation;
    final reports = _reports;
    final matchLine = reports == null
        ? 'Grouped with reports within 300 m'
        : reports > 1
        ? 'Within 300 m of an active area'
        : 'A new area — the first report here';

    final (String phase, double fraction) = switch (_stage) {
      'fire_out' => ('Fire out', 1.0),
      'rejected' => ('Closed', 1.0),
      'arrived' => ('On scene', 0.9),
      'en_route' || 'verified' => ('On the way', 0.8),
      _ => ('Confirming', 0.6),
    };

    final (String eyebrow, Color eyebrowTone) = _fireOut
        ? ('Report done', context.pal.ok)
        : _refused
        ? ('Report closed', context.pal.muted)
        : ('Report sent', context.pal.accentInk);

    final heading = _fireOut
        ? 'FIRE OUT'
        : _refused
        ? 'NOT CONFIRMED'
        : 'GETTING YOU HELP';

    final lead = _fireOut
        ? 'Responders have put the fire out. Thank you for reporting — your '
              'report is done.'
        : _refused
        ? 'A coordinator could not confirm this one. If it is still '
              'happening, send another report or call a hotline.'
        : 'You do not need to do anything else. This screen follows your '
              'report until the fire is out — SOS brings you back here.';

    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          content: [
            Eyebrow(eyebrow, color: eyebrowTone),
            const SizedBox(height: 10),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: context.type.heading1,
            ),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 290,
                child: Text(
                  lead,
                  textAlign: TextAlign.center,
                  style: context.type.body,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Center(child: _ring(fraction, phase)),
            const SizedBox(height: 36),
            const _StepRow(
              state: _Step.done,
              title: 'Report received',
              line: 'Photo and GPS stored',
            ),
            const SizedBox(height: 8),
            _StepRow(
              state: _Step.done,
              title: reports == 1
                  ? '$designation opened'
                  : 'Matched to $designation',
              line: matchLine,
            ),
            const SizedBox(height: 8),
            const _StepRow(
              state: _Step.done,
              title: 'Barangay 76 notified',
              line: 'Neighbours within 300 m were alerted too',
            ),
            const SizedBox(height: 8),
            _StepRow(
              state: _refused || _accepted ? _Step.done : _Step.now,
              title: _refused
                  ? 'Not confirmed'
                  : _accepted
                  ? 'Accepted'
                  : 'Waiting to be accepted',
              line: _refused
                  ? 'Closed by a coordinator'
                  : _onScene
                  ? 'Responders reached the scene'
                  : _accepted
                  ? 'Responders are on the way'
                  : _areaId == null
                  ? 'Open it from Your reports to follow it'
                  : 'Now',
              refused: _refused,
            ),
            if (!_refused) ...[
              const SizedBox(height: 8),
              _StepRow(
                state: _fireOut
                    ? _Step.done
                    : _onScene
                    ? _Step.now
                    : _Step.later,
                title: 'Fire out',
                line: _fireOut
                    ? 'Your report is done'
                    : _onScene
                    ? 'Responders are working on it'
                    : 'Once responders are on scene',
              ),
            ],
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_over)
                AppButton('Done', height: 54, onPressed: _done)
              else ...[
                if (_areaId != null)
                  AppButton('Track it live', height: 54, onPressed: _follow),
                TextButton(
                  onPressed: _callHotline,
                  style: TextButton.styleFrom(
                    foregroundColor: context.pal.label,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Something else? Call a hotline',
                    style: context.type.label.copyWith(
                      color: context.pal.label,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: context.pal.muted,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ENCRYPTED, SHARED ONLY WITH RESPONDERS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: context.pal.muted,
                      ),
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

  /// The 144px ring: how far the report has come, and the stage it is at.
  Widget _ring(double fraction, String phase) {
    final tone = _fireOut
        ? context.pal.ok
        : _refused
        ? context.pal.muted
        : context.pal.accentInk;
    return Semantics(
      label: '${(fraction * 100).round()} percent. $phase.',
      excludeSemantics: true,
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 144,
              height: 144,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: context.pal.lineStrong,
                color: tone,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_fireOut)
                  Icon(Icons.check_rounded, size: 40, color: tone)
                else
                  Text(
                    '${(fraction * 100).round()}%',
                    style: context.type.numeralXl,
                  ),
                const SizedBox(height: 4),
                Text(
                  phase.toUpperCase(),
                  style: context.type.tag.copyWith(
                    color: _fireOut ? tone : context.pal.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One step: a marker (a tick, coral while it is the open one, hollow until
/// it is reached), the step, and what it amounts to.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.state,
    required this.title,
    required this.line,
    this.refused = false,
  });

  final _Step state;
  final String title;
  final String line;
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final now = state == _Step.now;
    final later = state == _Step.later;
    final Widget marker = switch (state) {
      _Step.done => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: (refused ? context.pal.muted : context.pal.ok).withValues(
            alpha: 0.14,
          ),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Icon(
          refused ? Icons.close_rounded : Icons.check_rounded,
          size: 12,
          color: refused ? context.pal.muted : context.pal.ok,
        ),
      ),
      _Step.now => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: context.pal.accentInk,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      _Step.later => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: context.pal.lineStrong, width: 1.5),
        ),
      ),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: context.pal.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: now
              ? context.pal.accentInk.withValues(alpha: 0.45)
              : context.pal.line,
        ),
      ),
      child: Row(
        children: [
          marker,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.type.rowValue.copyWith(
                    color: later ? context.pal.muted : context.pal.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: context.type.caption.copyWith(
                    color: now ? context.pal.accentInk : context.pal.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
