import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/report_queue.dart';
import '../models/active_report.dart';
import '../models/resident_status.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'live_update_screen.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';

/// "09 Submitting" from the REPLIT-OVERHAUL Figma — "Getting you help" — and
/// the screen a resident stays on until the fire is out.
///
/// The frame is drawn mid-upload and stops at a coordinator's confirmation.
/// Here it carries on: once someone has reported an emergency, their report is
/// what the app is for, so this screen follows it the whole way —
///
///   1. received — the photo and fix are stored (the 201 itself);
///   2. matched — clustered into an area, joined or first;
///   3. notified — responders have it, and neighbours within 100 m were asked;
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
    this.status,
    this.api,
  });

  /// The screen for a report in progress.
  ReportStatusScreen.of(
    ActiveReport report, {
    Key? key,
    String? status,
    ApiClient? api,
  }) : this(
         key: key,
         designation: report.designation,
         lat: report.lat,
         lng: report.lng,
         submittedAt: report.submittedAt,
         message: report.message,
         areaId: report.areaId,
         reportId: report.reportId,
         selectedAgencies: report.agencies,
         status: status,
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

  /// The area's status when it opens, when the caller already knows it —
  /// Track It Live handing over at fire out — so the finished screen shows at
  /// once instead of after its first read.
  final String? status;
  final ApiClient? api;

  static int _showing = 0;

  /// A status heard elsewhere (Track It Live) for the screen on the stack.
  static final ValueNotifier<String?> _heard = ValueNotifier(null);

  /// True while this screen is on the stack, so nothing opens a second one.
  static bool get isShowing => _showing > 0;

  static const String routeName = '/report-in-progress';

  /// The route for a report in progress, named so it can be found again.
  static MaterialPageRoute<void> route(
    ActiveReport report, {
    String? status,
    ApiClient? api,
  }) => MaterialPageRoute(
    settings: const RouteSettings(name: routeName),
    builder: (_) => ReportStatusScreen.of(report, status: status, api: api),
  );

  /// The report is over — the fire is out, or it was not confirmed — while
  /// the resident is on another screen (Track It Live). Take them to this one
  /// next, which says so and has Done, instead of leaving them to back out to
  /// find it: back down to it if it is on the stack, or in place of the
  /// screen they are on.
  static void showFinished(
    BuildContext context,
    ActiveReport report,
    String status, {
    ApiClient? api,
  }) {
    final nav = Navigator.of(context);
    if (isShowing) {
      _heard
        ..value = null
        ..value = status;
      nav.popUntil(ModalRoute.withName(routeName));
      return;
    }
    nav.pushReplacement(route(report, status: status, api: api));
  }

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
        SnackBar(
          content: Text(
            t(
              'You already have a report in progress. It stays open until the '
              'fire is out.',
            ),
          ),
        ),
      );
      return true;
    }
    if (ReportQueue.instance.pending.value.isNotEmpty) {
      AppNavBar.switchTo(context, AppTab.map);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Your report is saved on this phone. It sends itself when the '
              'signal is back.',
            ),
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
    ReportStatusScreen._heard.addListener(_onHeard);
    final known = widget.status;
    if (known != null) _area = {'status': known};
    if (_areaId != null && !_over) {
      _load();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  @override
  void dispose() {
    ReportStatusScreen._showing--;
    WidgetsBinding.instance.removeObserver(this);
    ReportStatusScreen._heard.removeListener(_onHeard);
    _poll?.cancel();
    super.dispose();
  }

  /// Track It Live saw the report finish: show it now, not on the next read.
  void _onHeard() {
    final status = ReportStatusScreen._heard.value;
    if (status == null || !mounted) return;
    setState(() => _area = {...?_area, 'status': status});
    if (_over) _poll?.cancel();
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
        ? t('Grouped with reports within 50 m')
        : reports > 1
        ? t('Within 50 m of an active area')
        : t('A new area — the first report here');

    final (String phase, double fraction) = switch (_stage) {
      'fire_out' => (t('Fire out'), 1.0),
      'rejected' => ('Closed', 1.0),
      'arrived' => (t('On scene'), 0.9),
      'en_route' => (t('On the way'), 0.8),
      'verified' => ('Acknowledged', 0.7),
      _ => ('Confirming', 0.6),
    };

    final (String eyebrow, Color eyebrowTone) = _fireOut
        ? (t('Report done'), context.pal.ok)
        : _refused
        ? (t('Report closed'), context.pal.muted)
        : (t('Report sent'), context.pal.accentInk);

    final heading = _fireOut
        ? t('FIRE OUT')
        : _refused
        ? t('NOT CONFIRMED')
        : t('GETTING YOU HELP');

    final lead = _fireOut
        ? t(
            'Responders have put the fire out. Thank you for reporting — your '
            'report is done.',
          )
        : _refused
        ? t(
            'A coordinator could not confirm this one. If it is still '
            'happening, send another report or call a hotline.',
          )
        : t(
            'You do not need to do anything else. This screen follows your '
            'report until the fire is out — SOS brings you back here.',
          );

    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // 12 Nov 2026: the page fits the screen, with no scrolling. Its
            // spacing eases from a short phone to a tall one, the ring takes
            // the room that is left (and steps aside when there is too
            // little: the steps say the same), and the line about
            // encryption is gone.
            final roomy = FitPage.roominess(context, box.maxHeight);
            double ease(double short, double tall) =>
                short + (tall - short) * roomy;
            final stepGap = SizedBox(height: ease(6, 8));
            return FitPage(
              padding: EdgeInsets.fromLTRB(24, ease(16, 40), 24, ease(16, 28)),
              gap: ease(16, 32),
              flexMin: _ringLeast,
              flexMax: _ringMost,
              top: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Eyebrow(eyebrow, color: eyebrowTone),
                  SizedBox(height: ease(8, 10)),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: context.type.heading1,
                  ),
                  SizedBox(height: ease(8, 10)),
                  Center(
                    child: SizedBox(
                      width: 300,
                      child: Text(
                        lead,
                        textAlign: TextAlign.center,
                        style: context.type.body,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              flex: _ringSlot(fraction, phase),
              bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepRow(
                    state: _Step.done,
                    title: t('Report received'),
                    line: t('Photo and GPS stored'),
                    roomy: roomy,
                  ),
                  stepGap,
                  _StepRow(
                    state: _Step.done,
                    title: reports == 1
                        ? '$designation opened'
                        : 'Matched to $designation',
                    line: matchLine,
                    roomy: roomy,
                  ),
                  stepGap,
                  _StepRow(
                    state: _Step.done,
                    title: t('Responders notified'),
                    line: t('Neighbours within 100 m were alerted too'),
                    roomy: roomy,
                  ),
                  stepGap,
                  _StepRow(
                    state: _refused || _accepted ? _Step.done : _Step.now,
                    title: _refused
                        ? t('Not confirmed')
                        : _accepted
                        ? t('Accepted')
                        : t('Waiting to be accepted'),
                    line: _refused
                        ? t('Closed by a coordinator')
                        : _onScene
                        ? t('Responders reached the scene')
                        : _accepted
                        ? t('Responders are on the way')
                        : _areaId == null
                        ? t('Open it from Your reports to follow it')
                        : t('Now'),
                    refused: _refused,
                    roomy: roomy,
                  ),
                  if (!_refused) ...[
                    stepGap,
                    _StepRow(
                      state: _fireOut
                          ? _Step.done
                          : _onScene
                          ? _Step.now
                          : _Step.later,
                      title: t('Fire out'),
                      line: _fireOut
                          ? t('Your report is done')
                          : _onScene
                          ? t('Responders are working on it')
                          : t('Once responders are on scene'),
                      roomy: roomy,
                    ),
                  ],
                ],
              ),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_over)
                    AppButton(t('Done'), height: 54, onPressed: _done)
                  else ...[
                    if (_areaId != null)
                      AppButton(
                        t('Track it live'),
                        height: 54,
                        onPressed: _follow,
                      ),
                    TextButton(
                      onPressed: _callHotline,
                      style: TextButton.styleFrom(
                        foregroundColor: context.pal.label,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        t('Something else? Call a hotline'),
                        style: context.type.label.copyWith(
                          color: context.pal.label,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The ring's room on the page, below the 16 under the lead: at most a
  /// 160 ring with 12 more above it and 28 below (the frame's spacing), and
  /// at least an 80 ring with 14 below. With less, it steps aside.
  static const double _ringMost = 12 + 160 + 28;
  static const double _ringLeast = 80 + 14;

  /// The ring in the room the page leaves it: the more room, the bigger the
  /// ring and the more air around it.
  Widget _ringSlot(double fraction, String phase) => LayoutBuilder(
    builder: (context, box) {
      final room = box.maxHeight;
      if (room < _ringLeast) return const SizedBox.shrink();
      final grown = ((room - _ringLeast) / (_ringMost - _ringLeast)).clamp(
        0.0,
        1.0,
      );
      final above = 12 * grown;
      final below = 14 + 14 * grown;
      return Padding(
        padding: EdgeInsets.only(top: above, bottom: below),
        child: Center(
          child: _ring(fraction, phase, math.min(160, room - above - below)),
        ),
      );
    },
  );

  /// The ring, [size] across (160 in the frame): how far the report has
  /// come, and the stage it is at, named under the figure when the ring is
  /// big enough to hold it (the steps name it too).
  Widget _ring(double fraction, String phase, double size) {
    final tone = _fireOut
        ? context.pal.ok
        : _refused
        ? context.pal.muted
        : context.pal.accentInk;
    return Semantics(
      label: '${(fraction * 100).round()} percent. $phase.',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size * 0.9,
              height: size * 0.9,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: context.pal.lineStrong,
                color: tone,
              ),
            ),
            SizedBox(
              width: size * 0.62,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_fireOut)
                      Icon(AppIcons.check, size: 40, color: tone)
                    else
                      Text(
                        '${(fraction * 100).round()}%',
                        style: context.type.numeralXl,
                      ),
                    if (size >= 120) ...[
                      const SizedBox(height: 4),
                      Text(
                        phase.toUpperCase(),
                        style: context.type.tag.copyWith(
                          color: _fireOut ? tone : context.pal.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    this.roomy = 1,
  });

  final _Step state;
  final String title;
  final String line;
  final bool refused;

  /// How roomy the page is ([FitPage.roominess]): a row is 58 tall on a
  /// tall phone, as in the frame, and 48 on a short one.
  final double roomy;

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
          refused ? AppIcons.close : AppIcons.check,
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
      constraints: BoxConstraints(minHeight: 48 + 10 * roomy),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 7 + 3 * roomy),
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
