import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/screens/notifications_screen.dart';
import 'package:replit/theme.dart';

/// Notifications that open what they are about (v1.12.6): the same place
/// whether tapped in the phone's shade, on the in-app banner, or in Alerts.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const citizen = {'id': 'u1', 'role': 'general_user'};
  const responder = {
    'id': 'r1',
    'role': 'response_team',
    'agency_type': 'fire_volunteer',
  };
  const policeResponder = {
    'id': 'r2',
    'role': 'response_team',
    'agency_type': 'police',
  };
  const fireCoordinator = {
    'id': 'c1',
    'role': 'sub_admin',
    'agency_type': 'fire_volunteer',
  };
  const bfpCoordinator = {
    'id': 'c2',
    'role': 'sub_admin',
    'agency_type': 'bfp',
  };
  const barangayCoordinator = {
    'id': 'c3',
    'role': 'sub_admin',
    'agency_type': 'barangay',
  };

  group('where a notification leads', () {
    test('a new fire opens the incident for whoever works it in the app', () {
      for (final me in [
        responder,
        policeResponder,
        fireCoordinator,
        bfpCoordinator,
      ]) {
        expect(
          targetFor('incident_new', me),
          NotificationTarget.staffIncident,
          reason: '$me',
        );
      }
      expect(
        targetFor('incident_new', barangayCoordinator),
        NotificationTarget.none,
        reason: 'their incidents are on the Observer Console',
      );
      expect(targetFor('incident_new', citizen), NotificationTarget.none);
    });

    test(
      "a coordinator's reminder opens the incident, as the first push did",
      () {
        expect(
          targetFor('incident_reminder', fireCoordinator),
          NotificationTarget.staffIncident,
        );
        expect(
          targetFor('incident_reminder', citizen),
          NotificationTarget.none,
        );
      },
    );

    test('a fire nearby asks a resident, and takes staff to the incident', () {
      expect(
        targetFor('neighborhood_alert', citizen),
        NotificationTarget.nearbyFire,
      );
      expect(targetFor('fire_alert', citizen), NotificationTarget.nearbyFire);
      expect(
        targetFor('neighborhood_alert', responder),
        NotificationTarget.staffIncident,
      );
    });

    test('news about a resident\'s own report opens its live tracker', () {
      expect(
        targetFor('incident_update', citizen),
        NotificationTarget.myReport,
      );
    });

    test(
      'an alarm request opens BFP\'s queue, and the incident for others',
      () {
        expect(
          targetFor('alarm_request', bfpCoordinator),
          NotificationTarget.alarmRequests,
        );
        expect(
          targetFor('alarm_request', fireCoordinator),
          NotificationTarget.staffIncident,
        );
      },
    );

    test('older staff notifications still open the incident', () {
      for (final type in ['responder_dispatch', 'incident_routed']) {
        expect(
          targetFor(type, fireCoordinator),
          NotificationTarget.staffIncident,
        );
      }
    });

    test('a test push and unknown types open nothing', () {
      expect(targetFor('test', responder), NotificationTarget.none);
      expect(targetFor(null, citizen), NotificationTarget.none);
    });

    test('the types that say there is a fire', () {
      expect(fireAlertTypes, {
        'incident_new',
        'incident_reminder',
        'neighborhood_alert',
        'fire_alert',
        'alarm_request',
      });
      expect(fireAlertTypes.contains('incident_update'), isFalse);
    });

    test('something to open: an incident named, or an alarm request', () {
      expect(canOpen('incident_new', {'area_id': 'a1'}), isTrue);
      expect(canOpen('alarm_request', const {}), isTrue);
      expect(canOpen('test', const {}), isFalse);
      expect(canOpen('incident_update', null), isFalse);
    });
  });

  group('the router itself', () {
    testWidgets('opens nothing when the account cannot be read', (
      tester,
    ) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      final router = NotificationRouter(
        api: ApiClient(
          client: MockClient((_) async => http.Response('{}', 503)),
        ),
      );
      final opened = await router.open(
        nav.currentState!,
        type: 'incident_new',
        data: const {'area_id': 'a1'},
      );
      expect(opened, isFalse);
    });

    testWidgets('opens nothing for an observer coordinator', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      final router = NotificationRouter(
        api: ApiClient(
          client: MockClient(
            (_) async => http.Response(jsonEncode(barangayCoordinator), 200),
          ),
        ),
      );
      expect(
        await router.open(
          nav.currentState!,
          type: 'incident_new',
          data: const {'area_id': 'a1'},
        ),
        isFalse,
      );
    });
  });

  group('the Alerts list', () {
    late List<String> calls;
    late List<Map<String, dynamic>> rows;

    ApiClient api() => ApiClient(
      client: MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.url.path == '/notifications') {
          return http.Response(jsonEncode(rows), 200);
        }
        return http.Response('{"message":"ok"}', 200);
      }),
    );

    setUp(() {
      calls = [];
      rows = [
        {
          'id': 'n1',
          'type': 'incident_new',
          'title': 'Fire reported: Area 12',
          'body':
              'A resident reported a fire. Tap to open it, verify it and '
              'respond.',
          'data': {'area_id': 'a12', 'event': 'incident_new'},
          'is_read': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'id': 'n2',
          'type': 'test',
          'title': 'RepLiT test',
          'body': 'Push notifications are working.',
          'data': <String, dynamic>{},
          'is_read': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ];
    });

    Future<List<Map<String, dynamic>>> pump(
      WidgetTester tester, {
      bool opens = true,
    }) async {
      final opened = <Map<String, dynamic>>[];
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: NotificationsScreen(
            api: api(),
            opener: (nav, n) async {
              opened.add(n);
              return opens;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return opened;
    }

    testWidgets('a new fire is labelled, and rows that lead somewhere say so', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('NEW FIRE'), findsOneWidget);
      expect(find.text('FIRE REPORTED: AREA 12'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('opens')),
        findsOneWidget,
        reason: 'the test push has nowhere to go',
      );
    });

    testWidgets('tapping a row marks it read and opens it', (tester) async {
      final opened = await pump(tester);
      await tester.tap(find.text('FIRE REPORTED: AREA 12'));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /notifications/n1/read'));
      expect(opened.single['id'], 'n1');
    });

    testWidgets('a row with nowhere to go only marks read', (tester) async {
      final opened = await pump(tester);
      await tester.tap(find.text('RepLiT test'.toUpperCase()));
      // Not pumpAndSettle: the other row is unread, and its dot pulses.
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, isEmpty);
    });

    testWidgets('when it cannot be opened, it says so', (tester) async {
      await pump(tester, opens: false);
      await tester.tap(find.text('FIRE REPORTED: AREA 12'));
      await tester.pumpAndSettle();
      expect(
        find.text('There is nothing to open for this one.'),
        findsOneWidget,
      );
    });
  });
}
