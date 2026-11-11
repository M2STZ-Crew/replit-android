import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/loading.dart';

/// Every loading state is the splash's loader (12 November 2026: "remove the
/// skeleton loading totally, just make it look our default loading screen in
/// the splash as the default loading for every loading").
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reduced = false,
    AppPalette pal = AppPalette.dark,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(pal),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            disableAnimations: reduced,
            textScaler: const TextScaler.linear(1.5),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a screen loads as the splash does: the mark, the loader, '
      '"Loading"', (tester) async {
    await pump(tester, const LoadingView());

    expect(find.byKey(const ValueKey('loader-bar')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    // The 106 × 3 track, in the middle of the screen.
    expect(
      tester.getSize(find.byKey(const ValueKey('loader-bar'))),
      const Size(106, 3),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('loader-bar'))).dx,
      moreOrLessEquals(160, epsilon: 0.5),
    );
  });

  testWidgets('the loader runs, and holds still under reduced motion', (
    tester,
  ) async {
    Offset segment() => tester.getTopLeft(
      find
          .descendant(
            of: find.byKey(const ValueKey('loader-bar')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );

    await pump(tester, const LoadingView());
    final before = segment();
    await tester.pump(const Duration(milliseconds: 400));
    expect(segment(), isNot(before));

    await pump(tester, const LoadingView(), reduced: true);
    final still = segment();
    await tester.pump(const Duration(milliseconds: 400));
    expect(segment(), still);
  });

  testWidgets('a list that is loading can still be pulled to refresh', (
    tester,
  ) async {
    var refreshed = 0;
    await pump(
      tester,
      RefreshIndicator(
        onRefresh: () async => refreshed++,
        child: const LoadingView(),
      ),
    );
    await tester.fling(
      find.byKey(const ValueKey('loading-view')),
      const Offset(0, 400),
      1000,
    );
    // The loader runs for ever: pump through the refresh rather than settle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(refreshed, 1);
  });

  testWidgets('part of a screen loads as the loader alone, with what it is', (
    tester,
  ) async {
    await pump(
      tester,
      ListView(
        children: const [
          Text('Responders'),
          LoadingInline(label: 'Loading responders'),
        ],
      ),
    );

    expect(find.byKey(const ValueKey('loader-bar')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Loading responders'), findsOneWidget);
  });

  testWidgets('a map or camera space shows the loader in its middle', (
    tester,
  ) async {
    await pump(
      tester,
      const SizedBox(
        width: 300,
        height: 200,
        child: LoadingView(
          label: 'Starting the camera',
          mark: false,
          scrollable: false,
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('loading-view'))),
      const Size(300, 200),
    );
    expect(find.text('Starting the camera'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the loader takes the accent on the light ground too', (
    tester,
  ) async {
    await pump(tester, const LoadingView(), pal: AppPalette.light);
    final segment = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey('loader-bar')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (segment.decoration as BoxDecoration).color,
      AppPalette.light.accent,
    );
  });
}
