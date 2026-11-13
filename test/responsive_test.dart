import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';
import 'package:replit/widgets/responsive_frame.dart';

/// The hand-off is drawn at 402 px. On a tablet a screen keeps that column
/// and centres it, rather than stretching a phone layout across the room;
/// since v1.12.43 (13 November 2026: "the responsiveness for tablets";
/// answered: maps full, the rest centred) each page has its own frame, a map
/// or a camera fills the tablet, and a tab's bar runs edge to edge over its
/// column.
void main() {
  Widget page(BuildContext context) => Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(title: 'Your reports'),
        Panel(child: Text('a card', style: context.type.cardTitle)),
        AppButton('Send report', onPressed: () {}),
      ],
    ),
  );

  void sizeTo(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// A reading page, pushed as every page is: the theme's transitions give
  /// it its frame.
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double scale = 1,
  }) async {
    sizeTo(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Builder(builder: page),
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
    // The frame paints the ground across the page, then the column on it.
    expect(
      tester.renderObject(find.byType(ResponsiveFrame).first),
      paints..rect(
        rect: const Rect.fromLTWH(0, 0, 1024, 768),
        color: AppPalette.dark.background,
      ),
    );
  });

  testWidgets('a map or a camera fills the tablet', (tester) async {
    sizeTo(tester, const Size(1280, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const FullBleed(
          child: Scaffold(body: SizedBox.expand(key: ValueKey('map'))),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(widthOf(tester, find.byKey(const ValueKey('map'))), 1280);
  });

  testWidgets('a tab keeps its column under a bar that runs edge to edge', (
    tester,
  ) async {
    sizeTo(tester, const Size(1280, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: FullBleed(
          child: Scaffold(
            bottomNavigationBar: const SizedBox(
              key: ValueKey('bar'),
              height: 64,
            ),
            body: ReadingSafeArea(
              bottom: false,
              child: Builder(
                builder: (context) =>
                    AppButton('Send report', onPressed: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(widthOf(tester, find.byKey(const ValueKey('bar'))), 1280);
    expect(widthOf(tester, find.byType(AppButton)), ResponsiveFrame.maxWidth);
    expect(
      tester.getCenter(find.byType(AppButton)).dx,
      moreOrLessEquals(640, epsilon: 1),
    );
  });

  testWidgets(
    'a screen that stops filling the tablet goes back to its column',
    (tester) async {
      sizeTo(tester, const Size(1280, 800));
      final full = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ValueListenableBuilder<bool>(
            valueListenable: full,
            builder: (context, on, _) {
              const content = Scaffold(
                body: SizedBox.expand(key: ValueKey('content')),
              );
              return on ? const FullBleed(child: content) : content;
            },
          ),
        ),
      );
      await tester.pump();
      expect(widthOf(tester, find.byKey(const ValueKey('content'))), 1280);
      full.value = false;
      await tester.pump();
      expect(
        widthOf(tester, find.byKey(const ValueKey('content'))),
        ResponsiveFrame.maxWidth,
      );
    },
  );
}
