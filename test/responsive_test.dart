import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';
import 'package:replit/widgets/responsive_frame.dart';

/// The hand-off is drawn at 402 px. On a tablet the app keeps that column and
/// centres it, rather than stretching a phone layout across the room.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) =>
            ResponsiveFrame(child: child ?? const SizedBox.shrink()),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenHeader(title: 'Your reports'),
                  Panel(child: Text('a card', style: context.type.cardTitle)),
                  AppButton('Send report', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double widthOf(WidgetTester tester, Finder finder) =>
      tester.getSize(finder).width;

  group('phones are left exactly as drawn', () {
    for (final size in const [
      Size(360, 800), // a small Android phone
      Size(402, 874), // the design's own frame
      Size(430, 932), // the largest iPhone
    ]) {
      testWidgets('$size', (tester) async {
        await pumpAt(tester, size);
        expect(tester.takeException(), isNull);
        expect(
          widthOf(tester, find.byType(AppButton)),
          size.width,
          reason: 'the frame should be a pass-through here',
        );
      });
    }
  });

  group('tablets keep the column and centre it', () {
    for (final size in const [
      Size(768, 1024), // iPad portrait
      Size(1024, 768), // iPad landscape
      Size(1280, 800), // a big Android tablet
      Size(1366, 1024), // iPad Pro landscape
    ]) {
      testWidgets('$size', (tester) async {
        await pumpAt(tester, size);
        expect(tester.takeException(), isNull);

        final button = find.byType(AppButton);
        expect(widthOf(tester, button), ResponsiveFrame.maxWidth);

        // Centred, not pinned to a side.
        final centre = tester.getCenter(button).dx;
        expect(centre, moreOrLessEquals(size.width / 2, epsilon: 1));
      });
    }
  });

  testWidgets('a tablet at 1.5x text still holds its column', (tester) async {
    await pumpAt(tester, const Size(1024, 1366), scale: 1.5);
    expect(tester.takeException(), isNull);
    expect(widthOf(tester, find.byType(AppButton)), ResponsiveFrame.maxWidth);
  });

  testWidgets('the ground fills the space beside the column', (tester) async {
    await pumpAt(tester, const Size(1024, 768));
    final fill = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(ResponsiveFrame),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(fill.color, AppPalette.dark.background);
  });
}
