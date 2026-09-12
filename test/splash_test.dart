import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/screens/splash_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

/// "01 Splash": it fills the screen. A Scaffold body is laid out with loose
/// constraints, so a Column of fixed-width children shrinks to its widest one
/// and lands against the left edge — which is how the mark, the wordmark and
/// the loader all ended up in the left third of a real phone.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(402, 874), Size(320, 640), Size(430, 932)]) {
    testWidgets('the mark, wordmark and loader stay centred on $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const SplashScreen()),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final middle = size.width / 2;
      Finder art(String asset) => find.byWidgetPredicate(
        (w) => w is Image && (w.image as AssetImage).assetName == asset,
      );
      final parts = <String, Finder>{
        'the mark': art(Art.mark),
        'the wordmark': art(Art.wordmarkType),
        'the status line': find.text('CONNECTING TO BARANGAY 76'),
        'the locality': find.text('Barangay 76, Pasay City'),
      };
      for (final MapEntry(key: what, value: finder) in parts.entries) {
        expect(finder, findsOneWidget, reason: what);
        expect(
          tester.getCenter(finder).dx,
          moreOrLessEquals(middle, epsilon: 1),
          reason: '$what is off centre',
        );
      }

      expect(tester.takeException(), isNull);
      // Let the 1.4s hand-off to the next screen run, so no timer outlives
      // the test.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    });
  }
}
