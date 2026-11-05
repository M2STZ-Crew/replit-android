import 'dart:async';

import 'package:flutter/material.dart';

import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'login_screen.dart';
import 'role_gate.dart';
import '../i18n/i18n.dart';

/// "01 Splash": the flame-and-pin mark and the "REPLIT" wordmark from the
/// Figma archive's LOGO section (01 — Existing Design Archive), a short coral
/// loader, "Connecting to RepLiT", and the locality at the foot. The wordmark
/// has a version for each ground, so light mode gets the black one rather
/// than a tinted copy. This and the SOS button are the only two places the
/// design allows glow (§2.7).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// Two controllers — the breathing halo and the loader — so the plural mixin.
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  late final AnimationController _loader = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _breathe.dispose();
    _loader.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Session.instance.restore();
    if (Session.instance.isAuthenticated) {
      unawaited(PushService.instance.syncForUser());
    }
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final Widget next = Session.instance.isAuthenticated
        ? const RoleGate()
        : const LoginScreen();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.background,
      body: SafeArea(
        // Padded, and every line below wraps: at the larger system font
        // scales people actually use, an unpadded single-line footer runs
        // off both edges of the screen.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          // Full width on purpose: a Scaffold body is laid out with loose
          // constraints, so a Column of fixed-width children shrinks to its
          // widest one and lands against the left edge instead of the middle.
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                // The frame puts the mark's centre at ~40% and the locality
                // 64px off the bottom; 3:2 flex keeps that on any height.
                const Spacer(flex: 3),
                _markInGlow(),
                const SizedBox(height: 36),
                Image.asset(
                  pal.isLight ? Art.wordmarkOnLight : Art.wordmarkOnDark,
                  width: 128,
                  height: 23,
                  semanticLabel: 'RepLiT',
                ),
                const SizedBox(height: 48),
                _loaderBar(),
                const SizedBox(height: 16),
                // Sentence case, so the name keeps its own capitals.
                Text(
                  t('Connecting to RepLiT'),
                  textAlign: TextAlign.center,
                  style: context.type.detail.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  t('Pasay City'),
                  textAlign: TextAlign.center,
                  style: context.type.labelSm,
                ),
                const SizedBox(height: 6),
                Text(
                  t('EMERGENCY RESPONSE NETWORK'),
                  textAlign: TextAlign.center,
                  style: context.type.eyebrow.copyWith(
                    color: context.pal.muted,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The mark at the Figma's 100×140, with its glow ("Mark glow (permitted
  /// §2.7)") breathing behind it while the session restores. The glow spills
  /// past the mark without pushing the wordmark down, centred a little below
  /// the middle, on the round of the flame rather than its tip.
  Widget _markInGlow() {
    const width = 100.0;
    const height = 140.0;
    const glow = 230.0;
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, child) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: (width - glow) / 2,
              top: (height - glow) / 2 + 12,
              width: glow,
              height: glow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.pal.accent.withValues(
                        alpha: 0.16 + _breathe.value * 0.06,
                      ),
                      context.pal.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Transform.scale(scale: 1 + _breathe.value * 0.04, child: child),
          ],
        ),
        child: Image.asset(Art.logoMark, width: width, height: height),
      ),
    );
  }

  /// A 34px coral segment running along a 106px track — the design's loader.
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
                    borderRadius: BorderRadius.all(Radius.circular(2)),
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
