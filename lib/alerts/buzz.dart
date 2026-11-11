import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Every alert vibrates, on Android and on iPhones (12 November 2026:
/// "vibration when notifying, both Android and iOS (every stage and every
/// notif)").
///
/// With the app closed the notification channel does it (MainActivity.kt;
/// since v1.12.35 every channel vibrates). With the app open this does: on
/// Android, the phone's own vibrator through MainActivity ("vibrate", the
/// alert channels' pattern); on an iPhone, the system vibration twice — iOS
/// gives apps no patterns. Either way it follows the phone's own settings.
abstract final class Buzz {
  static const MethodChannel _device = MethodChannel('replit/device');

  /// The alert channels' rhythm: on 0.6 s, off 0.25 s, three times.
  static const List<int> pattern = [0, 600, 250, 600, 250, 600];

  /// For tests: what was asked of the vibrator.
  @visibleForTesting
  static int buzzes = 0;

  static Future<void> alert() async {
    if (kIsWeb) return;
    buzzes++;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final done = await _device.invokeMethod<bool>('vibrate', {
          'pattern': pattern,
        });
        if (done == true) return;
      } catch (_) {
        // An older Android side, or no vibrator: the haptic below.
      }
      await HapticFeedback.vibrate();
      return;
    }
    // iPhone: kSystemSoundID_Vibrate, twice.
    await HapticFeedback.vibrate();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await HapticFeedback.vibrate();
  }
}
