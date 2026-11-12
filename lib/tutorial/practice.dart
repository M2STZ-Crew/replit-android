import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'lit_character.dart';
import 'lit_lessons.dart';
import 'lit_narrator.dart';
import 'lit_tutorial_state.dart';
import 'lit_welcome_screen.dart';

/// What the real screens tell a practice report.
enum PracticeEvent {
  /// The SOS screen opened (SOS was tapped on the map).
  sosOpened,

  /// The camera opened (SOS was held).
  cameraOpened,

  /// "What are we sending?" opened (the photo was taken).
  reportOpened,

  /// An agency was ticked or unticked: the detail is (agency, on).
  agencyChanged,

  /// "Getting you help" opened for the practice report (it was "sent").
  statusOpened,
}

/// The practice report: the LIT tutorial on the real reporting screens
/// (12 November 2026: "the system or the real reporting phase is in the
/// tutorial (but it will not report officially)").
///
/// While one runs ([active]) the real screens work as they always do — SOS
/// tapped on the map and held, the real camera, the real GPS — with these
/// differences, each made where the screen asks [active]:
/// - Send reads "Submit Practice Report" and sends nothing: "Getting you
///   help" opens on the practice report and plays its stages by itself.
/// - Nothing of it is kept: no report, no queue, no history, no timing; the
///   photo is deleted from the phone as soon as it is read, and its bytes go
///   with the screens.
/// - Back is the tutorial's ([PracticeBack]).
/// - Each screen says what happened ([tell]) and wraps the control a lesson
///   is about in a [PracticeTarget], so Lit's spotlight finds it where it
///   really is.
abstract final class Practice {
  static LitPractice? _session;

  /// A practice report is under way (after Start Tutorial).
  static bool get active => _session?.started ?? false;

  /// The practice on now, if any (from the welcome on).
  static LitPractice? get session => _session;

  /// A real screen says [event] happened. Often told from a screen's
  /// initState, in the middle of a build: acted on just after it.
  static void tell(PracticeEvent event, [Object? detail]) {
    final session = _session;
    if (session == null || !session.started) return;
    scheduleMicrotask(() => session._on(event, detail));
  }

  /// Bumped when the report form should go back to how it opened: Fire
  /// alone, so the lesson's agency is there to choose again.
  static final ValueNotifier<int> resets = ValueNotifier(0);

  /// The real send button's words during a practice (and Lit's, in 06).
  static const String sendLabel = 'Submit Practice Report';

  /// The practice report's photo for a phone whose camera will not start: a
  /// drawing (tool/tutorial/render_practice_photo_test.dart).
  static const String samplePhoto = 'assets/tutorial/practice_photo.png';

  static Future<Uint8List> loadSamplePhoto() async =>
      (await rootBundle.load(samplePhoto)).buffer.asUint8List();
}

/// A real control a practice lesson can light, found by [id] while it is on
/// the screen in front ([LitTargets]). Several with one id are lit together.
class PracticeTarget extends StatefulWidget {
  const PracticeTarget({
    super.key,
    required this.id,
    required this.child,
    this.round = false,
  });

  final String id;
  final Widget child;

  /// A round control: lit in a circle.
  final bool round;

  @override
  State<PracticeTarget> createState() => _PracticeTargetState();
}

class _PracticeTargetState extends State<PracticeTarget> {
  @override
  void initState() {
    super.initState();
    PracticeTargets._add(widget.id, this);
  }

