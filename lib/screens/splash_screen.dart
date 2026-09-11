import 'dart:async';

import 'package:flutter/material.dart';

import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'login_screen.dart';
import 'role_gate.dart';

/// "01 Splash" from the REPLIT-OVERHAUL Figma: the mark in its glow, the
/// plain wordmark, a short coral loader, and the locality at the foot. This
/// and the SOS button are the only two places the design allows glow (§2.7).
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // Padded, and every line below wraps: at the larger system font
        // scales people actually use, an unpadded single-line footer runs
        // off both edges of the screen.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // The frame puts the mark's centre at ~40% and the locality
              // 64px off the bottom; 3:2 flex keeps that on any height.
              const Spacer(flex: 3),
              _markInGlow(),
              // 125px from the mark in the frame, less the glow's 39px margin.
              const SizedBox(height: 86),
              Image.asset(Art.wordmarkType, width: 118, height: 21),
              const SizedBox(height: 52),
              _loaderBar(),
              const SizedBox(height: 18),
              Text(
                'CONNECTING TO BARANGAY 76',
                textAlign: TextAlign.center,
                style: AppText.eyebrow.copyWith(color: AppColors.muted),
              ),
              const Spacer(flex: 2),
              Text(
                'Barangay 76, Pasay City',
                textAlign: TextAlign.center,
                style: AppText.labelSm,
              ),
              const SizedBox(height: 6),
              Text(
                'EMERGENCY RESPONSE NETWORK',
                textAlign: TextAlign.center,
                style: AppText.eyebrow.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// The 112px mark inside its 190px glow ("Mark glow (permitted §2.7)"),
  /// breathing slowly while the session restores.
  Widget _markInGlow() {
    return SizedBox(
      width: 190,
      height: 190,
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(
                      alpha: 0.16 + _breathe.value * 0.06,
                    ),
                    AppColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Transform.scale(scale: 1 + _breathe.value * 0.04, child: child),
          ],
        ),
        child: Image.asset(Art.mark, width: 112, height: 112),
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
        color: AppColors.lineStrong,
        child: AnimatedBuilder(
          animation: _loader,
          builder: (context, _) => Stack(
            children: [
              Positioned(
                left: -fill + (track + fill) * _loader.value,
                top: 0,
                bottom: 0,
                width: fill,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
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
