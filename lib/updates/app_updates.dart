import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_version.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../widgets/sheet_grip.dart';
import '../i18n/i18n.dart';

/// A newer build of RepLiT, waiting in Firebase App Distribution.
class AvailableRelease {
  const AvailableRelease({
    required this.version,
    required this.build,
    this.notes,
  });

  final String version;
  final int build;
  final String? notes;

  /// "1.12.24 (91)", the way App Distribution and Profile write a build.
  String get label => '$version ($build)';
}

/// What a check found.
sealed class UpdateCheck {
  const UpdateCheck();
}

class UpToDate extends UpdateCheck {
  const UpToDate();
}

class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(this.release);
  final AvailableRelease release;
}

class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed(this.code);

  /// App Distribution's status name ("NETWORK_FAILURE"), or "UNAVAILABLE"
  /// when this build has no Firebase to ask.
  final String code;
}

/// An install that did not go through, with App Distribution's status.
class UpdateInstallFailed implements Exception {
  const UpdateInstallFailed(this.code);
  final String code;
}

/// "Check for updates" (the 5 November issue list, 2.4), Android only.
///
/// Every Android build CI makes goes to Firebase App Distribution, and its
/// testers are RepLiT's users. This asks App Distribution — through its
/// Android SDK, behind the `replit/updates` channel in MainActivity — whether
/// a newer build is waiting for the signed-in tester, and installs it in the
/// app: the APK downloads, and Android's own installer asks to confirm. The
/// first check asks the tester to sign in with the Google account their
/// invitation went to; App Distribution remembers it after that.
///
/// iPhones are sideloaded (docs/ios-sideload.md), and nothing installed that
/// way can update itself, so the row is not drawn there.
abstract final class AppUpdates {
  static const MethodChannel _channel = MethodChannel('replit/updates');

  /// Whether this phone can check: Android.
  static bool get supported =>
      supportedOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @visibleForTesting
  static bool? supportedOverride;

  @visibleForTesting
  static Future<UpdateCheck> Function()? checkOverride;

  @visibleForTesting
  static Future<void> Function(ValueChanged<double?> onProgress)?
  installOverride;

  /// Ask App Distribution for a newer build. Never throws.
  static Future<UpdateCheck> check() async {
    final stand = checkOverride;
    if (stand != null) return stand();
    try {
      final found = await _channel.invokeMapMethod<String, Object?>('check');
      if (found == null) return const UpToDate();
      return UpdateAvailable(
        AvailableRelease(
          version: '${found['version'] ?? ''}',
          build: (found['build'] as num?)?.toInt() ?? 0,
          notes: (found['notes'] as String?)?.trim(),
        ),
      );
    } on PlatformException catch (e) {
      return UpdateCheckFailed(e.code);
    } on MissingPluginException catch (_) {
      return const UpdateCheckFailed('UNAVAILABLE');
    }
  }

  /// Download the build the last [check] found and hand it to Android's
  /// installer. [onProgress] hears the share downloaded, 0 to 1, or null
  /// while the size is not known yet. Throws [UpdateInstallFailed].
  static Future<void> install(ValueChanged<double?> onProgress) async {
    final stand = installOverride;
    if (stand != null) return stand(onProgress);
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return;
      final args = (call.arguments as Map?) ?? const {};
      final total = (args['total'] as num?)?.toDouble() ?? 0;
      final done = (args['downloaded'] as num?)?.toDouble() ?? 0;
      onProgress(total > 0 ? (done / total).clamp(0.0, 1.0) : null);
    });
    try {
      await _channel.invokeMethod<bool>('install');
    } on PlatformException catch (e) {
      throw UpdateInstallFailed(e.code);
    } on MissingPluginException catch (_) {
      throw const UpdateInstallFailed('UNAVAILABLE');
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  /// What a failure means for the person holding the phone.
  static String explain(String code) => switch (code) {
    'AUTHENTICATION_CANCELED' => t(
      'Sign-in was cancelled. Updates come through Firebase App '
      'Distribution: sign in with the Google account your RepLiT '
      'invitation was sent to.',
    ),
    'AUTHENTICATION_FAILURE' => t(
      "Couldn't sign you in to App Distribution. Check your connection and "
      'try again.',
    ),
    'NETWORK_FAILURE' => t('No connection. Check your internet and try again.'),
    'API_DISABLED' => t(
      "Updates aren't switched on for RepLiT yet. Please tell the RepLiT "
      'team.',
    ),
    'UNAVAILABLE' || 'NOT_IMPLEMENTED' => t(
      "This build can't check for updates. Install the newest one from your "
      'App Distribution email.',
    ),
    'INSTALLATION_CANCELED' => t(
      'The install was cancelled. Tap "Download and install" to try again.',
    ),
    'INSTALLATION_FAILURE' || 'DOWNLOAD_FAILURE' => t(
      "The update couldn't be installed. Try again, or install it from your "
      'App Distribution email.',
    ),
    'HOST_ACTIVITY_INTERRUPTED' => t('The update was interrupted. Try again.'),
    'UPDATE_NOT_AVAILABLE' => t('You already have the newest version.'),
    _ => t("Couldn't check for updates. Try again in a little while."),
  };
}