  @override
  void didUpdateWidget(PracticeTarget old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      PracticeTargets._remove(old.id, this);
      PracticeTargets._add(widget.id, this);
    }
  }

  @override
  void dispose() {
    PracticeTargets._remove(widget.id, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Where a lesson's control is on the screen, and whether it is round.
typedef PracticeSpot = ({Rect rect, bool round});

/// Where the [PracticeTarget]s are.
abstract final class PracticeTargets {
  static final Map<String, List<_PracticeTargetState>> _all = {};

  static void _add(String id, _PracticeTargetState target) =>
      (_all[id] ??= []).add(target);

  static void _remove(String id, _PracticeTargetState target) =>
      _all[id]?.remove(target);

  /// Where [id] is on the screen now, on the route in front only (the map's
  /// bar under a pushed screen does not count): the one control, or all of
  /// them together. Null when none is showing.
  static PracticeSpot? spotOf(String id) {
    Rect? all;
    var round = false;
    var found = 0;
    for (final target in _all[id] ?? const <_PracticeTargetState>[]) {
      if (!target.mounted) continue;
      if (ModalRoute.isCurrentOf(target.context) == false) continue;
      final box = target.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      // Through every transform above it: a dial scaled down to fit, a
      // screen sliding in.
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      if (!rect.isFinite || rect.isEmpty) continue;
      all = all == null ? rect : all.expandToInclude(rect);
      round = target.widget.round;
      found++;
    }
    return all == null ? null : (rect: all, round: round && found == 1);
  }

  /// Bring [id] into view where its screen scrolls it out of it (a short
  /// phone, a large text size): the spotlight lets no finger scroll to a
  /// control below the edge.
  static void reveal(String id) {
    for (final target in _all[id] ?? const <_PracticeTargetState>[]) {
      if (!target.mounted) continue;
      if (ModalRoute.isCurrentOf(target.context) == false) continue;
      final scrollable = Scrollable.maybeOf(target.context);
      final box = target.context.findRenderObject();
      final view = scrollable?.context.findRenderObject();
      if (scrollable == null ||
          box is! RenderBox ||
          view is! RenderBox ||
          !box.hasSize ||
          !view.hasSize) {
        continue;
      }
      Rect onScreen(RenderBox of) => MatrixUtils.transformRect(
        of.getTransformTo(null),
        Offset.zero & of.size,
      );
      final rect = onScreen(box);
      final room = onScreen(view);
      final policy = rect.bottom > room.bottom + 0.5
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : rect.top < room.top - 0.5
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : null;
      if (policy != null) {
        Scrollable.ensureVisible(
          target.context,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignmentPolicy: policy,
        );
      }
      return;
    }
  }
}

/// While a practice runs, the system Back on a real screen is the tutorial's
/// Back: the screens stay where the lesson is. One per route (the resident's
/// bar carries one for the map and the SOS screen).
class PracticeBack extends StatelessWidget {
  const PracticeBack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final practice = Practice.session;
    if (practice == null || !practice.started) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) practice.back();
      },
      child: child,
    );
  }
}

/// One practice report, from the welcome to Finish or Skip: its lesson, Lit's
/// voice, and the coach over the real screens.
class LitPractice with WidgetsBindingObserver {
  LitPractice._({
    required this.account,
    required this.replay,
    NarrationPlayer? player,
  }) : narrator = LitNarrator(player ?? AudioNarrationPlayer());

  /// A practice that is not running, for a screen test of the welcome.
  @visibleForTesting
  factory LitPractice.forTest({
    String account = 'test@example.com',
    required NarrationPlayer player,
  }) => LitPractice._(account: account, replay: false, player: player);

  /// The Citizen account it is for: where its outcome is kept.
  final String account;

  /// Opened from Profile to watch again: its end does not undo a completion.
  final bool replay;

  /// Lit's voice: the one audio owner.
  final LitNarrator narrator;

  /// Stand in for the speaker in a test.
  @visibleForTesting
  static NarrationPlayer Function()? playerOverride;

  /// Stand in for the way home (the map) in a test.
  @visibleForTesting
  static void Function(BuildContext navigatorContext)? homeOverride;

  NavigatorState? _nav;
  OverlayEntry? _coach;
  bool _started = false;
  bool _ended = false;
  Timer? _beat;

  /// Tells the welcome and the coach to draw again.
  final ValueNotifier<int> changes = ValueNotifier(0);

  int _step = 0;

  /// The beat after Submit Practice Report: Lit approves.
  bool received = false;

  /// The app went to the background: the clip stopped and waits for Replay.
  bool interrupted = false;

  /// Finish's farewell: approve, then a wave.
  bool waving = false;

