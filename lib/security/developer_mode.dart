import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../i18n/i18n.dart';

/// Android's Developer options must be off for RepLiT to run.
///
/// They are where a phone is told to take its location from another app — a
/// fake-GPS app — and a report, a neighbour's alert and a responder's
/// position are only worth anything if the location is real. So a release
/// build will not run while they are on (the 5 November issue list, 2.1).
///
/// Debug and profile builds are exempt: they are what the team runs from a
/// laptop over USB, and USB debugging lives inside Developer options. iPhones
/// have no such switch.
abstract final class DeveloperMode {
  static const MethodChannel _channel = MethodChannel('replit/device');

  /// Whether this build checks at all: an Android release build.
  static bool get enforced =>
      enforcedOverride ??
      (kReleaseMode &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android);

  /// For tests: whether to check, whatever the build.
  @visibleForTesting
  static bool? enforcedOverride;

  /// For tests: what the phone answers.
  @visibleForTesting
  static Future<bool> Function()? probeOverride;

  /// Whether Developer options are on right now. A phone that cannot say is
  /// taken at its word as off: a broken check must not lock anyone out of
  /// reporting a fire.
  static Future<bool> isOn() async {
    final probe = probeOverride;
    if (probe != null) return probe();
    try {
      return await _channel.invokeMethod<bool>('developerOptions') ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  /// Open Developer options in Settings (or Settings itself, where a phone
  /// has no direct way in). False when neither would open.
  static Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openDeveloperOptions') ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }
}

/// Covers the whole app while Developer options are on, in a build that
/// [DeveloperMode.enforced]. Checked when the app starts and each time it
/// comes back to the front — the way back from Settings, where they are
/// turned off.
///
/// The app underneath keeps its place: once they are off, the resident is
/// exactly where they were.
class DeveloperModeGate extends StatefulWidget {
  const DeveloperModeGate({super.key, required this.child});

  final Widget child;

  @override
  State<DeveloperModeGate> createState() => _DeveloperModeGateState();
}

class _DeveloperModeGateState extends State<DeveloperModeGate>
    with WidgetsBindingObserver {
  bool _blocked = false;

  /// Set when "I've turned them off" finds them still on.
  bool _stillOn = false;

  @override
  void initState() {
    super.initState();
    if (!DeveloperMode.enforced) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check({bool asked = false}) async {
    final on = await DeveloperMode.isOn();
    if (!mounted) return;
    setState(() {
      _blocked = on;
      _stillOn = asked && on;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Kept, not rebuilt: the place in the app survives the block.
        ExcludeSemantics(
          excluding: _blocked,
          child: AbsorbPointer(absorbing: _blocked, child: widget.child),
        ),
        if (_blocked)
          DeveloperModeBlock(
            stillOn: _stillOn,
            onRecheck: () => _check(asked: true),
          ),
      ],
    );
  }
}

/// "Turn off Developer options": what the gate shows, and the three ways out
/// of it — to Settings, back after turning them off, or a call to 911 for
/// someone who opened the app because something is on fire.
class DeveloperModeBlock extends StatelessWidget {
  const DeveloperModeBlock({
    super.key,
    required this.onRecheck,
    this.stillOn = false,
  });

  final VoidCallback onRecheck;
  final bool stillOn;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: pal.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: IconWell(
                    tint: pal.live,
                    icon: AppIcons.construction,
                    size: 64,
                    glyph: 30,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  t('TURN OFF DEVELOPER OPTIONS'),
                  textAlign: TextAlign.center,
                  style: context.type.title,
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    "RepLiT can't run while Android's Developer options are on. "
                    'They let another app change where your phone says it is, '
                    'and every report needs your real location.',
                  ),
                  textAlign: TextAlign.center,
                  style: context.type.body,
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    'Open Settings, switch Developer options off, then come '
                    'back here.',
                  ),
                  textAlign: TextAlign.center,
                  style: context.type.bodySm.copyWith(color: pal.textSoft),
                ),
                if (stillOn) ...[
                  const SizedBox(height: 14),
                  Text(
                    t(
                      'They are still on. Switch off the toggle at the top of '
                      'Developer options.',
                    ),
                    key: const ValueKey('developer-mode-still-on'),
                    textAlign: TextAlign.center,
                    style: context.type.bodySm.copyWith(color: pal.live),
                  ),
                ],
                const SizedBox(height: 26),
                AppButton(
                  t('Open Developer options'),
                  icon: AppIcons.openInNew,
                  onPressed: () => unawaited(DeveloperMode.openSettings()),
                ),
                const SizedBox(height: 10),
                AppButton.secondary(
                  t("I've turned them off"),
                  onPressed: onRecheck,
                ),
                const SizedBox(height: 22),
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        unawaited(launchUrl(Uri(scheme: 'tel', path: '911'))),
                    icon: Icon(AppIcons.call, size: 18, color: pal.live),
                    label: Text(
                      t('In an emergency, call 911'),
                      style: context.type.rowTitle.copyWith(color: pal.live),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
