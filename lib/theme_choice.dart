import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Which of the two grounds the app draws in.
///
/// The choice is the resident's, made in the app, not inherited from the
/// phone: a responder who keeps their handset light all day may still want the
/// dark ground at three in the morning, and the reverse. It is kept on the
/// device — nothing about which colours someone prefers belongs on a server.
///
/// Dark is the default. It is the ground the design was drawn on, and the one
/// that costs least on a screen at night.
abstract final class ThemeChoice {
  static const String _key = 'theme_light_v1';

  /// True when the light ground is showing. Listened to at the app root, so a
  /// change repaints every screen at once.
  static final ValueNotifier<bool> light = ValueNotifier(false);

  static AppPalette get palette =>
      light.value ? AppPalette.light : AppPalette.dark;

  /// Read the saved choice. Called once, before the first frame.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      light.value = prefs.getBool(_key) ?? false;
    } catch (_) {
      // No stored choice, or no storage: the dark ground stands.
    }
    unawaited(_tellLaunchScreen(light.value));
  }

  static Future<void> set(bool value) async {
    light.value = value;
    unawaited(_tellLaunchScreen(value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {
      // The change still applies to this session.
    }
  }

  static const MethodChannel _device = MethodChannel('replit/device');

  /// Android draws its launch screen before the app runs, in the phone's
  /// light or dark rather than this choice. Android 13+ can keep the app's
  /// own: tell it, so the next launch screen has the app's ground
  /// (MainActivity, "launchGround"). iPhones and older Androids follow the
  /// phone.
  static Future<void> _tellLaunchScreen(bool light) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _device.invokeMethod<bool>('launchGround', {'light': light});
    } catch (_) {
      // An older build of the Android side, or a test: the phone's ground.
    }
  }

  /// For tests: forget the choice without touching storage.
  @visibleForTesting
  static void reset() => light.value = false;
}
