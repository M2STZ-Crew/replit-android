import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import 'lit_character.dart';
import 'lit_lessons.dart';
import 'lit_narrator.dart';
import 'lit_tutorial_state.dart';
import 'practice_stage.dart';

/// The Citizen tutorial, led by Lit (12 November 2026, replacing the old
/// seven-step tour): a practice report, one action at a time. The screen
/// dims, one control is lit, Lit says what to do, and the lesson waits for
/// it to be done. Explanations wait for Continue; a clip ending never moves
/// on by itself.
///
/// Practice is a drawing of the real thing ([PracticeReport] and the rest):
/// nothing is reported, queued, uploaded or notified, and no GPS, camera or
/// microphone is asked for. Reporting never depends on this.
class LitTutorialScreen extends StatefulWidget {
  const LitTutorialScreen({
    super.key,
    required this.account,
    this.replay = false,
    this.player,
  });

  /// The Citizen account it is for: where its outcome is kept.
  final String account;

  /// Opened from Help to watch again: its end does not undo a completion.
  final bool replay;

  /// Stands in for the speaker in a test.
  final NarrationPlayer? player;

  static Future<void> open(
    BuildContext context, {
    required String account,
    bool replay = false,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      settings: const RouteSettings(name: routeName),
      builder: (_) => LitTutorialScreen(account: account, replay: replay),
    ),
  );

  static const String routeName = '/lit-tutorial';

  @override
  State<LitTutorialScreen> createState() => _LitTutorialScreenState();
}

