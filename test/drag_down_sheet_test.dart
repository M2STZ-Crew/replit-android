import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/widgets/drag_down_sheet.dart';

/// Let the sheet's fold or unfold run: the first frame only starts the clock.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The sheet over the map folds down to its title and opens back up.
void main() {
  Future<List<String>> pump(WidgetTester tester) async {
    final taps = <String>[];
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DragDownSheet(
                  frame: (context, content) => Container(
                    color: Colors.black,
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
                    child: content,
                  ),
                  header: const SizedBox(height: 40, child: Text('TITLE')),
                  body: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final r in ['Row 1', 'Row 2', 'Row 3'])
                        SizedBox(
                          height: 56,
                          child: InkWell(
                            onTap: () => taps.add(r),
                            child: Text(r),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('a drag folds it to the title; a tap on the title opens it', (
    tester,
  ) async {
    final taps = await pump(tester);
    final title = find.text('TITLE');
    final open = tester.getTopLeft(title).dy;

    await tester.drag(find.text('Row 2'), const Offset(0, 300));
    await settle(tester);
    expect(tester.getTopLeft(title).dy, open + 3 * 56);
    expect(find.text('Row 1').hitTestable(), findsNothing);
    expect(taps, isEmpty, reason: 'a drag is not a tap');

    await tester.tap(title);
    await settle(tester);
    expect(tester.getTopLeft(title).dy, open);

    await tester.tap(find.text('Row 1'));
    expect(taps, ['Row 1'], reason: 'a tap on a row still lands');
  });

  testWidgets('a short drag springs back; a drag up opens it', (tester) async {
    await pump(tester);
    final title = find.text('TITLE');
    final open = tester.getTopLeft(title).dy;

    final gesture = await tester.startGesture(tester.getCenter(title));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await settle(tester);
    expect(tester.getTopLeft(title).dy, open, reason: 'not far enough');

    await tester.drag(title, const Offset(0, 300));
    await settle(tester);
    await tester.drag(title, const Offset(0, -300));
    await settle(tester);
    expect(tester.getTopLeft(title).dy, open);
  });
}
