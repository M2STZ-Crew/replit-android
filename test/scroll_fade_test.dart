import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/scroll_fade.dart';

/// The Scroll fade follows the real scroll position (REPLIT (MAIN) 09 ·
/// pass 3): Figma could only draw the at-top state, so the states it lists
/// are checked here against a live list.
void main() {
  late ScrollController controller;
  var taps = 0;

  Future<void> pumpList(WidgetTester tester, {required int rows}) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = ScrollController();
    addTearDown(controller.dispose);
    taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ScrollFade(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.only(bottom: kScrollFadeEndPadding),
              children: [
                for (var i = 0; i < rows; i++)
                  SizedBox(
                    height: 100,
                    child: TextButton(
                      onPressed: () => taps++,
                      child: Text('row $i'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double opacity(WidgetTester tester, String edge) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(ValueKey('scroll-fade-$edge')),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('content that fits shows no fade at all', (tester) async {
    await pumpList(tester, rows: 3);
    expect(opacity(tester, 'top'), 0);
    expect(opacity(tester, 'bottom'), 0);
  });

  testWidgets('at the top only the bottom edge fades', (tester) async {
    await pumpList(tester, rows: 30);
    expect(opacity(tester, 'top'), 0);
    expect(opacity(tester, 'bottom'), 1);
  });

  testWidgets('in the middle both edges fade', (tester) async {
    await pumpList(tester, rows: 30);
    controller.jumpTo(800);
    await tester.pumpAndSettle();
    expect(opacity(tester, 'top'), 1);
    expect(opacity(tester, 'bottom'), 1);
  });

  testWidgets(
    'at the end only the top edge fades, and the last row clears it',
    (tester) async {
      await pumpList(tester, rows: 30);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(opacity(tester, 'top'), 1);
      expect(opacity(tester, 'bottom'), 0);
      // The end padding lifts the last row clear of where the fade would be.
      final lastRow = tester.getRect(find.text('row 29'));
      expect(lastRow.bottom, lessThanOrEqualTo(874 - kScrollFadeEndPadding));
    },
  );

  testWidgets('a fade never takes a tap from the row under it', (tester) async {
    await pumpList(tester, rows: 30);
    // A point inside the bottom fade's 40 px band.
    await tester.tapAt(const Offset(201, 874 - 20));
    expect(taps, 1);
  });

  testWidgets('a fade is not read out by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpList(tester, rows: 30);
    final fade = find.byKey(const ValueKey('scroll-fade-bottom'));
    expect(
      find.descendant(of: fade, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('under reduced motion a fade appears at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpList(tester, rows: 30);
    final fade = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(const ValueKey('scroll-fade-bottom')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(fade.duration, Duration.zero);
  });
}
