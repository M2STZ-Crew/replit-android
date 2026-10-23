import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/navigation/instructions.dart';
import 'package:replit/navigation/nav_route.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/lane_strip.dart';

import 'navigation_test.dart' as nt;

/// A lane as the Directions answer lists it.
Map<String, dynamic> lane(
  List<String> indications, {
  required bool valid,
  bool active = false,
  String? use,
}) => {
  'indications': indications,
  'valid': valid,
  'active': active,
  'valid_indication': ?use,
};

/// [lanes] as a step's first intersection carries them.
List<Map<String, dynamic>> at(List<Map<String, dynamic>> lanes) => [
  {
    'location': <double>[121.0, 14.5],
    'lanes': lanes,
  },
];

/// Lanes from valid flags, left to right: `[false, true, true]`.
List<LaneInfo> lanes(List<bool> valid) => [
  for (final v in valid) LaneInfo(indications: const ['straight'], valid: v),
];

NavStep turn({List<LaneInfo>? lanes}) => NavStep(
  type: 'turn',
  modifier: 'right',
  name: 'Gil Puyat Avenue',
  location: nt.at(1000),
  distance: 0,
  duration: 0,
  at: 1000,
  lanes: lanes,
);

void main() {
  group('reading the lanes (PRD v14 §4.9.2)', () {
    test('a maneuver with lanes keeps them, left to right', () {
      final read = parseLanes(
        at([
          lane(['left'], valid: false),
          lane(['straight'], valid: false),
          lane(['straight', 'right'], valid: true, active: true, use: 'right'),
        ]),
      )!;
      expect(read, hasLength(3));
      expect(read.map((l) => l.valid), [false, false, true]);
      expect(read[2].preferred, isTrue);
      expect(read[2].shown, 'right', reason: 'the way this maneuver uses it');
      expect(read[0].shown, 'left');
    });

    test('no lane data, or a malformed lane, means no strip', () {
      expect(parseLanes(null), isNull);
      expect(parseLanes(const []), isNull);
      expect(parseLanes(at(const [])), isNull);
      expect(
        parseLanes([
          {
            'location': <double>[121.0, 14.5],
          },
        ]),
        isNull,
      );
      expect(
        parseLanes(
          at([
            lane(['left'], valid: true),
            {'indications': 'left', 'valid': true},
          ]),
        ),
        isNull,
      );
      expect(
        parseLanes(
          at([
            {'indications': <String>[], 'valid': true},
          ]),
        ),
        isNull,
      );
      expect(
        parseLanes(
          at([
            {
              'indications': ['left'],
              'valid': 'yes',
            },
          ]),
        ),
        isNull,
      );
    });

    test('lanes none of which can be taken are not shown', () {
      expect(
        parseLanes(
          at([
            lane(['left'], valid: false),
            lane(['straight'], valid: false),
          ]),
        ),
        isNull,
      );
    });

    test('a route answer carries each step\'s lanes', () {
      final route = nt.lRoute;
      final steps = [...route.steps];
      steps[1] = {
        ...steps[1],
        'intersections': at([
          lane(['straight'], valid: false),
          lane(['right'], valid: true),
        ]),
      };
      final read = parseRoutes(
        nt.answer([
          (
            points: route.points,
            steps: steps,
            duration: route.duration,
            summary: route.summary,
            congestion: route.congestion,
            typical: route.typical,
          ),
        ]),
      ).single;
      expect(read.steps[0].lanes, isNull);
      expect(read.steps[1].lanes!.map((l) => l.valid), [false, true]);
    });
  });

  group('the lanes in words', () {
    test('which side, and how many', () {
      expect(lanePhrase(lanes([true, true, false])), 'the left two lanes');
      expect(lanePhrase(lanes([false, false, true])), 'the right lane');
      expect(lanePhrase(lanes([false, true, false])), 'the middle lane');
      expect(
        lanePhrase(lanes([false, true, true, false])),
        'the middle two lanes',
      );
      expect(
        lanePhrase(lanes([false, true, true, true])),
        'the right three lanes',
      );
    });

    test('nothing to say when the lanes do not narrow the choice', () {
      expect(lanePhrase(null), isNull);
      expect(lanePhrase(lanes([true])), isNull, reason: 'one lane');
      expect(lanePhrase(lanes([true, true])), isNull, reason: 'any lane');
      expect(
        lanePhrase(lanes([true, false, true])),
        isNull,
        reason: 'not side by side: the strip shows it, words would mislead',
      );
    });

    test('the banner line and the voice', () {
      final step = turn(lanes: lanes([false, true, true]));
      expect(laneInstruction(step), 'Use the right two lanes');
      expect(
        spokenInstruction(step, 300, withLanes: true),
        'In 300 metres, turn right onto Gil Puyat Avenue. '
        'Stay in the right two lanes',
      );
      expect(
        spokenInstruction(step, 300),
        'In 300 metres, turn right onto Gil Puyat Avenue',
        reason: 'only a driver hears the lanes',
      );
      expect(laneInstruction(turn()), isNull);
    });

    test('the strip shows from 500 m before the maneuver', () {
      final step = turn(lanes: lanes([false, true]));
      expect(laneStripVisible(step, 501), isFalse);
      expect(laneStripVisible(step, 500), isTrue);
      expect(laneStripVisible(step, 40), isTrue);
      expect(laneStripVisible(turn(), 100), isFalse);
    });
  });

  group('the strip', () {
    Future<void> pump(WidgetTester tester, List<LaneInfo> lanes) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Center(child: LaneStrip(lanes: lanes)),
            ),
          ),
        );

    testWidgets('one plate per lane; the ones to use are marked', (
      tester,
    ) async {
      await pump(tester, lanes([false, true, true]));
      expect(find.byKey(const ValueKey('lane-0-not')), findsOneWidget);
      expect(find.byKey(const ValueKey('lane-1-use')), findsOneWidget);
      expect(find.byKey(const ValueKey('lane-2-use')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a screen reader hears it as one phrase', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, lanes([true, true, false]));
      expect(
        find.bySemanticsLabel('Lanes: 3. Use the left two lanes'),
        findsOneWidget,
      );
      await pump(tester, lanes([true, false, true]));
      expect(
        find.bySemanticsLabel('Lanes: 3. Use the highlighted lanes'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
