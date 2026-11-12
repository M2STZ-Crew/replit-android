import 'package:package_info_plus/package_info_plus.dart';

/// This app's version, "1.12.37": pubspec.yaml's, read from the installed
/// app rather than written here.
///
/// The version alone, everywhere it shows (12 Nov 2026: "remove the build
/// number. it is just the version of app will be remain seen in any
/// platforms, no build number"). CI still stamps a build number on every
/// build (--build-number), but nothing shows it, and "Check for updates"
/// compares versions.
abstract final class AppVersion {
  /// The version as it shows ("1.12.37"). Empty until [load] has run, and
  /// where the platform cannot say (tests).
  static String label = '';

  /// The version, for comparing: what "Check for updates" compares. Empty
  /// until [load].
  static String version = '';

  /// Read once, before the first frame.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      label = info.version;
    } catch (_) {
      // No platform to ask; the version is simply left off.
    }
  }
}