  LitLesson get lesson => kLitLessons[_step];
  int get step => _step;

  /// Started and not over: the real screens are in practice.
  bool get started => _started && !_ended;

  /// Lit's language: the app's, chosen on the welcome.
  LitLanguage get language => LitTutorial.language;

  /// Open the tutorial: the welcome (01) over [context]'s screen.
  static Future<void> open(
    BuildContext context, {
    required String account,
    bool replay = false,
  }) async {
    if (Practice._session != null) return;
    final nav = Navigator.of(context, rootNavigator: true);
    final practice = LitPractice._(
      account: account,
      replay: replay,
      player: playerOverride?.call(),
    ).._nav = nav;
    Practice._session = practice;
    WidgetsBinding.instance.addObserver(practice);
    LanguageChoice.current.addListener(practice._onLanguage);
    practice._say();
    await nav.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: LitWelcomeScreen.routeName),
        builder: (_) => LitWelcomeScreen(practice: practice),
      ),
    );
    // Back from the welcome, neither started nor skipped: dismissed.
    if (!practice._started && !practice._ended) await practice.skip();
  }

  /// English or Tagalog, chosen on the welcome for the whole app: Lit's
  /// voice and words change with it.
  void _onLanguage() {
    if (_ended) return;
    _say();
    _changed();
  }

  // ── Start, lessons, Back ─────────────────────────────────────────────────

  /// Start Tutorial: the welcome gives way to the map, with Lit over it.
  void start() {
    final nav = _nav;
    if (_started || _ended || nav == null || !nav.mounted) return;
    _started = true;
    nav.popUntil((route) => route.settings.name != LitWelcomeScreen.routeName);
    _goHome();
    final coach = _coach = OverlayEntry(
      builder: (_) => _CoachLayer(practice: this),
    );
    nav.overlay?.insert(coach);
    _enter(_index('tap_sos'));
  }

  void _enter(int index) {
    _beat?.cancel();
    _step = index;
    received = false;
    interrupted = false;
    waving = false;
    // Choosing who responds starts from Fire alone, however it was left.
    if (lesson.action == LitAction.chooseAgency) Practice.resets.value++;
    _say();
    if (lesson.action == LitAction.finish) {
      final at = _step;
      _beat = Timer(const Duration(milliseconds: 1600), () {
        if (_step == at && !_ended && !narrator.talking.value) {
          waving = true;
          _changed();
        }
      });
    }
    _changed();
  }

  void _say() {
    if (!_ended) narrator.say(lesson.clipAsset(language));
  }

  void _changed() => changes.value++;

  /// On to the next lesson, from [from] only: a second tap that arrives
  /// before the first has moved on finds the lesson already changed.
  void _nextFrom(int from) {
    if (!started || from != _step || _step >= kLitLessons.length - 1) return;
    _enter(_step + 1);
  }

  /// What a real screen told: the lesson that waited for it moves on.
  void _on(PracticeEvent event, Object? detail) {
    if (!started) return;
    final at = _step;
    final action = lesson.action;
    switch (event) {
      case PracticeEvent.sosOpened when action == LitAction.tapSos:
      case PracticeEvent.cameraOpened when action == LitAction.holdSos:
      case PracticeEvent.reportOpened when action == LitAction.shutter:
        _nextFrom(at);
      case PracticeEvent.agencyChanged
          when action == LitAction.chooseAgency &&
              detail == (LitTargets.medicalAgency, true):
        _beat?.cancel();
        _beat = Timer(const Duration(milliseconds: 450), () => _nextFrom(at));
      case PracticeEvent.statusOpened when action == LitAction.submit:
        // A practice report "received": Lit approves for a moment.
        narrator.stop();
        received = true;
        _changed();
        _beat = Timer(const Duration(milliseconds: 1400), () => _nextFrom(at));
      default:
        break;
    }
  }

  /// Continue, on a lesson that is read.
  void next(int from) {
    if (lesson.action == LitAction.read) _nextFrom(from);
  }

  /// Whether Back has a lesson to go back to.
  bool get canGoBack => _backTarget != null && !received;

  int? get _backTarget => switch (lesson.name) {
    'hold_sos' => _index('tap_sos'),
    'photo' || 'check_location' => _index('hold_sos'),
    'select_organization' => _index('check_location'),
    'review_details' => _index('select_organization'),
    'practice_submit' => _index('review_details'),
    'follow_updates' => _index('practice_submit'),
    'finish' => _index('follow_updates'),
    _ => null,
  };

  static int _index(String name) =>
      kLitLessons.indexWhere((l) => l.name == name);

  /// Back: the lesson before, and its screen. On the same screen it is put
  /// as it was; a screen pushed for this lesson goes.
  void back() {
    final to = _backTarget;
    final nav = _nav;
    if (!started || !canGoBack || to == null || nav == null) return;
    switch (lesson.name) {
      // The SOS screen: back to the map's SOS.
      case 'hold_sos':
        _goHome();
      // The camera, or the form it gave way to: back to the SOS screen
      // under it. "Getting you help": back to the form it was sent from.
      case 'photo' || 'check_location' || 'follow_updates':
        nav.pop();
    }
    _enter(to);
  }

  // ── Leaving ──────────────────────────────────────────────────────────────

  /// Skip: out at once, remembered as skipped (a replay after finishing
  /// stays completed).
  Future<void> skip() async {
    if (_ended) return;
    _end();
    await LitTutorial.skip(account);
  }

  /// Finish: home, and completed.
  Future<void> finish() async {
    if (_ended) return;
    _end();
    await LitTutorial.complete(account);
  }

  void _end() {
    final wasStarted = _started;
    _ended = true;
    _beat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LanguageChoice.current.removeListener(_onLanguage);
    final coach = _coach;
    _coach = null;
    if (coach != null) {
      coach.remove();
      coach.dispose();
    }
    if (Practice._session == this) Practice._session = null;
    unawaited(narrator.dispose());
    final nav = _nav;
    if (nav == null || !nav.mounted) return;
    if (wasStarted) {
      // The practice screens go; the real home is back.
      _goHome();
    } else {
      nav.popUntil(
        (route) => route.settings.name != LitWelcomeScreen.routeName,
      );
    }
  }

  void _goHome() {
    final nav = _nav;
    if (nav == null || !nav.mounted) return;
    final home = homeOverride;
    if (home != null) {
      home(nav.context);
    } else {
      AppNavBar.switchTo(nav.context, AppTab.map);
    }
  }

  /// Replay: the current clip again, and the pause it may have been in.
  Future<void> replayClip() async {
    interrupted = false;
    _changed();
    await narrator.replay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || _ended) return;
    // Away from the app: stop talking now, and wait for Replay on return.
    if (narrator.talking.value || narrator.clip != null) {
      narrator.stop();
      interrupted = true;
      _changed();
    }
  }

  /// A Back that no practice screen took (the screens' own [PracticeBack]
  /// take it first): still the tutorial's, never out of the app.
  @override
  Future<bool> didPopRoute() async {
    if (!started) return false;
    back();
    return true;
  }
}

