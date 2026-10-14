import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/unit_groups.dart';
import 'package:replit/widgets/app_icons.dart';

/// Which trucks share a marker (v1.12.7): those that would overlap on screen.
void main() {
  test('trucks far apart keep a marker each', () {
    expect(
      groupOnScreen(const [Offset(0, 0), Offset(100, 0), Offset(0, 100)]),
      [
        [0],
        [1],
        [2],
      ],
    );
  });

  test('trucks that would overlap share one', () {
    expect(
      groupOnScreen(const [Offset(0, 0), Offset(20, 10), Offset(10, -15)]),
      [
        [0, 1, 2],
      ],
    );
  });

  test('a long convoy splits rather than one marker far from its trucks', () {
    // Five trucks 30 px apart along a road: 120 px end to end.
    final convoy = [for (var i = 0; i < 5; i++) Offset(i * 30.0, 0)];
    final groups = groupOnScreen(convoy);
    expect(groups.length, greaterThan(1));
    expect(groups.expand((g) => g).toList()..sort(), [0, 1, 2, 3, 4]);
  });

  test('a truck joins the nearest group it reaches', () {
    // 0 and 2 are 80 px apart; 1 sits nearer to 2.
    expect(groupOnScreen(const [Offset(0, 0), Offset(50, 0), Offset(80, 0)]), [
      [0],
      [1, 2],
    ]);
  });

  test('nothing to group, nothing grouped', () {
    expect(groupOnScreen(const []), isEmpty);
  });

  test('the count stops at 9+', () {
    expect(groupCount(2), '2');
    expect(groupCount(9), '9');
    expect(groupCount(12), '9+');
  });

  testWidgets('the merged marker: the count at the top right, tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Center(
          child: UnitGroupMarker(
            count: 2,
            colour: Colors.red,
            behind: Colors.orange,
            label: '2 trucks: Apollo, Hermes',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(AppIcons.fireTruck), findsOneWidget);
    expect(find.bySemanticsLabel('2 trucks: Apollo, Hermes'), findsOneWidget);

    final marker = tester.getRect(find.byType(UnitGroupMarker));
    final badge = tester.getRect(
      find.byKey(const ValueKey('unit-group-count')),
    );
    expect(badge.center.dx, greaterThan(marker.center.dx));
    expect(badge.center.dy, lessThan(marker.center.dy));

    await tester.tap(find.byType(UnitGroupMarker));
    expect(taps, 1);
  });
}
