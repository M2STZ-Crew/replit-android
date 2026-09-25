import 'package:package_info_plus/package_info_plus.dart';

/// This build's version, written the way Firebase App Distribution lists a
/// release: "1.11.0 (57)" — the version name, then the build number.
///
/// Both halves are read from the installed app rather than written here. The
/// name is pubspec.yaml's; the build number is the GitHub run number CI stamps
/// on every release build (--build-number), and it is what App Distribution
/// shows. So the version on the profile screen is the release the tester
/// installed — one number to quote when something goes wrong.
abstract final class AppVersion {
  /// Empty until [load] has run, and where the platform cannot say (tests).
  static String label = '';

  /// Read once, before the first frame.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      label = info.buildNumber.isEmpty
          ? info.version
          : '${info.version} (${info.buildNumber})';
    } catch (_) {
      // No platform to ask; the version is simply left off.
    }
  }
}
