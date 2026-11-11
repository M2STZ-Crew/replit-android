import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// System, Light or Dark (12 November 2026: "add 'System' to dark/light mode,
/// detecting the phone's mode").
enum ThemePick {
  system('system', 'System'),
  light('light', 'Light'),
  dark('dark', 'Dark');

  const ThemePick(this.wire, this.label);

  /// What is stored on the device.
  final String wire;

  /// What the Theme picker says (through t()).
  final String label;

  static ThemePick? parse(String? value) {
    for (final pick in values) {
      if (pick.wire == value) return pick;
    }
    return null;
  }
}

/// Which of the two grounds the app draws in.
///
/// The person picks in the app: System follows the phone's light or dark,
/// and changes with it; Light and Dark hold whatever the phone does — a
/// responder who keeps their handset light all day may still want the dark
/// ground at three in the morning. It is kept on the device: nothing about
/// which colours someone prefers belongs on a server.
///
/// System is the default since v1.12.34. Someone who chose Light or Dark
/// before then keeps it.
abstract final class ThemeChoice {
  static const String _key = 'theme_pick_v2';

  /// Before v1.12.34: true for light, false for dark, absent if never chosen.
  static const String _oldKey = 'theme_light_v1';

  /// What the person picked.
  static final ValueNotifier<ThemePick> pick = ValueNotifier(ThemePick.system);

  /// True when the light ground is showing — the pick, with System resolved
  /// against the phone. Listened to at the app root, so a change repaints
  /// every screen at once.
  static final ValueNotifier<bool> light = ValueNotifier(false);

  static AppPalette get palette =>
      light.value ? AppPalette.light : AppPalette.dark;

  /// The phone's own setting; tests set it.
  @visibleForTesting
  static Brightness Function() phoneBrightness = () =>
      SchedulerBinding.instance.platformDispatcher.platformBrightness;

  /// Read the saved choice. Called once, before the first frame.
  static Future<void> load() async {
    var chosen = ThemePick.system;
    try {
      final prefs = await SharedPreferences.getInstance();
      chosen =
          ThemePick.parse(prefs.getString(_key)) ??
          switch (prefs.getBool(_oldKey)) {
            true => ThemePick.light,
            false => ThemePick.dark,
            null => ThemePick.system,
          };
    } catch (_) {
      // No stored choice, or no storage: System stands.
    }
    pick.value = chosen;
    _resolve();
  }

  static Future<void> choose(ThemePick value) async {
    pick.value = value;
    _resolve();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.wire);
    } catch (_) {
      // The change still applies to this session.
    }
  }

  /// Kept for the switch the staff screens had: on is Light, off is Dark.
  static Future<void> set(bool lightOn) =>
      choose(lightOn ? ThemePick.light : ThemePick.dark);

  /// The phone went light or dark (the app root hears it): System follows.
  static void phoneChanged() {
    if (pick.value == ThemePick.system) _resolve();
  }

  static void _resolve() {
    final isLight = switch (pick.value) {
      ThemePick.light => true,
      ThemePick.dark => false,
      ThemePick.system => _phoneIsLight(),
    };
    light.value = isLight;
    unawaited(_tellLaunchScreen(isLight));
  }

  static bool _phoneIsLight() {
    try {
      return phoneBrightness() == Brightness.light;
    } catch (_) {
      return false;
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
  static void reset() {
    pick.value = ThemePick.system;
    light.value = false;
    phoneBrightness = () =>
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
  }
}