class _LitTutorialScreenState extends State<LitTutorialScreen>
    with WidgetsBindingObserver {
  late final LitNarrator _narrator = LitNarrator(
    widget.player ?? AudioNarrationPlayer(),
  );
  final PracticeKeys _keys = newPracticeKeys();
  final GlobalKey _stageKey = GlobalKey(debugLabel: 'practice-stage');

  LitLanguage _language = LitLanguage.en;
  int _step = 0;

  /// Practice state, set from the step on the way in, so Back restores it.
  bool _medical = false;

  /// The beat after Submit Practice Report: Lit approves, then the updates.
  bool _received = false;

  /// The app went to the background mid-lesson: the clip stopped, and
  /// waits for Replay rather than starting again by itself.
  bool _interrupted = false;

  /// Finish's farewell: approve, then a wave.
  bool _waving = false;

  bool _leaving = false;
  Rect? _target;
  Timer? _beat;

  LitLesson get _lesson => kLitLessons[_step];

  static final int _chooseAgency = kLitLessons.indexWhere(
    (l) => l.action == LitAction.chooseAgency,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LitTutorial.language().then((language) {
      if (!mounted) return;
      setState(() => _language = language);
      _enter(0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _beat?.cancel();
    _narrator.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || _leaving) return;
    // Away from the app: stop talking now, and wait for Replay on return.
    if (_narrator.talking.value || _narrator.clip != null) {
      _narrator.stop();
      if (mounted) setState(() => _interrupted = true);
    }
  }

  // ── Moving between lessons ────────────────────────────────────────────────

  /// Into lesson [step], with the practice as it stood at that point.
  void _enter(int step) {
    _beat?.cancel();
    setState(() {
      _step = step;
      _medical = step > _chooseAgency;
      _received = false;
      _interrupted = false;
      _waving = false;
      _target = null;
    });
    _narrator.say(_lesson.clipAsset(_language));
    if (_lesson.action == LitAction.finish) {
      _beat = Timer(const Duration(milliseconds: 1600), () {
        if (mounted && !_narrator.talking.value) {
          setState(() => _waving = true);
        }
      });
    }
  }

  /// On to the next lesson, from [from] only: a second tap that arrives
  /// before the first has moved on finds the lesson already changed.
  void _next(int from) {
    if (_leaving || from != _step || _step >= kLitLessons.length - 1) return;
    _enter(_step + 1);
  }

  void _back() {
    if (_leaving || _step == 0) return;
    _enter(_step - 1);
  }

  /// The one action this lesson waits for, done.
  void _done(LitAction action) {
    final step = _step;
    if (_leaving || _lesson.action != action || _received) return;
    switch (action) {
      case LitAction.chooseAgency:
        setState(() => _medical = true);
        _beat = Timer(const Duration(milliseconds: 450), () => _next(step));
      case LitAction.submit:
        // A practice report "received": Lit approves for a moment.
        _narrator.stop();
        setState(() => _received = true);
        _beat = Timer(const Duration(milliseconds: 1400), () => _next(step));
      case LitAction.finish:
        _finish();
      default:
        _next(step);
    }
  }

  Future<void> _setLanguage(LitLanguage language) async {
    if (language == _language) return;
    setState(() => _language = language);
    unawaited(LitTutorial.setLanguage(language));
    // Same lesson, same practice; the words and voice change together.
    await _narrator.say(_lesson.clipAsset(language));
  }

  Future<void> _skip() async {
    if (_leaving) return;
    _leaving = true;
    _beat?.cancel();
    await _narrator.stop();
    await LitTutorial.skip(widget.account);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    _beat?.cancel();
    await _narrator.stop();
    await LitTutorial.complete(widget.account);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _replay() async {
    setState(() => _interrupted = false);
    await _narrator.replay();
  }

  // ── What the lesson shows ─────────────────────────────────────────────────

  /// The control the lesson is about, if it has one on the stage.
  GlobalKey? get _targetKey => switch (_lesson.name) {
    'start_report' => _keys.dial,
    'photo' => _keys.shutter,
    'check_location' => _keys.location,
    'select_organization' => _keys.agency,
    'review_details' => _keys.form,
    'practice_submit' => _keys.submit,
    'follow_updates' => _keys.updates,
    _ => null,
  };

  /// Whether the lit control takes a touch: the actions do; the readings
  /// are for looking at.
  bool get _touchable => const {
    LitAction.holdSos,
    LitAction.shutter,
    LitAction.chooseAgency,
    LitAction.submit,
  }.contains(_lesson.action);

  /// Find the lit control where it really is, after each layout.
  void _measure(Duration _) {
    if (!mounted) return;
    final box = _targetKey?.currentContext?.findRenderObject();
    final stage = _stageKey.currentContext?.findRenderObject();
    Rect? rect;
    if (box is RenderBox &&
        stage is RenderBox &&
        box.attached &&
        box.hasSize &&
        stage.hasSize) {
      rect = box.localToGlobal(Offset.zero, ancestor: stage) & box.size;
      // Scaled away to nothing (a dial shrunk to fit): no hole to cut.
      if (!rect.isFinite || rect.isEmpty) rect = null;
    }
    if (rect != _target) setState(() => _target = rect);
  }

  LitPose get _pose {
    if (_received) return LitPose.approve;
    if (_waving) return LitPose.wave;
    return _lesson.pose;
  }

  String _say(String en, String tl) => _language == LitLanguage.tl ? tl : en;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step == 0) {
          _skip();
        } else {
          _back();
        }
      },
      child: Scaffold(
        backgroundColor: context.pal.background,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: _lesson.action == LitAction.start
                    ? _welcome()
                    : LayoutBuilder(
                        // Lit's words take at most 60% of the height, so
                        // the lit control always keeps room above them.
                        builder: (context, box) => Column(
                          children: [
                            Expanded(child: _stageArea()),
                            _coach(maxHeight: box.maxHeight * 0.6),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Practice mode, then the voice and Skip.
  Widget _topBar() {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          // Always on show; smaller rather than pushing the controls off a
          // narrow screen at a large text size.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pal.warn.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: pal.warn),
                  ),
                  child: Text(
                    'PRACTICE MODE',
                    style: context.type.tag.copyWith(color: pal.warn),
                  ),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _narrator.muted,
            builder: (context, muted, _) => _IconControl(
              icon: muted ? AppIcons.volumeOff : AppIcons.volumeUp,
              label: muted
                  ? _say("Turn Lit's voice on", 'Buksan ang boses ni Lit')
                  : _say("Turn Lit's voice off", 'Patayin ang boses ni Lit'),
              onTap: () => _narrator.setMuted(!muted),
            ),
          ),
          _IconControl(
            icon: AppIcons.restartAlt,
            label: _say('Hear Lit again', 'Pakinggan ulit si Lit'),
            onTap: _lesson.clip == null ? null : _replay,
          ),
          TextLink(_say('Skip', 'Laktawan'), onTap: _skip),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// 01 · Welcome: Lit, what this is, the language, Start Tutorial.
  Widget _welcome() => LayoutBuilder(
    // Lit as big as the screen's height allows: 200 on a tall phone.
    builder: (context, box) =>
        _welcomeIn(lit: (box.maxHeight * 0.3).clamp(96.0, 200.0)),
  );

  Widget _welcomeIn({required double lit}) {
    final pal = context.pal;
    return FootedScroll(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      content: [
        Center(child: _lit(size: lit)),
        const SizedBox(height: 12),
        Text(
          _say('MEET LIT', 'KILALANIN SI LIT'),
          textAlign: TextAlign.center,
          style: context.type.heading1,
        ),
        const SizedBox(height: 12),
        _caption(center: true),
        const SizedBox(height: 20),
        _languages(),
        const SizedBox(height: 16),
        Text(
          _say(
            'Nothing you do here is sent.',
            'Walang naipapadala sa ginagawa mo rito.',
          ),
          textAlign: TextAlign.center,
          style: context.type.caption.copyWith(color: pal.label),
        ),
      ],
      footer: AppButton(
        'Start Tutorial',
        height: 56,
        onPressed: () => _done(LitAction.start),
      ),
    );
  }

  /// The practice screen for this lesson, dimmed but for its control.
  Widget _stageArea() {
    final pal = context.pal;
    final stage = switch (_lesson.name) {
      'start_report' => PracticeSos(
        dialKey: _keys.dial,
        onHeld: () => _done(LitAction.holdSos),
      ),
      'photo' => PracticeCamera(
        shutterKey: _keys.shutter,
        onShutter: () => _done(LitAction.shutter),
      ),
      'follow_updates' => PracticeStatus(updatesKey: _keys.updates),
      'finish' => _recap(),
      _ => PracticeReport(
        keys: _keys,
        medical: _medical,
        onMedical: () => _done(LitAction.chooseAgency),
        onSubmit: () => _done(LitAction.submit),
      ),
    };
    final lit = _lesson.action != LitAction.finish;
    return Stack(
      key: _stageKey,
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: stage,
          ),
        ),
        // Without a lit control (none, or not found), nothing is dimmed or
        // held back: the words alone say what to do.
        if (lit && _target != null)
          Positioned.fill(
            child: _Spotlight(
              hole: _target!,
              touchable: _touchable && !_received,
              dim: pal.scrim,
              ring: pal.accent,
            ),
          ),
      ],
    );
  }

  /// 08 · What a report takes, in four lines.
  Widget _recap() {
    final pal = context.pal;
    final lines = [
      _say(
        'Hold SOS for two seconds',
        'Pindutin nang matagal ang SOS nang dalawang segundo',
      ),
      _say('Take one photo of the scene', 'Kumuha ng isang litrato ng lugar'),
      _say(
        'Check the details, then send',
        'Tingnan ang mga detalye, saka i-send',
      ),
      _say(
        'Follow the updates until the fire is out',
        'Sundan ang updates hanggang mapatay ang sunog',
      ),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: pal.line),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.checkCircle, size: 20, color: pal.ok),
                  const SizedBox(width: 12),
                  Expanded(child: Text(line, style: context.type.listTitle)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Lit and his words, under the stage: never over the lit control. At
  /// most [maxHeight]; longer words scroll inside the bubble.
  Widget _coach({required double maxHeight}) {
    final pal = context.pal;
    final lesson = _lesson;
    final left = _pose == LitPose.pointUpperRight;
    final reading = lesson.action == LitAction.read;
    final finishing = lesson.action == LitAction.finish;
    final bubble = Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(color: pal.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(
                    _say(
                      'Step ${int.parse(lesson.id)} of $kLitLessonCount',
                      'Hakbang ${int.parse(lesson.id)} sa $kLitLessonCount',
                    ),
                    color: pal.accentInk,
                  ),
                ),
                _languages(compact: true),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(child: SingleChildScrollView(child: _caption())),
            if (_interrupted) ...[
              const SizedBox(height: 6),
              Text(
                _say(
                  'Paused. Tap replay to hear Lit again.',
                  'Naka-pause. I-tap ang replay para marinig ulit si Lit.',
                ),
                style: context.type.caption.copyWith(color: pal.warn),
              ),
            ],
          ],
        ),
      ),
    );
    // A narrow phone gives Lit a little less room, and his words more.
    final lit = MediaQuery.sizeOf(context).width < 380 ? 92.0 : 112.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (left) ...[_lit(size: lit), const SizedBox(width: 8)],
                  bubble,
                  if (!left) ...[const SizedBox(width: 8), _lit(size: lit)],
                ],
              ),
            ),
            // Back and Continue across the whole width, under Lit and his
            // words: room for them at any text size.
            Row(
              children: [
                if (_step > 0) TextLink(_say('Back', 'Bumalik'), onTap: _back),
                const Spacer(),
                if (reading || finishing)
                  AppButton(
                    finishing ? 'Finish' : 'Continue',
                    height: 48,
                    onPressed: () =>
                        _done(finishing ? LitAction.finish : LitAction.read),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The lesson's words, or the practice report's receipt in its beat.
  Widget _caption({bool center = false}) {
    final text = _received
        ? _say(
            'Practice report received. Nothing was sent.',
            'Natanggap ang practice report. Walang naipadala.',
          )
        : _lesson.caption(_language);
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: const ValueKey('lit-caption'),
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: context.type.body.copyWith(color: context.pal.onBackground),
      ),
    );
  }

  Widget _lit({required double size}) => ValueListenableBuilder<bool>(
    valueListenable: _narrator.talking,
    builder: (context, talking, _) => Semantics(
      label: 'Lit',
      image: true,
      child: LitCharacter(
        pose: _pose,
        talking: talking && !_received,
        size: size,
      ),
    ),
  );

  /// English | Tagalog, for the voice and the words together.
  Widget _languages({bool compact = false}) {
    final pal = context.pal;
    // A wrap: on a narrow phone at a large text size the two take two lines
    // rather than running off the screen.
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final language in LitLanguage.values)
          Semantics(
            button: true,
            selected: language == _language,
            label: language.label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              onTap: () => _setLanguage(language),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
                  // Centred in its 48 px target, but no wider than its word.
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 14,
                        vertical: compact ? 4 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: language == _language
                            ? pal.accent.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(
                          color: language == _language ? pal.accent : pal.line,
                        ),
                      ),
                      child: Text(
                        compact ? language.name.toUpperCase() : language.label,
                        style: context.type.tag.copyWith(
                          color: language == _language
                              ? pal.accentInk
                              : pal.textSoft,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A 48 × 48 icon control with a name for screen readers.
class _IconControl extends StatelessWidget {
  const _IconControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Icon(
            icon,
            size: 22,
            color: onTap == null ? pal.line : pal.onBackground,
          ),
        ),
      ),
    );
  }
}

