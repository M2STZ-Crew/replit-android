import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/push_service.dart';
import '../i18n/i18n.dart';
import '../theme.dart';
import 'app_updates.dart';

/// "There's a new update!" (WHAT'S NEXT, 1.1). On Android the app looks for a
/// newer release by itself — once it is past the splash, and when it comes
/// back to the front, at most every [every] — and says so in a banner like an
/// alert's. UPDATE opens Check for updates; closing the banner keeps it away
/// until a release newer than that one. A banner left to time out comes back
/// at the next look. iPhones are sideloaded and cannot update themselves, so
/// nothing happens there ([AppUpdates.supported]).
abstract final class UpdateNudge {
  /// The longest a look waits for the last one.
  static const Duration every = Duration(hours: 6);

  /// How long the banner stays without a tap, as an alert's does.
  static const Duration showFor = Duration(seconds: 10);

  static const String _lookedKey = 'update_looked_at_v1';
  static const String _closedKey = 'update_closed_build_v1';

  /// While the splash is up, looks wait: the banner belongs on the screen
  /// after it. The splash lets go as it hands over, and looks then.
  static bool hold = false;

  static bool _looking = false;

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Look for a newer release, unless one looked in the last [every], and
  /// show the banner for one this phone has not closed it for.
  static Future<void> maybeCheck() async {
    if (!AppUpdates.supported || hold || _looking) return;
    _looking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lookedKey);
      final at = now();
      if (last != null &&
          at.difference(DateTime.fromMillisecondsSinceEpoch(last)) < every) {
        return;
      }
      final found = await AppUpdates.check();
      // No answer (offline, GitHub down): look again next time instead.
      if (found is UpdateCheckFailed) return;
      await prefs.setInt(_lookedKey, at.millisecondsSinceEpoch);
      if (found is! UpdateAvailable || hold) return;
      final closed = prefs.getInt(_closedKey);
      if (closed != null && found.release.build <= closed) return;
      _show(found.release, prefs);
    } finally {
      _looking = false;
    }
  }

  static void _show(AvailableRelease release, SharedPreferences prefs) {
    final messenger = PushService.messengerKey.currentState;
    if (messenger == null) return;
    final shown = messenger.showSnackBar(
      banner(
        release,
        onUpdate: () {
          final navigator = PushService.navigatorKey.currentState;
          final context = navigator?.overlay?.context ?? navigator?.context;
          if (context != null) unawaited(showUpdateSheet(context));
        },
      ),
    );
    unawaited(
      shown.closed.then((reason) async {
        // Closed by hand: not again until a newer release.
        if (reason == SnackBarClosedReason.dismiss ||
            reason == SnackBarClosedReason.swipe) {
          await prefs.setInt(_closedKey, release.build);
        }
      }),
    );
  }

  /// The banner, in the in-app alerts' manner: a title, a line, UPDATE, and
  /// a close button.
  @visibleForTesting
  static SnackBar banner(
    AvailableRelease release, {
    required VoidCallback onUpdate,
  }) {
    return SnackBar(
      backgroundColor: AppColors.gradientEnd,
      duration: showFor,
      persist: false,
      showCloseIcon: true,
      closeIconColor: Colors.white,
      action: SnackBarAction(
        label: t('UPDATE'),
        textColor: Colors.white,
        onPressed: onUpdate,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t("There's a new update!"),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            t('RepLiT {version} is ready to install.', {
              'version': release.version,
            }),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// For tests: forget what was looked at and closed.
  @visibleForTesting
  static void reset() {
    hold = false;
    _looking = false;
    now = DateTime.now;
  }
}