/// Lit over the real screens: the dim with the lesson's control lit, and
/// his panel where it does not cover it.
class _CoachLayer extends StatefulWidget {
  const _CoachLayer({required this.practice});

  final LitPractice practice;

  @override
  State<_CoachLayer> createState() => _CoachLayerState();
}

class _CoachLayerState extends State<_CoachLayer> {
  PracticeSpot? _spot;

  /// The lesson whose control was last brought into view.
  int? _revealed;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(_watch);
  }

  /// After every frame (never asking for one): screens slide in and lay
  /// out, and the lit control moves with them. Once a lesson's control is
  /// found, it is brought into view.
  void _watch(Duration _) {
    if (!mounted) return;
    final practice = widget.practice;
    final target = practice.lesson.target;
    final spot = target == null ? null : PracticeTargets.spotOf(target);
    if (spot != _spot) setState(() => _spot = spot);
    if (target != null && spot != null && _revealed != practice.step) {
      _revealed = practice.step;
      PracticeTargets.reveal(target);
    }
    SchedulerBinding.instance.addPostFrameCallback(_watch);
  }

  @override
  Widget build(BuildContext context) {
    final practice = widget.practice;
    return ListenableBuilder(
      listenable: Listenable.merge([
        practice.changes,
        practice.narrator.talking,
        practice.narrator.muted,
      ]),
      builder: (context, _) => _layer(context),
    );
  }

  Widget _layer(BuildContext context) {
    final practice = widget.practice;
    final lesson = practice.lesson;
    final pal = context.pal;
    final screen = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final spot = lesson.target == null ? null : _spot;
    final hole = spot?.rect;
    // On the side of the control with more room: over it when it is low on
    // the screen, under it otherwise.
    final roomAbove = hole == null ? 0.0 : hole.top - safe.top - 24;
    final roomBelow = hole == null
        ? screen.height * 0.5
        : screen.height - hole.bottom - safe.bottom - 24;
    final above = hole != null && roomAbove > roomBelow;
    final room = above ? roomAbove : roomBelow;
    // Never so short that Lit, Back and Continue do not fit: on a small
    // phone at a large text size it covers the edge of what is lit rather
    // than lose them, and his words scroll.
    final most = math.max(260.0, screen.height * 0.55);
    final reading = const {
      LitAction.read,
      LitAction.finish,
    }.contains(lesson.action);
    final least = math.min(reading ? 270.0 : 210.0, most);
    return Stack(
      children: [
        if (spot != null)
          Positioned.fill(
            child: _Spotlight(
              hole: spot.rect,
              round: spot.round,
              touchable: lesson.touches && !practice.received,
              dim: pal.scrim,
              ring: pal.accent,
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: above ? safe.top + 8 : null,
          bottom: above ? null : safe.bottom + 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: room.clamp(least, most)),
            child: _Panel(
              practice: practice,
              pose: _pose(practice, hole, screen, above),
            ),
          ),
        ),
      ],
    );
  }

  /// Lit points up at a control above him, from the side away from it;
  /// with the control below, he presents it.
  LitPose _pose(LitPractice practice, Rect? hole, Size screen, bool above) {
    if (practice.received) return LitPose.approve;
    if (practice.waving) return LitPose.wave;
    final lesson = practice.lesson;
    if (hole == null || lesson.pose == LitPose.review) return lesson.pose;
    if (above) return LitPose.present;
    return hole.center.dx < screen.width / 2
        ? LitPose.pointUpperLeft
        : LitPose.pointUpperRight;
  }
}

