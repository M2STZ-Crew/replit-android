import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/models/area_view.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/alarm_ask_sheet.dart';
import 'package:replit/widgets/coordinator_kit.dart';
import 'package:replit/widgets/you_are_here.dart';

/// v1.12.62 (23 November 2026): "it centers the whole screen but the drawer
/// blocks it" (answered "Visible center"), and "before to proceed with
/// positive fire alarm, someone should fill the fire type first".
void main() {
  group('the map centres in what the drawer leaves in view', () {
    test('the middle of what shows, or low in it while navigating', () {
      const map = Size(360, 800);
      final still = YouAreHereLayer.focalFor(navigating: false, covered: 400);
      // From the map's centre: 200 px up, the middle of the top 400 px.
      expect(still.project(map).dy, -200);
      final driving = YouAreHereLayer.focalFor(navigating: true, covered: 400);
      // 70% of the way down what shows: 280 px from the top.
      expect(400 + driving.project(map).dy, closeTo(280, 0.001));
      // With nothing over the map, as before.
      expect(
        YouAreHereLayer.focalFor(navigating: false, covered: 0).project(map),
        Offset.zero,
      );
      expect(
        400 +
            YouAreHereLayer.focalFor(
              navigating: true,
              covered: 0,
            ).project(map).dy,
        closeTo(560, 0.001),
      );
    });

    testWidgets('MapCover says how much of the screen the drawer covers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cover = ValueNotifier<double>(0);
      final sheet = DraggableScrollableController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DraggableScrollableSheet(
                  controller: sheet,
                  initialChildSize: 0.5,
                  minChildSize: 0.2,
                  maxChildSize: 0.9,
                  builder: (context, scroll) => MapCover(
                    cover: cover,
                    child: ListView(
                      controller: scroll,
                      children: const [SizedBox(height: 2000)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(cover.value, closeTo(400, 1));

      sheet.jumpTo(0.2);
      await tester.pump();
      await tester.pump();
      expect(cover.value, closeTo(160, 1));
    });

    test('a following map goes back to the person; a free one stays', () async {
      final follow = MapFollow(
        positions: const Stream.empty(),
        headings: const Stream.empty(),
      );
      final seen = <double?>[];
      final listening = follow.alignments.listen(seen.add);
      follow.realign();
      follow.follow();
      follow.realign();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [MapFollow.followZoom, null]);
      await listening.cancel();
      follow.dispose();
    });

    test('Center first makes room when the screen asks it to', () {
      final follow = MapFollow(
        positions: const Stream.empty(),
        headings: const Stream.empty(),
      );
      var asked = 0;
      follow.makeRoom = () => asked++;
      follow.makeRoom?.call();
      expect(asked, 1);
      follow.dispose();
    });
  });

  group('the alarm waits for the fire type', () {
    Future<void> sheet(WidgetTester tester, Map<String, dynamic> raw) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AlarmAskSheet(area: AreaView(raw), bfp: true),
              ),
            ),
          ),
        );

    const area = {
      'id': 'a1',
      'designation': 'Area 1',
      'status': 'arrived',
      'alarm_level': null,
    };

    testWidgets('nobody has said what is burning: no level to pick', (
      tester,
    ) async {
      await sheet(tester, {...area, 'fire_type': null});
      expect(find.text('What is burning comes first'), findsOneWidget);
      expect(find.byType(RadioRow), findsNothing);
    });

    testWidgets('once they have, the levels are offered', (tester) async {
      await sheet(tester, {
        ...area,
        'fire_type': 'structural',
        'fire_subtype': 'residential',
        'alarm_level': 'positive_fire_alarm',
      });
      expect(find.text('What is burning comes first'), findsNothing);
      expect(find.byType(RadioRow), findsWidgets);
    });

    testWidgets('an older server that sends no fire type is not locked', (
      tester,
    ) async {
      await sheet(tester, {...area, 'alarm_level': 'positive_fire_alarm'});
      expect(find.text('What is burning comes first'), findsNothing);
    });
  });
}
