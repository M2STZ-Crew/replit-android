import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/dev/preview_main.dart';
import 'package:replit/models/field_ops.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/field_ops.dart';

/// The pass 6 field-operations parts that are UI READY (no server behind them
/// yet): what they offer, and that the development preview draws them.
void main() {
  test('Structural offers no Agricultural (PRD v14 §4.5.3)', () {
    expect(FireType.structural.subtypes, [
      'Residential',
      'Commercial',
      'Industrial',
    ]);
    for (final t in FireType.values) {
      expect(t.subtypes, isNot(contains('Agricultural')), reason: t.label);
    }
  });

  test('an older report that says Agricultural still reads', () {
    const old = FireClassification(FireType.structural, 'Agricultural');
    expect(old.subtype, 'Agricultural');
  });

  testWidgets('the fire-type sheet lists Structural without Agricultural', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: FireTypeSheet(areaLabel: 'Example Area 1.2'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Structural'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Structural — which kind?'), findsOneWidget);
    for (final kind in ['Residential', 'Commercial', 'Industrial']) {
      expect(find.text(kind), findsOneWidget);
    }
    expect(find.text('Agricultural'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the development preview draws every part', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FieldOpsPreview());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('FIELD OPERATIONS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
