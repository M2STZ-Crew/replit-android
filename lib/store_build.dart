import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/api_config.dart';

/// Which copy of RepLiT this is (v1.12.44): one from Google Play, or one from
/// the APK page.
///
/// Google Play updates the apps it installs and does not allow an app to
/// install itself, so a Play copy has no updater of its own: "Check for
/// updates" and "New Update!" open its Play Store page, the update banner never
/// looks at GitHub, and it registers with the server as "1.12.44 play", which
/// the server never tells of a GitHub release. Developer options warn rather
/// than lock it (Google's test phones have them on).
///
/// Built with `--flavor play --dart-define=PLAY_STORE=true`
/// (.github/workflows/android-release.yml); the `play` flavor's manifest also
/// leaves out the permission to install apps (android/app/src/play).
abstract final class StoreBuild {
  static const bool _play = bool.fromEnvironment('PLAY_STORE');

  /// For tests: which copy to be, whatever the build.
  @visibleForTesting
  static bool? playOverride;

  /// Whether this is the Google Play copy.
  static bool get play => playOverride ?? _play;

  static const String packageId = 'com.m2stz.replit';

  static final Uri playListing = Uri.parse(
    'https://play.google.com/store/apps/details?id=$packageId',
  );
  static final Uri _market = Uri.parse('market://details?id=$packageId');

  /// RepLiT's page in the Play Store app, or on the web without it.
  static Future<void> openPlayListing() async {
    try {
      if (await launchUrl(_market, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // No Play Store on this phone: the web page instead.
    }
    await launchUrl(playListing, mode: LaunchMode.externalApplication);
  }

  /// The version the server is told ("1.12.44", or "1.12.44 play"), or null
  /// when it is not known yet.
  static String? deviceVersion(String version) {
    if (version.isEmpty) return null;
    return play ? '$version play' : version;
  }
}

/// RepLiT's public pages (Google Play): the privacy policy, and deleting or
/// restoring an account without the app. On the residents' site since
/// v1.12.45, not the Admin console's address.
abstract final class PolicyLinks {
  static Uri get privacy => Uri.parse('${ApiConfig.publicSiteUrl}/privacy');

  /// The Terms (v1.12.63).
  static Uri get terms => Uri.parse('${ApiConfig.publicSiteUrl}/terms');

  static Uri get deleteAccount =>
      Uri.parse('${ApiConfig.publicSiteUrl}/delete-account');

  /// Open the Terms in the browser.
  static Future<void> openTerms() async {
    try {
      await launchUrl(terms, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser: nothing else to open it in.
    }
  }

  /// Open the privacy policy in the browser.
  static Future<void> openPrivacy() async {
    try {
      await launchUrl(privacy, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser: nothing else to open it in.
    }
  }
}
