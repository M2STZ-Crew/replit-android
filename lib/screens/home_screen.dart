import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/push_service.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import '../widgets/notification_bell.dart';
import 'camera_capture_screen.dart';
import 'profile_screen.dart';

/// The SOS tab, from the "General User App v2" hand-off.
///
/// The three-second hold is deliberate friction — a single tap on a big button
/// in a pocket would flood dispatchers with false alarms. The design wraps that
/// in reassurance rather than alarm: "You're covered", a calm connected pill,
/// and one hard line about false alerts at the bottom.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Two controllers live here — the hold ring and the breathing halo — so this
// needs the plural TickerProviderStateMixin. SingleTicker... throws at build.
class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed) _triggerSos();
  });

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep location fresh so this user stays reachable by nearby-incident alerts.
    if (state == AppLifecycleState.resumed) {
      PushService.instance.refreshLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hold.dispose();
    _breathe.dispose();
    super.dispose();
  }

  void _startHold() {
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _cancelHold() {
    if (_hold.status != AnimationStatus.completed) _hold.reset();
  }

  Future<void> _triggerSos() async {
    HapticFeedback.heavyImpact();
    _hold.reset();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CameraCaptureScreen()));
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.sos),
      body: DecoratedBox(
        // The one place besides the splash where the design allows glow.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 0.9,
            colors: [Color(0x17FF9066), Color(0x00131313)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Image.asset(Art.wordmark, height: 30, fit: BoxFit.contain),
                        const Spacer(),
                        const NotificationBell(),
                        const SizedBox(width: 8),
                        AvatarWell(onTap: _openProfile),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _connectedPill(),
                    const SizedBox(height: 12),
                    const Text(
                      "YOU'RE COVERED",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        height: 28 / 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(
                      width: 280,
                      child: Text(
                        'Hold the button when something is wrong. Your location '
                        'goes straight to the responders for your area.',
                        textAlign: TextAlign.center,
                        style: AppText.body,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _sosButton(),
                    const SizedBox(height: 24),
                    _holdLabel(),
                    const SizedBox(height: 30),
                    _cautionCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectedPill() {
    // No fixed height, and the label is Flexible: at a 1.5x system font scale
    // this pill is wider than the screen otherwise.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveDot(color: AppColors.ember, size: 8),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'CONNECTED · LOCATION ON',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.label,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sosButton() {
    return Semantics(
      button: true,
      label: 'SOS. Press and hold for three seconds to start a report.',
      child: GestureDetector(
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: SizedBox(
          width: 244,
          height: 244,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Breathing halo behind the dial.
              AnimatedBuilder(
                animation: _breathe,
                builder: (context, _) => Container(
                  width: 244 + _breathe.value * 14,
                  height: 244 + _breathe.value * 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(
                          alpha: 0.10 + _breathe.value * 0.06,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.55, 1],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 236,
                height: 236,
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => CircularProgressIndicator(
                    value: _hold.value,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.lineStrong,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF262626), AppColors.surfaceSolid],
                  ),
                  border: Border.all(color: AppColors.lineStrong),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(Art.mark, width: 64, height: 64),
                    const SizedBox(height: 10),
                    const Text(
                      'SOS',
                      style: TextStyle(
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.onBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _holdLabel() {
    return AnimatedBuilder(
      animation: _hold,
      builder: (context, _) {
        final label = _hold.value == 0
            ? 'HOLD FOR 3 SECONDS'
            : _hold.value < 1
                ? 'KEEP HOLDING'
                : 'RELEASE';
        return Column(
          children: [
            Text(
              label,
              style: AppText.eyebrow.copyWith(
                fontSize: 12,
                letterSpacing: 0.6,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 106,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _hold.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cautionCard() {
    return Panel(
      radius: AppRadius.control,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.live,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Only for real emergencies. Every false alert takes a truck away '
              'from someone who needs it.',
              style: AppText.meta.copyWith(
                fontSize: 12,
                height: 17 / 12,
                color: AppColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
