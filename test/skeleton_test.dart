import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/skeleton.dart';

/// Loading screens show the shape of what is coming, not a spinner (the 5
/// November issue list, 1.6).
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

  testWidgets('a list loads as rows, read out once as "Loading"', (
    tester,
  ) async {
    await pump(tester, const SkeletonList(rows: 4, trailing: true));
    expect(tester.takeException(), isNull);
    expect(find.byType(SkeletonRow), findsNWidgets(4));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The sweep is drawn over the whole list at once.
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('under reduced motion nothing sweeps', (tester) async {
    await pump(tester, const SkeletonList(rows: 2), reduced: true);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SkeletonRow), findsNWidgets(2));
  });

  for (final pal in const [AppPalette.dark, AppPalette.light]) {
    testWidgets('a detail screen fits a small phone at large text '
        '(${pal.isLight ? 'light' : 'dark'})', (tester) async {
      await pump(tester, const SkeletonDetail(media: true), pal: pal);
      expect(tester.takeException(), isNull);
      final block = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SkeletonBox).first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (block.decoration! as BoxDecoration).color,
        SkeletonTone.of(tester.element(find.byType(SkeletonDetail))).base,
      );
    });
  }

  testWidgets('rows inside a list that is already there', (tester) async {
    await pump(
      tester,
      ListView(children: const [Text('Responders'), SkeletonRows(rows: 3)]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SkeletonRow), findsNWidgets(3));
  });

  testWidgets('a viewfinder or map fills its space', (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 200,
        height: 150,
        child: SkeletonFill(label: 'Starting the camera'),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('skeleton-fill'))),
      const Size(200, 150),
    );
    expect(find.bySemanticsLabel('Starting the camera'), findsOneWidget);
  });
}
