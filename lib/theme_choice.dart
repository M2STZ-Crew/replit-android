import 'package:flutter/material.dart';
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
  }

  static Future<void> set(bool value) async {
    light.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {
      // The change still applies to this session.
    }
  }

  /// For tests: forget the choice without touching storage.
  @visibleForTesting
  static void reset() => light.value = false;
}
