import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/screens/splash_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/app_logo.dart';
import 'package:replit/widgets/design.dart';

/// The logos are drawn white for the dark ground. On the light ground the
/// splash showed that white wordmark on a pale screen — the "dark mode logo in
/// light mode" of the 5 November issue list. Each logo now follows the ground.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Image imageOf(WidgetTester tester, String asset) => tester.widget<Image>(
    find.byWidgetPredicate(
      (w) => w is Image && (w.image as AssetImage).assetName == asset,
    ),
  );

  for (final pal in const [AppPalette.dark, AppPalette.light]) {
    final ground = pal.isLight ? 'light' : 'dark';

    testWidgets('the splash wordmark is drawn in the $ground ground\'s ink', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(pal), home: const SplashScreen()),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final wordmark = imageOf(tester, Art.wordmarkType);
      expect(wordmark.color, pal.onBackground);
      // srcIn keeps the letters' shape (and the flame cut out of the R) and
      // replaces only their colour.
      expect(wordmark.colorBlendMode ?? BlendMode.srcIn, BlendMode.srcIn);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('the top-bar logo has a $ground-ground variant', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(pal),
          home: const Scaffold(body: AppLogo()),
        ),
      );
      final asset = pal.isLight ? AppLogo.light : AppLogo.dark;
      expect(imageOf(tester, asset), isNotNull);
      expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
    });
  }
}
