import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_updates.dart';

/// "There's a new update!" (WHAT'S NEXT, 1.1), on the home screens.
///
/// The app looks for a newer release every time it opens, and again whenever
/// it comes back to the front, at most every [every]: the newest release is a
/// small file on GitHub's releases, not its rate-limited API. One it finds
/// waits in [waiting], and the home screens draw it as a banner that stays
/// (UpdateBanner): the resident's map, the coordinator's Queue, the
/// responder's Duty. Closing it keeps it away until a release newer than that
/// one; installing it makes the next look find nothing.
///
/// Until v1.12.31 it looked at most every six hours, counting a look that
/// found nothing, and said so in a pop-up for ten seconds: a release out an
/// hour after a look went unseen for hours, and a pop-up shown as the home
/// screen was drawn was easy to miss. And an iPhone never looked. Now one is
/// told a newer version is out, to install with Sideloadly as before, since
/// nothing sideloaded can update itself (only Android installs:
/// [AppUpdates.supported]).
abstract final class UpdateNudge {
  /// Coming back to the front looks again only this long after the last look.
  static const Duration every = Duration(minutes: 15);

  /// The release closed with ×: Android's build number, an iPhone's version
  /// (an iPhone's builds count apart from Android's).
  static const String _closedKey = 'update_closed_build_v1';
  static const String _closedVersionKey = 'update_closed_version_v1';

  /// The newer release the home screens' banner shows, or null.
  static final ValueNotifier<AvailableRelease?> waiting = ValueNotifier(null);

  static DateTime? _lookedAt;
  static bool _looking = false;

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Look as the app opens, however recent the last look was.
  static Future<void> start() => _look();

  /// Look on coming back to the front, unless one looked in the last [every].
  static Future<void> maybeCheck() async {
    final last = _lookedAt;
    if (last != null && now().difference(last) < every) return;
    await _look();
  }

  static Future<void> _look() async {
    if (!AppUpdates.canTell || _looking) return;
    _looking = true;
    try {
      final found = await AppUpdates.check();
      // No answer (offline, GitHub down): what is shown stays, and the next
      // look tries again.
      if (found is UpdateCheckFailed) return;
      _lookedAt = now();
      final release = found is UpdateAvailable ? found.release : null;
      waiting.value = release == null || await _closedFor(release)
          ? null
          : release;
    } finally {
      _looking = false;
    }
  }

  static Future<bool> _closedFor(AvailableRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    if (AppUpdates.supported) {
      final closed = prefs.getInt(_closedKey);
      return closed != null && release.build <= closed;
    }
    final closed = prefs.getString(_closedVersionKey);
    return closed != null && !isNewerVersion(release.version, than: closed);
  }

  /// The banner's ×: not again until a release newer than this one.
  static Future<void> close() async {
    final release = waiting.value;
    if (release == null) return;
    waiting.value = null;
    final prefs = await SharedPreferences.getInstance();
    if (AppUpdates.supported) {
      await prefs.setInt(_closedKey, release.build);
    } else {
      await prefs.setString(_closedVersionKey, release.version);
    }
  }

  /// For tests: forget what was looked at and found.
  @visibleForTesting
  static void reset() {
    waiting.value = null;
    _lookedAt = null;
    _looking = false;
    now = DateTime.now;
  }
}
