import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../api/push_service.dart';
import '../api/report_queue.dart';
import '../diagnostics/report_timing.dart';
import '../location/sos_location.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'camera_capture_screen.dart';

/// "07 SOS" from the REPLIT-OVERHAUL Figma — the screen behind the SOS disc.
///
/// The three-second hold is deliberate friction — a single tap on a big button
/// in a pocket would flood dispatchers with false alarms. The design wraps that
/// in reassurance rather than alarm: "You're covered", a calm status pill, and
/// one hard line about false alerts at the bottom.
///
/// Two departures from the frame, both for honesty (§2.7.1). Its subtitle says
/// the location goes "immediately — details come after"; the server takes no
/// report without a photo, so the line says the photo comes first. And its
/// pill is fixed text; this one reports the real location and signal state.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Two controllers live here — the hold ring and the breathing halo — so this
// needs the plural TickerProviderStateMixin. SingleTicker... throws at build.
class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _triggerSos();
        });

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  /// Location services on and permitted. Null until checked, or when the
  /// platform will not say.
  bool? _locationOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReportQueue.instance.offline.addListener(_rebuild);
    _checkLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Keep location fresh so this user stays reachable by nearby-incident
      // alerts — and re-read the pill, in case they just switched GPS on.
      PushService.instance.refreshLocation();
      _checkLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReportQueue.instance.offline.removeListener(_rebuild);
    _hold.dispose();
    _breathe.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _checkLocation() async {
    try {
      final on = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      final ok =
          on &&
          (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse);
      if (mounted) setState(() => _locationOk = ok);
    } catch (_) {
      if (mounted) setState(() => _locationOk = null);
    }
  }

  Future<void> _fixLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      } else {
        final perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
      }
    } catch (_) {
      // Nothing more to offer from here; the pill stays as it is.
    }
    await _checkLocation();
  }

  void _startHold() {
    HapticFeedback.selectionClick();
    // The three seconds of the hold are free time for the GPS: start the fix
    // now rather than when the camera opens (v10 §6). Without asking for
    // permission — a dialog here would cancel the hold under the thumb.
    ReportTiming.instance.start('sos');
    SosLocation.instance.warmUp(requestPermission: false);
    _hold.forward();
  }

  void _cancelHold() {
    if (_hold.status != AnimationStatus.completed) _hold.reset();
  }

  Future<void> _triggerSos() async {
    HapticFeedback.heavyImpact();
    ReportTiming.instance.mark('hold_complete');
    _hold.reset();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CameraCaptureScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.sos),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 32).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statusPill(),
                  const SizedBox(height: 14),
                  const Text(
                    "YOU'RE COVERED",
                    textAlign: TextAlign.center,
                    style: AppText.heading2,
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 290,
                    child: Text(
                      'Hold the dial, take one photo, and your location goes '
                      'to Barangay 76 with it.',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // The glow is 320px; on a 360dp-wide phone that is wider
                  // than the column, so the dial scales down rather than clip.
                  FittedBox(fit: BoxFit.scaleDown, child: _sosDial()),
                  const SizedBox(height: 4),
                  _holdLabel(),
                  const SizedBox(height: 36),
                  _cautionCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What the phone can actually do right now, in one line.
  Widget _statusPill() {
    final offline = ReportQueue.instance.offline.value;
    final (Color dot, String text, VoidCallback? onTap) = switch (_locationOk) {
      false => (AppColors.live, 'Location off — tap to turn on', _fixLocation),
      _ when offline => (AppColors.warn, 'No signal — reports will wait', null),
      true => (AppColors.ok, 'Connected, location on', null),
      null => (AppColors.ok, 'Connected', null),
    };
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.eyebrow.copyWith(color: AppColors.label),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: pill),
    );
  }

  Widget _sosDial() {
    return Semantics(
      button: true,
      label: 'SOS. Press and hold for three seconds to start a report.',
      child: GestureDetector(
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // "SOS glow (permitted §2.7)" — one of the two places the design
              // allows glow. It breathes, slowly.
              AnimatedBuilder(
                animation: _breathe,
                builder: (context, _) => Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(
                          alpha: 0.10 + _breathe.value * 0.06,
                        ),
                        AppColors.accent.withValues(alpha: 0),
                      ],
                      stops: const [0.45, 1],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 230,
                height: 230,
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => CircularProgressIndicator(
                    value: _hold.value,
                    strokeWidth: 3,
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
                    begin: Alignment(-0.35, -1),
                    end: Alignment(0.35, 1),
                    stops: [0.116, 0.891],
                    colors: [AppColors.surface, AppColors.surfaceSolid],
                  ),
                  border: Border.all(color: AppColors.lineStrong),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(Art.mark, width: 64, height: 64),
                    const SizedBox(height: 10),
                    const Text('SOS', style: AppText.dial),
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
            ? 'Hold 3 seconds to send'
            : _hold.value < 1
            ? 'Keep holding'
            : 'Release';
        return Column(
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppText.eyebrow.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: 14),
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
      radius: AppRadius.card,
      padding: const EdgeInsets.all(16),
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
              style: AppText.detail.copyWith(color: AppColors.textSoft),
            ),
          ),
        ],
      ),
    );
  }
}