/// Lit's panel: Practice mode and its controls, the step, Lit and his words,
/// Back, and Continue or Finish across the width.
class _Panel extends StatelessWidget {
  const _Panel({required this.practice, required this.pose});

  final LitPractice practice;
  final LitPose pose;

  String _say(String en, String tl) =>
      practice.language == LitLanguage.tl ? tl : en;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lesson = practice.lesson;
    final reading = lesson.action == LitAction.read;
    final finishing = lesson.action == LitAction.finish;
    final litLeft = pose == LitPose.pointUpperRight;
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final caption = Semantics(
      liveRegion: true,
      child: Text(
        practice.received
            ? _say(
                'Practice report received. Nothing was sent.',
                'Natanggap ang practice report. Walang naipadala.',
              )
            : lesson.caption(practice.language),
        key: const ValueKey('lit-caption'),
        style: context.type.body.copyWith(color: pal.onBackground),
      ),
    );
    return Material(
      key: const ValueKey('lit-coach'),
      color: pal.surface,
      elevation: 8,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PracticeModePill(),
                  ),
                ),
                LitVoiceControls(practice: practice),
                TextLink(_say('Skip', 'Laktawan'), onTap: practice.skip),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Eyebrow(
                _say(
                  'Step ${int.parse(lesson.id)} of $kLitLessonCount',
                  'Hakbang ${int.parse(lesson.id)} sa $kLitLessonCount',
                ),
                color: pal.accentInk,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: LayoutBuilder(
                  // Lit as big as the panel leaves him, his words beside.
                  builder: (context, box) {
                    final size = math.min(narrow ? 76.0 : 88.0, box.maxHeight);
                    final lit = Semantics(
                      label: 'Lit',
                      image: true,
                      child: LitCharacter(
                        pose: pose,
                        talking:
                            practice.narrator.talking.value &&
                            !practice.received,
                        size: size,
                      ),
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (litLeft) ...[lit, const SizedBox(width: 8)],
                        Expanded(child: SingleChildScrollView(child: caption)),
                        if (!litLeft) ...[const SizedBox(width: 8), lit],
                      ],
                    );
                  },
                ),
              ),
            ),
            if (practice.interrupted) ...[
              const SizedBox(height: 6),
              Text(
                _say(
                  'Paused. Tap replay to hear Lit again.',
                  'Naka-pause. I-tap ang replay para marinig ulit si Lit.',
                ),
                style: context.type.caption.copyWith(color: pal.warn),
              ),
            ],
            if (practice.canGoBack)
              Align(
                alignment: Alignment.centerLeft,
                child: TextLink(_say('Back', 'Bumalik'), onTap: practice.back),
              ),
            if (reading || finishing) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: AppButton(
                  finishing ? 'Finish' : 'Continue',
                  height: 54,
                  onPressed: finishing
                      ? practice.finish
                      : () => practice.next(practice.step),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "PRACTICE MODE", always on show while Lit is: smaller rather than
/// pushing the controls beside it off a narrow screen.
class PracticeModePill extends StatelessWidget {
  const PracticeModePill({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    );
  }
}

/// Lit's voice on or off, and Replay.
class LitVoiceControls extends StatelessWidget {
  const LitVoiceControls({super.key, required this.practice});

  final LitPractice practice;

  String _say(String en, String tl) =>
      practice.language == LitLanguage.tl ? tl : en;

  @override
  Widget build(BuildContext context) {
    final muted = practice.narrator.muted.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconControl(
          icon: muted ? AppIcons.volumeOff : AppIcons.volumeUp,
          label: muted
              ? _say("Turn Lit's voice on", 'Buksan ang boses ni Lit')
              : _say("Turn Lit's voice off", 'Patayin ang boses ni Lit'),
          onTap: () => practice.narrator.setMuted(!muted),
        ),
        _IconControl(
          icon: AppIcons.restartAlt,
          label: _say('Hear Lit again', 'Pakinggan ulit si Lit'),
          onTap: practice.lesson.clip == null ? null : practice.replayClip,
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

/// The screen dimmed with a hole where the lit control is, ringed in coral.
/// Outside the hole every touch stops here; inside it, a touch reaches the
/// control when the lesson waits for one ([touchable]).
class _Spotlight extends LeafRenderObjectWidget {
  const _Spotlight({
    required this.hole,
    required this.round,
    required this.touchable,
    required this.dim,
    required this.ring,
  });

  final Rect hole;
  final bool round;
  final bool touchable;
  final Color dim;
  final Color ring;

  @override
  _RenderSpotlight createRenderObject(BuildContext context) => _RenderSpotlight(
    hole: hole,
    round: round,
    touchable: touchable,
    dim: dim,
    ring: ring,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSpotlight render) {
    render
      ..hole = hole
      ..round = round
      ..touchable = touchable
      ..dim = dim
      ..ring = ring;
  }
}

class _RenderSpotlight extends RenderBox {
  _RenderSpotlight({
    required Rect hole,
    required bool round,
    required bool touchable,
    required Color dim,
    required Color ring,
  }) : _hole = hole,
       _round = round,
       _touchable = touchable,
       _dim = dim,
       _ring = ring;

  Rect _hole;
  set hole(Rect value) {
    if (value == _hole) return;
    _hole = value;
    markNeedsPaint();
  }

  bool _round;
  set round(bool value) {
    if (value == _round) return;
    _round = value;
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

  RRect get _cut {
    final cut = _hole.inflate(6);
    return RRect.fromRectAndRadius(
      cut,
      Radius.circular(_round ? cut.shortestSide / 2 : 16),
    );
  }

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
