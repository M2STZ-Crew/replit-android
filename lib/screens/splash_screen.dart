import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../i18n/i18n.dart';
import '../theme.dart';
import '../updates/update_nudge.dart';
import '../widgets/launch_mark.dart';
import 'call_screen.dart';
import 'login_screen.dart';
import 'role_gate.dart';

/// "01 Splash" (the Figma archive's 01 — Existing Design Archive), in two
/// states.
///
/// The trigger: the flame-and-pin mark alone in the middle of the screen,
/// where and as big as the phone's own launch screen drew it ([LaunchMark]),
/// so the hand-off from the phone to the app doesn't show. Then loading: the
/// same, with the coral loader and "Connecting to RepLiT" near the foot, until
/// the next screen is ready. No wordmark, glow or footer: the reference has
/// none.
///
/// For someone signed in, ready means their home: the splash loads the
/// account (GET /auth/me) and hands it to [RoleGate], so opening the app never
/// shows a skeleton. A slow or failed load is answered here, at the foot, with
/// the same words and ways out RoleGate gives after signing in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.api});

  /// The client the account is loaded with (tests give their own).
  final ApiClient? api;

  /// How long the trigger shows before the loader comes in.
  static const Duration triggerFor = Duration(milliseconds: 600);

  /// The least the splash shows in all, so the loader is read rather than
  /// flashed: trigger, then at least 0.8 s of loading.
  static const Duration shownAtLeast = Duration(milliseconds: 1400);

  /// From the foot of the screen to the foot of the status line: the
  /// reference's 58 on its 874-high phone. Never closer than 24 above a home
  /// indicator or navigation bar.
  static double footGap(EdgeInsets viewPadding) =>
      math.max(58, viewPadding.bottom + 24);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  late final ApiClient _api = widget.api ?? ApiClient();
  final Stopwatch _shown = Stopwatch()..start();
  Timer? _trigger;
  Timer? _slowTimer;

  /// Past the trigger: the loader and the status line are showing.
  bool _loading = false;

  /// The account is taking a while: say why, and offer the hotlines.
  bool _slow = false;

  /// The account didn't load: say so, and offer a way on.
  bool _failed = false;

  /// Why, when it is not the connection: the organisation is suspended or
  /// revoked (backend v1.12.28).
  String? _why;

  @override
  void initState() {
    super.initState();
    // A newer release? Looked for while the splash is up, so the home screen
    // has the banner as it appears.
    unawaited(UpdateNudge.start());
    _trigger = Timer(SplashScreen.triggerFor, () {
      if (!mounted) return;
      setState(() => _loading = true);
      _loader.repeat();
    });
    _boot();
  }

  @override
  void dispose() {
    _trigger?.cancel();
    _slowTimer?.cancel();
    _loader.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Session.instance.restore();
    if (!Session.instance.isAuthenticated) return _go(const LoginScreen());
    unawaited(PushService.instance.syncForUser());
    await _loadAccount();
  }

  Future<void> _loadAccount() async {
    _slowTimer?.cancel();
    _slowTimer = Timer(ApiClient.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    Widget? next;
    try {
      final me = await _api.getMe().timeout(ApiClient.signInTimeout);
      // The account's language, as the console or another phone left it.
      await LanguageChoice.adopt(me['language']);
      next = RoleGate(initialMe: me);
    } on SessionExpiredException {
      // The stored session was too old to renew and the client has cleared
      // it: sign in, rather than an error whose Retry re-sends a dead token.
      await Session.instance.clear();
      next = const LoginScreen();
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _why = frozenOrganization(e) ? (e as ApiException).message : null;
        });
      }
    } finally {
      _slowTimer?.cancel();
    }
    if (next != null) await _go(next);
  }

  Future<void> _retry() async {
    setState(() {
      _failed = false;
      _slow = false;
    });
    await _loadAccount();
  }

  /// Drop whatever is stored and start again at the login screen, so nobody
  /// is cornered here by an account that won't load.
  Future<void> _signInAgain() async {
    await Session.instance.clear();
    await _go(const LoginScreen());
  }

  Future<void> _go(Widget next) async {
    final wait = SplashScreen.shownAtLeast - _shown.elapsed;
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final splash = ModalRoute.of(context);
    final route = MaterialPageRoute<void>(builder: (_) => next);
    if (splash != null && !splash.isCurrent) {
      // The hotlines are open over the splash: put the next screen under
      // them, so Back from the hotlines lands there, and leave the call be.
      navigator.replace(oldRoute: splash, newRoute: route);
    } else {
      unawaited(navigator.pushReplacement(route));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.background,
      body: LayoutBuilder(
        builder: (context, box) {
          final view = box.biggest;
          final mark = LaunchMark.sizeFor(view.shortestSide);
          final centre = LaunchMark.centreIn(context, view);
          return Stack(
            children: [
              Positioned(
                left: centre.dx - mark.width / 2,
                top: centre.dy - mark.height / 2,
                width: mark.width,
                height: mark.height,
                child: LaunchMark.image(context, semanticLabel: 'RepLiT'),
              ),
              if (_loading || _failed)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: SplashScreen.footGap(
                    MediaQuery.viewPaddingOf(context),
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 240),
                    builder: (context, shown, child) =>
                        Opacity(opacity: shown, child: child),
                    child: _failed ? _failure() : _status(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The loader and "Connecting to RepLiT"; when it is slow, why, and the
  /// hotlines.
  Widget _status() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _loaderBar(),
        const SizedBox(height: 18),
        // Sentence case, so the name keeps its own capitals.
        Text(
          t('Connecting to RepLiT'),
          textAlign: TextAlign.center,
          style: context.type.detail.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        if (_slow) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              t(
                'Still connecting. RepLiT can take up to a minute to wake '
                'after a quiet spell.',
              ),
              textAlign: TextAlign.center,
              style: context.type.caption.copyWith(color: context.pal.label),
            ),
          ),
          _hotlinesLink(),
        ],
      ],
    );
  }

  /// The account didn't load: try again, sign in again, or call for help.
  Widget _failure() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            _why ?? t('Could not load your account.'),
            textAlign: TextAlign.center,
            style: context.type.detail.copyWith(color: context.pal.muted),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: _retry,
              child: Text(
                t('Retry'),
                style: TextStyle(
                  color: context.pal.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _signInAgain,
              child: Text(
                t('Sign in again'),
                style: TextStyle(color: context.pal.muted),
              ),
            ),
          ],
        ),
        _hotlinesLink(),
      ],
    );
  }

  /// No account needed, and maybe no signal: the hotlines need neither.
  Widget _hotlinesLink() => TextButton(
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CallScreen(guest: true)),
    ),
    child: Text(
      t('Emergency hotlines'),
      style: TextStyle(color: context.pal.accent, fontWeight: FontWeight.w700),
    ),
  );

  /// A 34px coral segment running along a 106px track: the design's loader.
  Widget _loaderBar() {
    const track = 106.0;
    const fill = 34.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: track,
        height: 3,
        color: context.pal.lineStrong,
        child: AnimatedBuilder(
          animation: _loader,
          builder: (context, _) => Stack(
            children: [
              Positioned(
                left: -fill + (track + fill) * _loader.value,
                top: 0,
                bottom: 0,
                width: fill,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.pal.accent,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
