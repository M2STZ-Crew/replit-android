import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/models/post_incident_report.dart';
import 'package:replit/screens/observer_handoff_screen.dart';
import 'package:replit/screens/responder/responder_status.dart';
import 'package:replit/screens/subadmin/pending_reports_screen.dart';
import 'package:replit/screens/subadmin/post_incident_report_screen.dart';
import 'package:replit/theme.dart';

/// Master Context v10 on the phone: the Post-Incident Report a team captain
/// files after fire out, the tray that holds it until they do, and the handoff
/// that sends observer captains to the web.
void main() {
  const designSize = Size(402, 874);

  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
    theme: buildAppTheme(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(child, textScale: textScale));
    await tester.pumpAndSettle();
  }

  // The form is a lazily built ListView; scroll its Scrollable, the first one.
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  // A fake API: the resolved incident, its dispatch log, and the org fleet.
  final dispatches = [
    {
      'id': 'd1',
      'responder_id': 'u1',
      'responder_name': 'Juan Dela Cruz',
      'status': 'completed',
      'vehicle_name': 'Apollo',
      'crew_role': 'Driver',
      'dispatched_at': '2026-09-10T10:00:00Z',
    },
    {
      'id': 'd2',
      'responder_id': 'u2',
      'responder_name': 'Maria Santos',
      'status': 'completed',
      'vehicle_name': 'Apollo',
      'crew_role': 'Nozzle',
      'dispatched_at': '2026-09-10T10:01:00Z',
    },
    {
      'id': 'd3',
      'responder_id': 'u3',
      'responder_name': 'Leo Reyes',
      'status': 'withdrawn',
      'vehicle_name': 'Hermes',
      'crew_role': 'Pump',
      'dispatched_at': '2026-09-10T10:02:00Z',
    },
  ];

  const fleet = [
    {
      'id': 'e1',
      'name': 'Apollo',
      'category': 'fire_truck',
      'status': 'available',
    },
    {
      'id': 'e2',
      'name': 'Achilles',
      'category': 'fire_truck',
      'status': 'available',
    },
  ];

  // The captain's organisation, as GET /organizations/mine/members lists it.
  const team = [
    {'id': 'u9', 'full_name': 'Ramon Dizon', 'role': 'sub_admin'},
    {'id': 'u1', 'full_name': 'Juan Dela Cruz', 'role': 'response_team'},
    {'id': 'u2', 'full_name': 'Maria Santos', 'role': 'response_team'},
  ];

  /// What the form posted when it filed, if it did.
  Map<String, dynamic>? filed;
  setUp(() => filed = null);

  ApiClient fakeApi({
    List<Map<String, Object>> equipment = fleet,
    List<Map<String, Object>>? members = team,
    List<Map<String, Object>>? joined,
    bool trayEndpoint = true,
  }) => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      Object body;
      if (path.endsWith('/post-incident-reports/owed')) {
        // A server from before each team filed its own has no such route.
        if (!trayEndpoint) return http.Response('{"message":"Not Found"}', 404);
        body = [
          {
            'id': 'a9',
            'designation': 'Area 12',
            'status': 'closed',
            'resolved_at': '2026-09-10T11:00:00Z',
          },
        ];
      } else if (path.endsWith('/post-incident-report') &&
          req.method == 'POST') {
        filed = jsonDecode(req.body) as Map<String, dynamic>;
        body = {'id': 'p1'};
      } else if (path.endsWith('/organizations/mine/members')) {
        if (members == null) return http.Response('{"message":"down"}', 500);
        body = members;
      } else if (path.endsWith('/dispatches')) {
        body = joined ?? dispatches;
      } else if (path == '/equipment') {
        body = equipment;
      } else if (path == '/incidents' &&
          req.url.queryParameters['status'] == 'post_incident_report') {
        body = [
          {
            'id': 'a4',
            'designation': 'Area 11',
            'status': 'post_incident_report',
            'resolved_at': '2026-09-10T11:00:00Z',
          },
        ];
      } else {
        body = {
          'id': 'a4',
          'designation': 'Area 11',
          'status': 'post_incident_report',
          'reported_at': '2026-09-10T09:40:00Z',
          'resolved_at': '2026-09-10T11:00:00Z',
        };
      }
      return http.Response(jsonEncode(body), 200);
    }),
  );

  group('Post-Incident Report prefill', () {
    test('starts from the dispatch log: truck, driver, crew', () {
      final p = PostIncidentPrefill.fromDispatches(dispatches);
      expect(p.truckLabel, 'Apollo');
      expect(p.driverName, 'Juan Dela Cruz');
      expect(p.driverUserId, 'u1');
      expect(p.roster.map((m) => m.name), ['Juan Dela Cruz', 'Maria Santos']);
    });

    test('a withdrawn responder did not go', () {
      final p = PostIncidentPrefill.fromDispatches(dispatches);
      expect(p.roster.any((m) => m.name == 'Leo Reyes'), isFalse);
    });

    test('an empty log prefills nothing', () {
      final p = PostIncidentPrefill.fromDispatches(const []);
      expect(p.truckLabel, isNull);
      expect(p.driverName, isNull);
      expect(p.roster, isEmpty);
    });

    test('a member dispatched twice appears once', () {
      final p = PostIncidentPrefill.fromDispatches([
        dispatches[0],
        dispatches[0],
      ]);
      expect(p.roster, hasLength(1));
    });
  });

  group('the form is single-submit, fully filled', () {
    test('everything has to be picked', () {
      expect(
        missingPostIncidentFields(
          units: 0,
          hasDriver: false,
          roster: 0,
          equipment: 0,
        ),
        ['unit', 'driver', 'roster', 'equipment taken'],
      );
      expect(
        missingPostIncidentFields(
          units: 2,
          hasDriver: true,
          roster: 3,
          equipment: 1,
        ),
        isEmpty,
      );
    });

    test('the fire cannot be out before the incident', () {
      final started = DateTime(2026, 9, 10, 9, 40);
      expect(
        missingPostIncidentFields(
          units: 1,
          hasDriver: true,
          roster: 1,
          equipment: 1,
          incidentAt: started,
          fireOutAt: started.subtract(const Duration(minutes: 5)),
        ),
        ['a fire-out time after the incident'],
      );
    });

    test('a false alarm needs its reason picked', () {
      List<String> missing(String? reason) => missingPostIncidentFields(
        units: 1,
        hasDriver: true,
        roster: 1,
        equipment: 1,
        falseAlarm: true,
        falseAlarmReason: reason,
      );
      expect(missing(null), ['what the team found']);
      expect(missing(kFalseAlarmReasons.first), isEmpty);
    });

    test('a unit from the register keeps its link', () {
      expect(
        const ReportUnit(
          name: 'Apollo',
          type: 'Fire Truck',
          equipmentId: 'e1',
        ).toJson(),
        {'name': 'Apollo', 'type': 'Fire Truck', 'equipment_id': 'e1'},
      );
      expect(const ReportUnit(name: 'Fire truck').toJson(), {
        'name': 'Fire truck',
      });
    });

    test('a roster member serialises without empty fields', () {
      expect(const RosterMember(name: 'Juan', role: ' ').toJson(), {
        'name': 'Juan',
      });
      expect(
        const RosterMember(name: 'Juan', role: 'Driver', userId: 'u1').toJson(),
        {'name': 'Juan', 'role': 'Driver', 'user_id': 'u1'},
      );
    });
  });

  group('status labels', () {
    test('the report step reads as a to-do, not an enum', () {
      expect(responderStatusLabel('post_incident_report'), 'REPORT DUE');
      expect(responderStatusLabel('closed'), 'CLOSED');
      expect(responderStatusLabel('en_route'), 'EN ROUTE');
    });

    test('every post-fire status counts as after fire out', () {
      expect(kAfterFireOut, {'fire_out', 'post_incident_report', 'closed'});
    });
  });

  group('screens build and fit', () {
    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('Post-Incident Report form at ${scale}x', (tester) async {
        await pump(
          tester,
          PostIncidentReportScreen(areaId: 'a4', api: fakeApi()),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('AREA 11'), findsOneWidget);
        // Picked, never typed: there is not one text box on the form.
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Time of the incident'), findsOneWidget);
        expect(find.text('Time the fire was out'), findsOneWidget);
        // The team is there to pick from — once as driver, once for the roster.
        await scrollTo(tester, find.text('Pick one.'));
        expect(find.text('Ramon Dizon'), findsWidgets);
        await scrollTo(
          tester,
          find.text('Pick everyone who went, the driver included.'),
        );
        expect(find.text('Maria Santos'), findsWidgets);
        // Started from the response: the truck, its driver and the crew are
        // already picked. Nothing came off the truck yet, so it cannot be filed.
        await scrollTo(tester, find.textContaining('Still needed'));
        expect(find.text('Still needed: equipment taken'), findsOneWidget);
      });

      testWidgets('pending reports tray at ${scale}x', (tester) async {
        await pump(
          tester,
          PendingReportsScreen(api: fakeApi()),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        // What this captain's team still owes — here an incident another
        // team's report already closed.
        expect(find.text('AREA 12'), findsOneWidget);
      });

      testWidgets('observer handoff at ${scale}x', (tester) async {
        await pump(
          tester,
          const ObserverHandoffScreen(
            me: {
              'role': 'sub_admin',
              'agency_type': 'police',
              'full_name': 'Pedro Pulis',
            },
          ),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('YOUR CONSOLE IS ON THE WEB'), findsOneWidget);
        // Nothing that the server would refuse an observer is offered here.
        for (final action in ['VERIFY', 'DISPATCH', 'FIRE OUT', 'REJECT']) {
          expect(find.textContaining(action), findsNothing);
        }
      });
    }

    // Scroll until the [nth] match is built, bring it on screen, let the list
    // lay out, then tap. A member appears twice — as a driver choice and as a
    // roster choice — so the roster's is nth: 1.
    Future<void> tapChip(
      WidgetTester tester,
      Finder chip, {
      int nth = 0,
    }) async {
      final list = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      if (chip.evaluate().length <= nth) {
        // It may be above: go back to the top and look down from there.
        await tester.drag(list, const Offset(0, 5000));
        await tester.pump(const Duration(milliseconds: 50));
      }
      for (var i = 0; i < 60 && chip.evaluate().length <= nth; i++) {
        await tester.drag(list, const Offset(0, -150));
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Pin the element itself: once it scrolls into view an earlier match can
      // be unloaded, and "the nth" would then be a different one.
      final element = chip.evaluate().elementAt(nth);
      final target = find.byElementPredicate((e) => identical(e, element));
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> file(WidgetTester tester) async {
      await scrollTo(tester, find.text('FILE REPORT & CLOSE INCIDENT'));
      expect(find.textContaining('Still needed'), findsNothing);
      await tester.tap(find.text('FILE REPORT & CLOSE INCIDENT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FILE REPORT'));
      await tester.pumpAndSettle();
    }

    testWidgets('picking the equipment arms the submit, and it files what '
        'was picked', (tester) async {
      await pump(
        tester,
        PostIncidentReportScreen(areaId: 'a4', api: fakeApi()),
      );
      await tapChip(tester, find.text('SCBA'));
      await tapChip(tester, find.text('Hose line'));
      await file(tester);

      expect(filed, isNotNull);
      expect(filed!['units'], [
        {'name': 'Apollo', 'type': 'Fire Truck', 'equipment_id': 'e1'},
      ]);
      expect(filed!['driver_name'], 'Juan Dela Cruz');
      expect(filed!['driver_user_id'], 'u1');
      expect(filed!['roster'], [
        {'name': 'Juan Dela Cruz', 'user_id': 'u1'},
        {'name': 'Maria Santos', 'user_id': 'u2'},
      ]);
      expect(filed!['equipment_taken'], ['Hose line', 'SCBA']);
      // The times the system recorded, unless the captain changes them.
      expect(filed!['incident_at'], '2026-09-10T09:40:00.000Z');
      expect(filed!['fire_out_at'], '2026-09-10T11:00:00.000Z');
      expect(filed!.containsKey('notes'), isFalse);
      // Still readable by a server from before several units were recorded.
      expect(filed!['truck_label'], 'Apollo');
    });

    testWidgets('several units, one driver, and the driver joins the roster', (
      tester,
    ) async {
      await pump(
        tester,
        PostIncidentReportScreen(areaId: 'a4', api: fakeApi()),
      );
      await tapChip(tester, find.text('Achilles'));
      // Ramon drove instead: the first "Ramon Dizon" chip is the driver's.
      await tapChip(tester, find.text('Ramon Dizon'));
      await tapChip(tester, find.text('Ladder'));
      await file(tester);

      expect(
        [for (final u in filed!['units'] as List) u['name']],
        ['Apollo', 'Achilles'],
      );
      expect(filed!['truck_label'], 'Apollo, Achilles');
      expect(filed!['driver_name'], 'Ramon Dizon');
      expect(
        [for (final m in filed!['roster'] as List) m['name']],
        ['Ramon Dizon', 'Juan Dela Cruz', 'Maria Santos'],
      );
    });

    testWidgets('taking the driver off the roster unpicks the driver', (
      tester,
    ) async {
      await pump(
        tester,
        PostIncidentReportScreen(areaId: 'a4', api: fakeApi()),
      );
      await tapChip(tester, find.text('SCBA'));
      await tapChip(tester, find.text('Juan Dela Cruz'), nth: 1);
      await scrollTo(tester, find.textContaining('Still needed'));
      expect(find.text('Still needed: driver'), findsOneWidget);
    });

    testWidgets('a false alarm asks which kind, to pick', (tester) async {
      await pump(
        tester,
        PostIncidentReportScreen(areaId: 'a4', api: fakeApi()),
      );
      await tapChip(tester, find.text('SCBA'));
      await tapChip(tester, find.text('We arrived and found nothing'));
      await scrollTo(tester, find.textContaining('Still needed'));
      expect(find.text('Still needed: what the team found'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tapChip(tester, find.text('Wrong address'));
      await file(tester);
      expect(filed!['false_alarm'], isTrue);
      expect(filed!['false_alarm_note'], 'Wrong address');
    });

    testWidgets('a team with no units registered picks the kind that went', (
      tester,
    ) async {
      await pump(
        tester,
        PostIncidentReportScreen(
          areaId: 'a4',
          api: fakeApi(equipment: const [], joined: const []),
        ),
      );
      await tapChip(tester, find.text('Fire truck'));
      await tapChip(tester, find.text('Water tanker'));
      await tapChip(tester, find.text('Maria Santos'));
      await tapChip(tester, find.text('Nozzle'));
      await file(tester);
      expect(
        [for (final u in filed!['units'] as List) u['name']],
        ['Fire truck', 'Water tanker'],
      );
      expect(
        (filed!['units'] as List).first.containsKey('equipment_id'),
        isFalse,
      );
      expect(filed!['driver_name'], 'Maria Santos');
    });

    testWidgets('only the captain\u2019s own organization is offered', (
      tester,
    ) async {
      // Someone from another team responded to this fire too. They went, but
      // they are on their own captain's report, not this one.
      const outsider = {
        'id': 'd9',
        'responder_id': 'x9',
        'responder_name': 'Outside Responder',
        'status': 'completed',
        'dispatched_at': '2026-09-10T10:03:00Z',
      };
      await pump(
        tester,
        PostIncidentReportScreen(
          areaId: 'a4',
          api: fakeApi(joined: [...dispatches, outsider]),
        ),
      );
      await tapChip(tester, find.text('SCBA'));
      expect(find.text('Outside Responder'), findsNothing);
      await file(tester);
      expect(
        [for (final m in filed!['roster'] as List) m['user_id']],
        ['u1', 'u2'],
      );
    });

    testWidgets('a captain in no organization is told so', (tester) async {
      await pump(
        tester,
        PostIncidentReportScreen(
          areaId: 'a4',
          api: fakeApi(members: const [], joined: const []),
        ),
      );
      await scrollTo(tester, find.textContaining('not in an organization'));
      expect(find.textContaining('Could not load your team'), findsNothing);
    });

    testWidgets('the tray falls back on a server without the owed list', (
      tester,
    ) async {
      await pump(
        tester,
        PendingReportsScreen(api: fakeApi(trayEndpoint: false)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('AREA 11'), findsOneWidget);
    });

    testWidgets('with no team loaded it says so, and offers to try again', (
      tester,
    ) async {
      await pump(
        tester,
        PostIncidentReportScreen(
          areaId: 'a4',
          api: fakeApi(members: null, joined: const []),
        ),
      );
      await scrollTo(tester, find.textContaining('Could not load your team'));
      expect(find.text('TRY AGAIN'), findsOneWidget);
      await scrollTo(tester, find.textContaining('Still needed'));
      expect(find.textContaining('driver, roster'), findsOneWidget);
    });
  });

  group('who the phone sends to the web', () {
    test('observer captains, and only them', () {
      for (final agency in ['police', 'medical', 'barangay']) {
        expect(
          isObserverCaptain({'role': 'sub_admin', 'agency_type': agency}),
          isTrue,
        );
      }
      expect(
        isObserverCaptain({
          'role': 'sub_admin',
          'agency_type': 'fire_volunteer',
        }),
        isFalse,
      );
      expect(
        isObserverCaptain({'role': 'sub_admin', 'agency_type': 'bfp'}),
        isFalse,
      );
      expect(
        isObserverCaptain({'role': 'response_team', 'agency_type': 'police'}),
        isFalse,
      );
    });
  });
}
