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
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );

  Future<void> pump(WidgetTester tester, Widget child, {double textScale = 1.0}) async {
    tester.view.physicalSize = designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(child, textScale: textScale));
    await tester.pumpAndSettle();
  }

  // The form is a lazily built ListView, and every TextField inside it has its
  // own Scrollable — so scroll the list's, which is the first one.
  Future<void> scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
  );

  // A fake API: the resolved incident, its dispatch log, and the org fleet.
  final dispatches = [
    {
      'id': 'd1', 'responder_id': 'u1', 'responder_name': 'Juan Dela Cruz',
      'status': 'completed', 'vehicle_name': 'Apollo', 'crew_role': 'Driver',
      'dispatched_at': '2026-09-10T10:00:00Z',
    },
    {
      'id': 'd2', 'responder_id': 'u2', 'responder_name': 'Maria Santos',
      'status': 'completed', 'vehicle_name': 'Apollo', 'crew_role': 'Nozzle',
      'dispatched_at': '2026-09-10T10:01:00Z',
    },
    {
      'id': 'd3', 'responder_id': 'u3', 'responder_name': 'Leo Reyes',
      'status': 'withdrawn', 'vehicle_name': 'Hermes', 'crew_role': 'Pump',
      'dispatched_at': '2026-09-10T10:02:00Z',
    },
  ];

  ApiClient fakeApi() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      Object body;
      if (path.endsWith('/dispatches')) {
        body = dispatches;
      } else if (path == '/equipment') {
        body = [
          {'id': 'e1', 'name': 'Apollo', 'category': 'fire_truck', 'status': 'available'},
          {'id': 'e2', 'name': 'Achilles', 'category': 'fire_truck', 'status': 'available'},
        ];
      } else if (path == '/incidents' && req.url.queryParameters['status'] == 'post_incident_report') {
        body = [
          {'id': 'a4', 'designation': 'Area 11', 'status': 'post_incident_report',
           'resolved_at': '2026-09-10T11:00:00Z'},
        ];
      } else {
        body = {'id': 'a4', 'designation': 'Area 11', 'status': 'post_incident_report',
                'resolved_at': '2026-09-10T11:00:00Z'};
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
      final p = PostIncidentPrefill.fromDispatches([dispatches[0], dispatches[0]]);
      expect(p.roster, hasLength(1));
    });
  });

  group('the form is single-submit, fully filled', () {
    test('everything but notes is required', () {
      expect(
        missingPostIncidentFields(
          truckLabel: ' ', truckType: 'Fire Truck', driverName: '',
          roster: const [], equipment: const [],
        ),
        ['unit', 'driver', 'roster', 'equipment taken'],
      );
      expect(
        missingPostIncidentFields(
          truckLabel: 'Apollo', truckType: 'Fire Truck', driverName: 'Juan',
          roster: const [RosterMember(name: 'Juan')], equipment: const ['SCBA'],
        ),
        isEmpty,
      );
    });

    test('a roster member serialises without empty fields', () {
      expect(const RosterMember(name: 'Juan', role: ' ').toJson(), {'name': 'Juan'});
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
      expect(kAfterFireOut, {'resolved', 'post_incident_report', 'closed'});
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
        // Prefilled from the dispatch log.
        expect(find.text('Juan Dela Cruz'), findsWidgets);
        await scrollTo(tester, find.text('Maria Santos'));
        expect(find.text('Maria Santos'), findsOneWidget);
        // Nothing came off the truck yet, so it cannot be filed.
        await scrollTo(tester, find.textContaining('Still needed'));
        expect(find.text('Still needed: equipment taken'), findsOneWidget);
      });

      testWidgets('pending reports tray at ${scale}x', (tester) async {
        await pump(tester, PendingReportsScreen(api: fakeApi()), textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('AREA 11'), findsOneWidget);
      });

      testWidgets('observer handoff at ${scale}x', (tester) async {
        await pump(
          tester,
          const ObserverHandoffScreen(
            me: {'role': 'sub_admin', 'agency_type': 'police', 'full_name': 'Pedro Pulis'},
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

    testWidgets('adding equipment arms the submit', (tester) async {
      await pump(tester, PostIncidentReportScreen(areaId: 'a4', api: fakeApi()));
      await scrollTo(tester, find.text('+ SCBA'));
      await tester.tap(find.text('+ SCBA'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('FILE REPORT & CLOSE INCIDENT'));
      expect(find.textContaining('Still needed'), findsNothing);
      expect(find.text('SCBA'), findsOneWidget); // now a chip on the report
    });
  });

  group('who the phone sends to the web', () {
    test('observer captains, and only them', () {
      for (final agency in ['police', 'medical', 'barangay']) {
        expect(isObserverCaptain({'role': 'sub_admin', 'agency_type': agency}), isTrue);
      }
      expect(isObserverCaptain({'role': 'sub_admin', 'agency_type': 'fire_volunteer'}), isFalse);
      expect(isObserverCaptain({'role': 'sub_admin', 'agency_type': 'bfp'}), isFalse);
      expect(isObserverCaptain({'role': 'response_team', 'agency_type': 'police'}), isFalse);
    });
  });
}
