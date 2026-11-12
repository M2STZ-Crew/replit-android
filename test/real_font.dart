import 'dart:io';

import 'package:flutter/services.dart';

import 'package:replit/theme.dart';

/// Loads Inter, the app's own typeface (assets/fonts, [kAppFont]), for a
/// test that measures whether a page fits a phone: the test font draws every
/// letter as a square, so it wraps far more than a phone does. Tests run
/// from the repository root, where the font files are.
Future<void> loadAppFont() async {
  final loader = FontLoader(kAppFont);
  for (final weight in [
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ]) {
    final bytes = File('assets/fonts/Inter-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
