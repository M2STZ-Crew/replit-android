import 'dart:async';

import 'package:flutter/material.dart';

import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'login_screen.dart';
import 'role_gate.dart';

/// The splash from the "General User App v2" hand-off: a slow breathing halo
/// behind the mark while the session is restored. This and the SOS button are
/// the only two places the design allows glow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _breathe.dispose();
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.16),
            radius: 0.8,
            colors: [Color(0x1CFF9066), Color(0x00131313)],
          ),
        ),
        child: SafeArea(
          // Padded, and every line below wraps: at the larger system font
          // scales people actually use, an unpadded single-line footer runs
          // off both edges of the screen.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _breathe,
                builder: (context, child) => Transform.scale(
                  scale: 1 + _breathe.value * 0.06,
                  child: Opacity(
                    opacity: 0.92 + _breathe.value * 0.08,
                    child: child,
                  ),
                ),
                child: Image.asset(Art.mark, width: 112, height: 112),
              ),
              const SizedBox(height: 34),
              Image.asset(Art.wordmark, width: 186, fit: BoxFit.contain),
              const Spacer(flex: 2),
              const SizedBox(
                width: 106,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'CONNECTING TO PASAY CITY',
                textAlign: TextAlign.center,
                style: AppText.eyebrow.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              Text(
                'FIRE VOLUNTEER RESPONSE · PASAY CITY',
                textAlign: TextAlign.center,
                style: AppText.tag.copyWith(
                  fontSize: 10,
                  height: 1.5,
                  letterSpacing: 0.6,
                  color: AppColors.faint,
                ),
              ),
              const SizedBox(height: 24),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
