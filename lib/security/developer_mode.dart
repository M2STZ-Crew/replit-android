import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../i18n/i18n.dart';

/// Android's Developer options must be off for RepLiT to be used.
///
/// They are where a phone is told to take its location from another app — a
/// fake-GPS app — and a report, a neighbour's alert and a responder's
/// position are only worth anything if the location is real. So a release
/// build opens to a warning while they are on, the way GCash does: Exit, or a
/// call to 911 (the 5 November issue list, 2.1, and issue 1 after it).
///
/// Debug and profile builds are exempt: they are what the team runs from a
/// laptop over USB, and USB debugging lives inside Developer options. iPhones
/// are not checked: sideloading RepLiT needs iOS's own Developer Mode on.
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
  static Future<DeviceRisk?> Function()? probeOverride;

  /// For tests: what Exit does.
  @visibleForTesting
  static Future<void> Function()? exitOverride;

  /// What is on right now, or null when nothing is. A phone that cannot say
  /// is taken at its word as off: a broken check must not lock anyone out of
  /// reporting a fire.
  static Future<DeviceRisk?> check() async {
    final probe = probeOverride;
    if (probe != null) return probe();
    try {
      final found = await _channel.invokeMapMethod<String, Object?>(
        'deviceSettings',
      );
      return DeviceRisk.from(
        developerOptions: found?['developerOptions'] == true,
        usbDebugging: found?['usbDebugging'] == true,
      );
    } on PlatformException catch (_) {
      return null;
    } on MissingPluginException catch (_) {
      return null;
    }
  }

  /// Close RepLiT and take it out of Recents, so it checks again from the
  /// start when it is next opened.
  static Future<void> exit() async {
    final override = exitOverride;
    if (override != null) return override();
    try {
      await _channel.invokeMethod<void>('exit');
    } on PlatformException catch (_) {
      await SystemNavigator.pop();
    } on MissingPluginException catch (_) {
      await SystemNavigator.pop();
    }
  }
}

/// Why the warning is up, and the reference code it shows.
enum DeviceRisk {
  /// Developer options are on.
  developerOptions('02'),

  /// Developer options are on, and USB debugging inside them.
  usbDebugging('03');

  const DeviceRisk(this.ref);

  /// Shown as "Ref 02", for whoever the resident asks for help.
  final String ref;

  /// USB debugging on its own does not count. It lives inside Developer
  /// options, so a phone that reports it on while they are off would leave
  /// the resident nothing they could switch off.
  static DeviceRisk? from({
    required bool developerOptions,
    required bool usbDebugging,
  }) {
    if (!developerOptions) return null;
    return usbDebugging ? DeviceRisk.usbDebugging : DeviceRisk.developerOptions;
  }
}

/// Puts the warning over the whole app while Developer options are on, in a
/// build that [DeveloperMode.enforced]. Checked when the app starts and each
/// time it comes back to the front, so the warning goes as soon as they are
/// turned off.
///
/// The app opens underneath and keeps its place, out of reach while the
/// warning is up.
class DeveloperModeGate extends StatefulWidget {
  const DeveloperModeGate({super.key, required this.child});

  final Widget child;

  @override
  State<DeveloperModeGate> createState() => _DeveloperModeGateState();
}

class _DeveloperModeGateState extends State<DeveloperModeGate>
    with WidgetsBindingObserver {
  DeviceRisk? _risk;

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

  Future<void> _check() async {
    final risk = await DeveloperMode.check();
    if (!mounted || risk == _risk) return;
    setState(() => _risk = risk);
  }

  @override
  Widget build(BuildContext context) {
    final risk = _risk;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Kept, not rebuilt: the place in the app survives the warning.
        ExcludeSemantics(
          excluding: risk != null,
          child: AbsorbPointer(absorbing: risk != null, child: widget.child),
        ),
        if (risk != null) DeveloperModeWarning(risk: risk),
      ],
    );
  }
}

/// "Developer options are on": what was found, how to fix it, and the two
/// ways out — Exit, or a call to 911 for someone who opened RepLiT because
/// something is on fire.
class DeveloperModeWarning extends StatelessWidget {
  const DeveloperModeWarning({super.key, required this.risk});

  final DeviceRisk risk;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: t('Developer options are on'),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  key: const ValueKey('developer-mode-warning'),
                  color: pal.surfaceSolid,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: pal.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: IconWell(
                            tint: pal.live,
                            icon: AppIcons.warning,
                            size: 56,
                            glyph: 28,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t('Developer options are on'),
                          textAlign: TextAlign.center,
                          style: context.type.cardTitle,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          risk == DeviceRisk.usbDebugging
                              ? t(
                                  'Our system found settings on this phone '
                                  'that are not secure: Developer options and '
                                  'USB debugging are on.',
                                )
                              : t(
                                  'Our system found settings on this phone '
                                  'that are not secure: Developer options are '
                                  'on.',
                                ),
                          textAlign: TextAlign.center,
                          style: context.type.body.copyWith(
                            color: pal.textSoft,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t(
                            'They let other apps fake your location, and '
                            'every report needs your real one. Turn them off '
                            "in your phone's Settings, then open RepLiT again.",
                          ),
                          textAlign: TextAlign.center,
                          style: context.type.body.copyWith(
                            color: pal.textSoft,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Ref ${risk.ref}',
                          key: const ValueKey('developer-mode-ref'),
                          textAlign: TextAlign.center,
                          style: context.type.meta,
                        ),
                        const SizedBox(height: 22),
                        AppButton(
                          t('Exit'),
                          onPressed: () => unawaited(DeveloperMode.exit()),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => unawaited(
                              launchUrl(Uri(scheme: 'tel', path: '911')),
                            ),
                            icon: Icon(
                              AppIcons.call,
                              size: 18,
                              color: pal.live,
                            ),
                            label: Text(
                              t('In an emergency, call 911'),
                              style: context.type.rowTitle.copyWith(
                                color: pal.live,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