/// Open the "Check for updates" sheet; it checks at once.
Future<void> showUpdateSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.pal.surfaceSolid,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
  ),
  builder: (_) => const SafeArea(child: UpdateSheet()),
);

/// The sheet: checking, then up to date, a newer build to install, or why
/// it could not tell.
class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

enum _Stage { checking, upToDate, available, installing, installed, failed }

class _UpdateSheetState extends State<UpdateSheet> {
  _Stage _stage = _Stage.checking;
  AvailableRelease? _release;
  String? _problem;
  double? _progress;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.checking;
      _problem = null;
    });
    final found = await AppUpdates.check();
    if (!mounted) return;
    setState(() {
      switch (found) {
        case UpToDate():
          _stage = _Stage.upToDate;
        case UpdateAvailable(:final release):
          _release = release;
          _stage = _Stage.available;
        case UpdateCheckFailed(:final code):
          _problem = AppUpdates.explain(code);
          _stage = _Stage.failed;
      }
    });
  }

  Future<void> _install() async {
    setState(() {
      _stage = _Stage.installing;
      _progress = null;
    });
    try {
      await AppUpdates.install((p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) setState(() => _stage = _Stage.installed);
    } on UpdateInstallFailed catch (e) {
      if (!mounted) return;
      setState(() {
        _problem = AppUpdates.explain(e.code);
        _stage = _Stage.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final installed = AppVersion.label;
    return FrozenHandleSheet(
      children: [
        Text(t('CHECK FOR UPDATES'), style: context.type.title),
        if (installed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            t('Installed: version {v}', {'v': installed}),
            style: context.type.caption.copyWith(color: pal.label),
          ),
        ],
        const SizedBox(height: 18),
        ...switch (_stage) {
          _Stage.checking => [
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
            Text(t('Looking for a newer version…'), style: context.type.body),
          ],
          _Stage.upToDate => [
            _Status(
              icon: AppIcons.checkCircle,
              tint: pal.ok,
              text: t('You have the latest version.'),
            ),
          ],
          _Stage.available => [
            _Status(
              icon: AppIcons.download,
              tint: pal.accent,
              text: t('Version {v} is ready.', {'v': _release!.label}),
            ),
            if ((_release!.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _release!.notes!,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodySm.copyWith(color: pal.textSoft),
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              t('Download and install'),
              icon: AppIcons.download,
              onPressed: _install,
            ),
          ],
          _Stage.installing => [
            LinearProgressIndicator(value: _progress, minHeight: 3),
            const SizedBox(height: 12),
            Text(
              _progress == null
                  ? 'Downloading…'
                  : t('Downloading… {n}%', {'n': (_progress! * 100).round()}),
              style: context.type.body,
            ),
            const SizedBox(height: 6),
            Text(
              t('Android will ask you to confirm the install.'),
              style: context.type.caption.copyWith(color: pal.label),
            ),
          ],
          _Stage.installed => [
            _Status(
              icon: AppIcons.checkCircle,
              tint: pal.ok,
              text: t(
                'Downloaded. Finish the install in the window Android '
                'opened.',
              ),
            ),
          ],
          _Stage.failed => [
            _Status(
              icon: AppIcons.error,
              tint: pal.live,
              text: _problem ?? AppUpdates.explain(''),
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              t('Try again'),
              icon: AppIcons.refresh,
              onPressed: _release != null ? _install : _check,
            ),
          ],
        },
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.tint, required this.text});

  final IconData icon;
  final Color tint;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: tint),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: context.type.body)),
      ],
    );
  }
}