/// The dimmed stage with a hole where the lit control is, ringed in coral.
/// Outside the hole every touch stops here; inside it, a touch reaches the
/// control when it is one to press ([touchable]).
class _Spotlight extends LeafRenderObjectWidget {
  const _Spotlight({
    required this.hole,
    required this.touchable,
    required this.dim,
    required this.ring,
  });

  final Rect hole;
  final bool touchable;
  final Color dim;
  final Color ring;

  @override
  _RenderSpotlight createRenderObject(BuildContext context) =>
      _RenderSpotlight(hole: hole, touchable: touchable, dim: dim, ring: ring);

  @override
  void updateRenderObject(BuildContext context, _RenderSpotlight render) {
    render
      ..hole = hole
      ..touchable = touchable
      ..dim = dim
      ..ring = ring;
  }
}

class _RenderSpotlight extends RenderBox {
  _RenderSpotlight({
    required Rect hole,
    required bool touchable,
    required Color dim,
    required Color ring,
  }) : _hole = hole,
       _touchable = touchable,
       _dim = dim,
       _ring = ring;

  Rect _hole;
  set hole(Rect value) {
    if (value == _hole) return;
    _hole = value;
    markNeedsPaint();
  }

  bool _touchable;
  set touchable(bool value) => _touchable = value;

  Color _dim;
  set dim(Color value) {
    if (value == _dim) return;
    _dim = value;
    markNeedsPaint();
  }

  Color _ring;
  set ring(Color value) {
    if (value == _ring) return;
    _ring = value;
    markNeedsPaint();
  }

  RRect get _cut =>
      RRect.fromRectAndRadius(_hole.inflate(6), const Radius.circular(16));

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => !(_touchable && _cut.contains(position));

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(_cut),
      Paint()..color = _dim,
    );
    canvas.drawRRect(
      _cut,
      Paint()
        ..color = _ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }
}
