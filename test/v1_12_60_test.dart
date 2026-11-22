import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/api/notification_router.dart';
import 'package:replit/models/alarm.dart';
import 'package:replit/models/alarm_status.dart';
import 'package:replit/models/coordinator_powers.dart';
import 'package:replit/models/tracking.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/alarm_status_banner.dart';
import 'package:replit/widgets/code_confirm_sheet.dart';

/// v1.12.60 (backend v1.12.49), 22 Nov 2026: the alarm status, highlighted,
/// for everyone, everywhere.
String _iso(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  ).toUtc().toIso8601String();
}

Map<String, dynamic> _fire({
  String status = 'arrived',
  String? level = 'third_alarm',
  bool underControl = false,
}) => {
  'status': status,
  'alarm_level': level,
  'alarm_level_set_at': level == null ? null : _iso(9, 42),
  'alarm_level_set_by_org': level == null ? null : 'BFP Pasay',
  'alarm_level_set_by_name': level == null ? null : 'C. Reyes',
  'under_control_at': underControl ? _iso(10, 15) : null,
  'under_control_by_org': underControl ? 'Pasay Fire Volunteers' : null,
  'resolved_at': status == 'fire_out' ? _iso(10, 30) : null,
};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 780),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the status', () {
    test('a raised alarm', () {
      final s = AlarmStatus.of(_fire());
      expect(s.situation, FireSituation.burning);
      expect(s.raised, isTrue);
      expect(s.known, isTrue);
    });

    test('a positive fire alarm is not a raise', () {
      final s = AlarmStatus.of(_fire(level: kInitialAlarmLevel));
      expect(s.raised, isFalse);
      expect(s.known, isTrue);
    });

    test('under control, then out', () {
      final held = AlarmStatus.of(_fire(underControl: true));
      expect(held.situation, FireSituation.underControl);
      expect(held.raised, isFalse);
      final out = AlarmStatus.of(_fire(status: 'fire_out', underControl: true));
      expect(out.situation, FireSituation.fireOut);
    });

    test('a rejected or merged incident has none', () {
      for (final status in ['rejected', 'merged']) {
        expect(AlarmStatus.of(_fire(status: status)).applies, isFalse);
      }
    });

    test("a report's row reads the fire's fields, not its own", () {
      final s = AlarmStatus.of({
        'status': 'submitted',
        'area_status': 'en_route',
        'area_alarm_level': 'second_alarm',
      });
      expect(s.status, 'en_route');
      expect(s.level, 'second_alarm');
    });

    test('an older server sends only the level', () {
      final s = AlarmStatus.of({
        'status': 'arrived',
        'alarm_level': 'first_alarm',
      });
      expect(s.raised, isTrue);
      expect(alarmStatusDetail(s, staff: true), isNull);
    });

    test('Track it live follows a raise without crediting the last setter', () {
      final s = AlarmStatus.of(
        _fire(),
      ).withLive(status: 'arrived', level: 'fourth_alarm');
      expect(s.level, 'fourth_alarm');
      expect(s.setByOrg, isNull);
    });

    test('a snapshot carries it, and an older one says it does not', () {
      final base = {
        'area_id': 'a1',
        'status': 'arrived',
        'centroid_lat': 14.5,
        'centroid_lng': 121.0,
        'responders': <Object>[],
      };
      expect(TrackingSnapshot.tryParse(base)!.hasAlarm, isFalse);
      final snap = TrackingSnapshot.tryParse({
        ...base,
        'alarm_level': 'second_alarm',
        'under_control_at': _iso(10, 15),
      })!;
      expect(snap.hasAlarm, isTrue);
      expect(snap.alarmLevel, 'second_alarm');
      expect(snap.underControlAt, isNotNull);
    });
  });

  group('the banner', () {
    testWidgets('residents: the meaning, and never a name', (tester) async {
      await _pump(tester, AlarmStatusBanner(AlarmStatus.of(_fire())));
      expect(find.text('3RD ALARM'), findsOneWidget);
      expect(find.text('Raised 9:42 AM by BFP Pasay'), findsOneWidget);
      expect(find.textContaining('C. Reyes'), findsNothing);
      expect(find.textContaining('more firefighters'), findsOneWidget);
    });

    testWidgets('staff: who set it', (tester) async {
      await _pump(
        tester,
        AlarmStatusBanner(AlarmStatus.of(_fire()), staff: true, compact: true),
      );
      expect(
        find.text('Raised 9:42 AM by BFP Pasay · C. Reyes'),
        findsOneWidget,
      );
      expect(find.textContaining('more firefighters'), findsNothing);
    });

    testWidgets('under control: what it was, and Withdraw', (tester) async {
      var withdrawn = false;
      await _pump(
        tester,
        AlarmStatusBanner(
          AlarmStatus.of(_fire(underControl: true)),
          staff: true,
          action: 'Withdraw',
          onAction: () => withdrawn = true,
        ),
      );
      expect(find.text('UNDER CONTROL'), findsOneWidget);
      expect(
        find.text('Was 3rd alarm · 10:15 AM · Pasay Fire Volunteers'),
        findsOneWidget,
      );
      await tester.tap(find.text('Withdraw'));
      expect(withdrawn, isTrue);
    });

    testWidgets('before a level it says so, except where it is not shown', (
      tester,
    ) async {
      final none = AlarmStatus.of(_fire(status: 'reported', level: null));
      await _pump(tester, AlarmStatusBanner(none));
      expect(find.text('NO ALARM YET'), findsOneWidget);
      await _pump(tester, AlarmStatusBanner(none, showNone: false));
      expect(find.text('NO ALARM YET'), findsNothing);
      await _pump(tester, AlarmBadge(none));
      expect(
        find.byType(Text),
        findsNothing,
        reason: 'no badge before a level',
      );
    });

    testWidgets('a rejected incident draws nothing', (tester) async {
      await _pump(
        tester,
        AlarmStatusBanner(AlarmStatus.of(_fire(status: 'rejected'))),
      );
      expect(find.byType(Text), findsNothing);
    });

    for (final level in kAlarmLadder) {
      testWidgets('$level fits 360 px at large type', (tester) async {
        await _pump(
          tester,
          Column(
            children: [
              AlarmStatusBanner(AlarmStatus.of(_fire(level: level))),
              AlarmBadge(AlarmStatus.of(_fire(level: level))),
            ],
          ),
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(alarmWord(level).toUpperCase()), findsNWidgets(2));
      });
    }
  });

  test(
    "a coordinator's FC-2 says everyone will see it; a responder's, not",
    () {
      expect(codeAudience('FC-2', declares: true), contains('residents too'));
      expect(codeAudience('FC-2'), contains('tells command'));
    },
  );

  test('who declares and withdraws', () {
    for (final agency in ['bfp', 'fire_volunteer']) {
      expect(
        CoordinatorPowers.of({'agency_type': agency}).declaresUnderControl,
        isTrue,
      );
    }
    for (final agency in ['police', 'medical', 'barangay']) {
      expect(
        CoordinatorPowers.of({'agency_type': agency}).declaresUnderControl,
        isFalse,
      );
    }
  });

  test('a raise opens the fire', () {
    const staff = {'role': 'response_team'};
    const resident = {'role': 'general_user'};
    expect(targetFor('alarm_raised', staff), NotificationTarget.staffIncident);
    expect(
      targetFor('alarm_raised', resident),
      NotificationTarget.verifiedFire,
    );
    expect(
      targetFor('under_control_withdrawn', resident),
      NotificationTarget.none,
    );
  });
}
