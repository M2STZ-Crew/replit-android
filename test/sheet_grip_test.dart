import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/sheet_grip.dart';

/// The grab handle at the top of a drawer stays put while the drawer's rows
/// scroll (the 5 November issue list, 1.9). It used to be the first row of
/// the list, and scrolled away with it.
void main() {
  group('a draggable sheet', () {
    late DraggableScrollableController sheet;

    Future<void> pump(WidgetTester tester) async {
      sheet = DraggableScrollableController();
      addTearDown(sheet.dispose);
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: DraggableScrollableSheet(
              controller: sheet,
              initialChildSize: 0.5,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder: (context, scroll) => Column(
                children: [
                  SheetGrip(sheet: sheet, minSize: 0.2, maxSize: 0.9),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: 60,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 48, child: Text('Row $i')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the handle stays at the top while the rows scroll', (
      tester,
    ) async {
      await pump(tester);
      // Open it all the way, so a drag on the list scrolls the list.
      sheet.jumpTo(0.9);
      await tester.pump();
      final handle = find.byKey(SheetGrip.handleKey);
      final before = tester.getTopLeft(handle);

      await tester.drag(find.text('Row 3'), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Row 3'), findsNothing, reason: 'the rows scrolled');
      expect(tester.getTopLeft(handle), before, reason: 'the handle did not');
    });

    testWidgets('dragging the handle still moves the sheet', (tester) async {
      await pump(tester);
      expect(sheet.size, moreOrLessEquals(0.5));

      await tester.drag(find.byKey(SheetGrip.handleKey), const Offset(0, -100));
      await tester.pump();
      expect(sheet.size, greaterThan(0.5));

      // A flick down sends it to its folded end.
      await tester.fling(
        find.byKey(SheetGrip.handleKey),
        const Offset(0, 200),
        2000,
      );
      await tester.pumpAndSettle();
      expect(sheet.size, moreOrLessEquals(0.2));
    });
  });

  testWidgets('a modal sheet\'s handle stays put over a long body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: FrozenHandleSheet(
                children: [for (var i = 0; i < 40; i++) Text('Line $i')],
              ),
            ),
          ),
        ),
      ),
    );
    final handle = find.byKey(SheetGrip.handleKey);
    final before = tester.getTopLeft(handle);
    final lineBefore = tester.getTopLeft(find.text('Line 2')).dy;
    await tester.drag(find.text('Line 2'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Line 2')).dy,
      lessThan(lineBefore - 200),
      reason: 'the body scrolled',
    );
    expect(tester.getTopLeft(handle), before, reason: 'the handle did not');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short modal sheet hugs its content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FrozenHandleSheet(children: const [Text('Only line')]),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FrozenHandleSheet)).height,
      lessThan(120),
    );
  });
}
