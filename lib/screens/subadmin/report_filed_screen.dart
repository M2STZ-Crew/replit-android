import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../coordinator/coordinator_shell.dart';

/// What the AI summary of an Area is doing, as GET /ai-summaries says.
enum NarrativeState { writing, ready, unavailable }

/// After the report is filed (REPLIT (MAIN) 06 · C14): what happened, in
/// the order the server did it — the report saved, the Area closed — and the
/// formal narrative, which the server starts writing the moment the report
/// lands and which this screen waits for.
///
/// Progress is the steps' real state, never an invented percentage. The
/// narrative is read from the coordinator's AI summaries list every few
/// seconds until it is ready, or the server says it cannot write one.
class ReportFiledScreen extends StatefulWidget {
  const ReportFiledScreen({
    super.key,
    required this.areaId,
    this.designation,
    this.api,
    this.savedAt,
  });

  final String areaId;
  final String? designation;
  final ApiClient? api;

  /// When the report was saved; now, when not given.
  final DateTime? savedAt;

  /// How often the narrative is looked for, and for how long.
  static const Duration every = Duration(seconds: 4);
  static const int tries = 45;

  @override
  State<ReportFiledScreen> createState() => _ReportFiledScreenState();
}

class _ReportFiledScreenState extends State<ReportFiledScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final DateTime _savedAt = widget.savedAt ?? DateTime.now();
  Timer? _poll;
  int _tried = 0;

  String _status = 'closed';
  String? _designation;
  NarrativeState _narrative = NarrativeState.writing;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _designation = widget.designation;
    _loadArea();
    _lookForNarrative();
    _poll = Timer.periodic(ReportFiledScreen.every, (_) {
      if (++_tried >= ReportFiledScreen.tries) {
        _poll?.cancel();
        return;
      }
      _lookForNarrative();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadArea() async {
    try {
      final area = await _api.getIncident(widget.areaId);
      if (!mounted) return;
      setState(() {
        _status = (area['status'] as String?) ?? _status;
        _designation ??= area['designation'] as String?;
      });
    } catch (_) {
      // Filing closes the Area; the screen says so until it hears otherwise.
    }
  }

  Future<void> _lookForNarrative() async {
    try {
      final rows = (await _api.getAiSummaries()).cast<Map<String, dynamic>>();
      final row = rows.where((r) => r['area_id'] == widget.areaId).firstOrNull;
      if (row == null || !mounted) return;
      final state = switch (row['state']) {
        'ready' => NarrativeState.ready,
        'unavailable' => NarrativeState.unavailable,
        _ => NarrativeState.writing,
      };
      setState(() {
        _narrative = state;
        _summary = row['summary_text'] as String?;
        if (row['status'] is String) _status = row['status'] as String;
      });
      if (state != NarrativeState.writing) _poll?.cancel();
    } catch (_) {
      // Try again on the next tick; the report itself is filed either way.
    }
  }

  String get _areaName {
    final d = _designation ?? 'Incident';
    return d.toLowerCase().startsWith('area') ? d : 'Area $d';
  }

  void _backToQueue() {
    final nav = Navigator.of(context);
    if (!CoordinatorShell.showQueue(nav)) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = _status == 'closed';
    return Scaffold(
      backgroundColor: context.pal.background,
      bottomNavigationBar: ActionBar(
        children: [
          AppButton('Back to queue', run: true, onPressed: _backToQueue),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(
              eyebrow: '$_areaName · ${LifecycleChip.word(_status)}',
              title: 'Report filed',
              subtitle: 'Saved ${clockText(_savedAt)}',
            ),
            Expanded(
              child: ScrollFade(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    kScrollFadeEndPadding,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: LifecycleChip(_status),
                    ),
                    const SizedBox(height: 16),
                    LifecycleRail(status: _status),
                    const SizedBox(height: 16),
                    const ProgressStep(
                      state: StepState.done,
                      title: 'Report saved',
                      detail: 'Trucks, driver, crew, equipment and notes',
                    ),
                    ProgressStep(
                      state: closed ? StepState.done : StepState.current,
                      title: 'Area closed',
                      detail: closed
                          ? 'It has left the live feed for every role'
                          : 'Closing it now',
                    ),
                    ProgressStep(
                      state: switch (_narrative) {
                        NarrativeState.ready => StepState.done,
                        NarrativeState.writing => StepState.current,
                        NarrativeState.unavailable => StepState.pending,
                      },
                      title: 'Formal narrative',
                      detail: switch (_narrative) {
                        NarrativeState.ready => 'Written and attached',
                        NarrativeState.writing =>
                          'Lit is writing it from your report and the '
                              "residents' reports",
                        NarrativeState.unavailable =>
                          'The server cannot write summaries right now. The '
                              'report is complete without one.',
                      },
                    ),
                    const SizedBox(height: 8),
                    _narrativeCard(),
                    const SizedBox(height: 16),
                    const InlineAlert(
                      body:
                          'You and Admin can read the narrative under AI '
                          'summaries; nobody can edit it once it is attached.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _narrativeCard() {
    if (_narrative == NarrativeState.writing &&
        (_summary == null || _summary!.trim().isEmpty)) {
      return const _WritingCard();
    }
    return SummaryCard(
      text: _summary,
      meta: _narrative == NarrativeState.writing ? 'Writing…' : null,
      empty: 'No summary. The report you filed is the full record.',
    );
  }
}

/// How far along one step of a real server process is (Progress step).
enum StepState { done, current, pending }

/// One step of the server's work: a green check when done, a spinner while
/// under way, an empty ring when it is not happening — with its name and a
/// line on what it means.
class ProgressStep extends StatelessWidget {
  const ProgressStep({
    super.key,
    required this.state,
    required this.title,
    this.detail,
  });

  final StepState state;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final word = switch (state) {
      StepState.done => 'done',
      StepState.current => 'under way',
      StepState.pending => 'not under way',
    };
    return Semantics(
      label: '$title, $word${detail == null ? '' : '. $detail'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 24,
              child: switch (state) {
                StepState.done => DecoratedBox(
                  decoration: BoxDecoration(
                    color: pal.ok,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.check,
                    size: 16,
                    color: AppColors.background,
                  ),
                ),
                StepState.current => Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: pal.accent,
                    // Still under reduced motion; the words carry the state.
                    value: Motion.of(context).reduced ? 0.3 : null,
                  ),
                ),
                StepState.pending => DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: pal.lineStrong, width: 1.5),
                  ),
                ),
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.listTitle),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: context.type.bodySm),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The summary card while the narrative is written (Summary card, Loading):
/// Lit's place and skeleton lines, not a spinner alone.
class _WritingCard extends StatelessWidget {
  const _WritingCard();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget line(double? width) => Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: pal.pressed,
        borderRadius: BorderRadius.circular(5),
      ),
    );
    return Semantics(
      label: 'Summary: writing',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: pal.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Eyebrow('Summary', color: pal.accentInk)),
                Text(
                  'Writing…',
                  style: context.type.detail.copyWith(color: pal.label),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const LitPlaceholder(size: 40),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(double.infinity),
                      const SizedBox(height: 8),
                      line(double.infinity),
                      const SizedBox(height: 8),
                      line(96),
                    ],
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

/// Lit's reserved place (Lit placeholder): the artwork is still to come, so
/// no character is drawn — a dashed coral ring with the name in it.
class LitPlaceholder extends StatelessWidget {
  const LitPlaceholder({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return CustomPaint(
      painter: _DashedRing(pal.accent),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: pal.accent.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          'Lit',
          style: context.type.label.copyWith(color: pal.accentInk),
        ),
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  _DashedRing(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    const dashes = 16;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(0.75), i * sweep, sweep * 0.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.colour != colour;
}
