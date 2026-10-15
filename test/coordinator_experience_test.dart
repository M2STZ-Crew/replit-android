import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/location/place_names.dart';
import 'package:replit/screens/coordinator/area_decision_screen.dart';
import 'package:replit/screens/coordinator/codes_tab.dart';
import 'package:replit/screens/coordinator/coordinator_feed.dart';
import 'package:replit/screens/coordinator/coordinator_shell.dart';
import 'package:replit/screens/coordinator/live_incident.dart';
import 'package:replit/screens/coordinator/my_decisions_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/coordinator_kit.dart';

/// The Coordinator Experience (REPLIT (MAIN) 06): the queue counts what
/// needs the coordinator, Accept verifies and — "I am going too" — responds
/// on the unit picked, Reject asks why, LIVE lists the units and ends with
/// fire out, codes press on the live Area, and "My decisions" reads the
/// audit log back.
void main() {
  const me = {
    'id': 'me',
    'role': 'sub_admin',
    'agency_type': 'fire_volunteer',
    'organization_name': 'Pasay Fire Volunteers',
    'full_name': 'R. Alonzo',
  };

  final now = DateTime.now().toUtc();
  String ago(int minutes) =>
      now.subtract(Duration(minutes: minutes)).toIso8601String();

  Map<String, dynamic> area(
    String id,
    String designation,
    String status, {
    int reports = 3,
    String band = 'medium',
    double score = 0.46,
  }) => {
    'id': id,
    'designation': designation,
    'status': status,
    'centroid_lat': 14.5378,
    'centroid_lng': 121.0014,
    'report_count': reports,
    'confidence_score': score,
    'confidence_band': band,
    'n_score': reports / 10,
    's_score': 0.72,
    'v_score': 0.42,
    'active_dispatch_count': status == 'en_route' ? 2 : 0,
    'reported_at': ago(2),
    'verified_at': status == 'reported' ? null : ago(1),
    'resolved_at': status == 'post_incident_report' ? ago(60 * 16) : null,
    'requested_agencies': ['fire_volunteer', 'medical'],
    'accepted_agencies': status == 'reported' ? [] : ['fire_volunteer'],
    'updated_at': ago(1),
  };

  late List<(String, String, Map<String, dynamic>)> posted;
  late Map<String, Map<String, dynamic>> incidents;
  late List<Map<String, dynamic>> dispatches;
  late List<Map<String, dynamic>> audit;

  // The maps' tile cache asks for a cache folder; tests have no plugin.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaceNames.clear();
    PlaceNames.lookUp = (_, _) async => const PlaceName(
      street: 'F. Victor Street',
      place: 'Barangay 76, Pasay City',
    );
    posted = [];
    dispatches = [];
    audit = [];
    incidents = {
      'a1': area('a1', 'Area 1.2', 'reported'),
      'a2': area('a2', 'Area 2.1', 'reported', reports: 2, band: 'low'),
      'a3': area('a3', 'Area 3.1', 'en_route'),
    };
  });

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      http.Response json(Object body) => http.Response(jsonEncode(body), 200);
      if (req.method == 'POST') {
        final body = req.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(req.body) as Map<String, dynamic>;
        posted.add(('POST', path, body));
        final id = path.split('/').length > 2 ? path.split('/')[2] : '';
        return json(incidents[id] ?? {'message': 'ok'});
      }
      if (path == '/incidents') {
        return json([
          for (final i in incidents.values)
            if (i['status'] != 'post_incident_report') i,
        ]);
      }
      if (path == '/post-incident-reports/owed') {
        return json([
          for (final i in incidents.values)
            if (i['status'] == 'post_incident_report') i,
        ]);
      }
      if (path == '/areas/overlaps/pending') {
        return json([
          {
            'id': 'o1',
            'area_a_id': 'a1',
            'area_b_id': 'a2',
            'area_a_designation': 'Area 1.2',
            'area_b_designation': 'Area 2.1',
            'distance_m': 120,
            'expires_at': now
                .add(const Duration(seconds: 90))
                .toIso8601String(),
          },
        ]);
      }
      if (path.endsWith('/reports')) {
        return json([
          {
            'id': 'r1',
            'reporter_name': 'Ana',
            'photo_url': null,
            'device_lat': 14.5378,
            'device_lng': 121.0014,
            'has_exif': false,
            'gps_discrepancy_flag': false,
            'user_verified_percent': 100,
            'selected_agencies': ['fire_volunteer', 'medical'],
            'created_at': ago(3),
          },
        ]);
      }
      if (path.endsWith('/dispatches')) return json(dispatches);
      if (path.endsWith('/responders/locations')) return json([]);
      if (path.endsWith('/summaries')) return json([]);
      if (path == '/equipment') {
        return json([
          {'id': 'e1', 'name': 'Tanker 1', 'category': 'fire_truck'},
          {'id': 'e2', 'name': 'Tanker 2', 'category': 'fire_truck'},
          {'id': 'e3', 'name': 'Hose', 'category': 'hose'},
        ]);
      }
      if (path == '/fire-codes') {
        return json([
          {
            'id': 'c1',
            'code_number': 'Code A',
            'name': 'Water supply established',
            'description': 'First line charged and flowing',
            'display_order': 1,
            'is_active': true,
          },
        ]);
      }
      if (path == '/audit-logs') return json(audit);
      if (path.startsWith('/incidents/')) {
        return json(incidents[path.split('/')[2]] ?? {});
      }
      return json([]);
    }),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: home));
    await settle(tester);
  }

  /// Tears the screen down so its polls stop before the test ends.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('the queue', () {
    testWidgets('counts what to decide, what is active and what to file', (
      tester,
    ) async {
      incidents['a4'] = area('a4', 'Area 5.1', 'post_incident_report');
      await pump(tester, CoordinatorShell(me: me, api: api()));

      expect(find.text('QUEUE'), findsOneWidget);
      expect(find.text('PASAY FIRE VOLUNTEERS'), findsOneWidget);
      expect(find.bySemanticsLabel('2 To decide'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Active'), findsOneWidget);
      expect(find.bySemanticsLabel('1 To file'), findsOneWidget);
      expect(find.text('Area 1.2 and Area 2.1 overlap'), findsOneWidget);
      expect(find.text('WAITING ON YOU'), findsOneWidget);
      expect(find.text('DECIDE'), findsNWidgets(2));
      expect(find.text('Medium 0.46'), findsOneWidget);
      expect(
        find.text('F. Victor Street, Barangay 76, Pasay City'),
        findsWidgets,
      );

      await tester.tap(find.bySemanticsLabel('1 Active'));
      await settle(tester);
      expect(find.text('ON THE GROUND'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('1 To file'));
      await settle(tester);
      expect(find.text('REPORTS TO FILE'), findsOneWidget);
      expect(find.text('FILE REPORT'), findsOneWidget);
      expect(find.textContaining('waiting 16 h'), findsOneWidget);
      await done(tester);
    });

    testWidgets('OPEN on an active Area goes to LIVE on it', (tester) async {
      await pump(tester, CoordinatorShell(me: me, api: api()));
      await tester.tap(find.bySemanticsLabel('1 Active'));
      await settle(tester);
      await tester.tap(find.text('OPEN'));
      await settle(tester);
      expect(find.text('NOBODY GOING YET'), findsOneWidget);
      expect(find.text('I AM GOING'), findsOneWidget);
      await done(tester);
    });
  });

  group('the decision', () {
    Future<void> openArea(WidgetTester tester, String id) =>
        pump(tester, AreaDecisionScreen(areaId: id, me: me, api: api()));

    testWidgets('shows where it is, how sure, and every report', (
      tester,
    ) async {
      await openArea(tester, 'a1');
      expect(find.text('F. VICTOR STREET'), findsOneWidget);
      expect(find.text('AREA 1.2 · BARANGAY 76'), findsOneWidget);
      expect(find.text('Medium — 0.46'), findsOneWidget);
      expect(find.text('3 of 10 reports'), findsOneWidget);
      expect(find.text('Spread 84 m'), findsOneWidget);
      expect(find.text('Reporters average 42%'), findsOneWidget);
      expect(
        find.text('No summary yet. The reports below are the full record.'),
        findsOneWidget,
      );
      expect(find.text('ACCEPT'), findsOneWidget);
      expect(find.text('REJECT THIS AREA'), findsOneWidget);
      await done(tester);
    });

    testWidgets('Accept alone verifies and sends nobody', (tester) async {
      await openArea(tester, 'a1');
      await tester.tap(find.text('ACCEPT'));
      await settle(tester);
      expect(find.text('Accept Area 1.2?'), findsOneWidget);
      expect(find.textContaining('Fire, Medical'), findsOneWidget);
      // The sheet's own Accept, not the action bar's under the scrim.
      await tester.tap(find.text('ACCEPT').last);
      await settle(tester);
      expect([for (final p in posted) p.$2], ['/incidents/a1/verify']);
      await done(tester);
    });

    testWidgets('"I am going too" responds on the unit picked', (tester) async {
      await openArea(tester, 'a1');
      await tester.tap(find.text('ACCEPT'));
      await settle(tester);
      await tester.tap(find.text('I am going too'));
      await settle(tester);
      expect(find.text('Tanker 1'), findsOneWidget);
      expect(find.text('Hose'), findsNothing, reason: 'units only');
      await tester.tap(find.text('Tanker 2'));
      await settle(tester);
      await tester.tap(find.text('ACCEPT AND GO'));
      await settle(tester);
      expect(
        [for (final p in posted) p.$2],
        ['/incidents/a1/verify', '/incidents/a1/self-dispatch'],
      );
      expect(posted.last.$3['vehicle_name'], 'Tanker 2');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('coordinator.last_unit'), 'Tanker 2');
      await done(tester);
    });

    testWidgets('Reject waits for a reason, then sends it', (tester) async {
      await openArea(tester, 'a2');
      await tester.tap(find.text('REJECT THIS AREA'));
      await settle(tester);
      expect(find.text('Reject Area 2.1?'), findsOneWidget);
      await tester.tap(find.text('REJECT AREA 2.1'));
      await settle(tester);
      expect(posted, isEmpty, reason: 'no reason picked yet');
      await tester.tap(find.text('Duplicate of another Area'));
      await settle(tester);
      await tester.tap(find.text('REJECT AREA 2.1'));
      await settle(tester);
      expect(posted.single.$2, '/incidents/a2/reject');
      expect(posted.single.$3['reason'], 'Duplicate of another Area');
      await done(tester);
    });
  });

  group('LIVE', () {
    testWidgets('lists units by truck and confirms fire out', (tester) async {
      dispatches = [
        {
          'id': 'd1',
          'responder_id': 'r1',
          'responder_name': 'Ben',
          'status': 'active',
          'vehicle_name': 'Tanker 1',
        },
        {
          'id': 'd2',
          'responder_id': 'r2',
          'responder_name': 'Cy',
          'status': 'active',
          'vehicle_name': 'Tanker 1',
        },
        {
          'id': 'd3',
          'responder_id': 'r3',
          'responder_name': 'Dee',
          'status': 'active',
        },
      ];
      await pump(
        tester,
        Scaffold(
          body: LiveIncidentView(areaId: 'a3', me: me, api: api()),
        ),
      );
      expect(find.text('2 UNITS RESPONDING'), findsOneWidget);
      expect(find.text('Tanker 1 · 2 crew'), findsOneWidget);
      expect(find.text('Dee'), findsOneWidget);
      expect(find.text('No location yet'), findsNWidgets(2));

      await tester.dragUntilVisible(
        find.text('MARK FIRE OUT'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.tap(find.text('MARK FIRE OUT'));
      await settle(tester);
      expect(find.text('Mark Area 3.1 fire out?'), findsOneWidget);
      expect(
        find.textContaining('Tanker 1 and Dee stand down'),
        findsOneWidget,
      );
      await tester.tap(find.text('NOT YET, KEEP IT LIVE'));
      await settle(tester);
      expect(posted, isEmpty);
      await done(tester);
    });
  });

  group('codes', () {
    testWidgets('press on the live Area and say it was recorded', (
      tester,
    ) async {
      final feed = CoordinatorFeed(me: me, api: api());
      await feed.load();
      await pump(tester, Scaffold(body: CodesTab(feed: feed, focus: null)));
      expect(find.text('AREA 3.1'), findsOneWidget);
      await tester.tap(find.text('Water supply established'));
      await settle(tester);
      expect(posted.single.$2, '/fire-codes/c1/press');
      expect(posted.single.$3['area_id'], 'a3');
      expect(find.textContaining('Code A recorded at'), findsOneWidget);
      feed.dispose();
      await done(tester);
    });
  });

  group('my decisions', () {
    testWidgets('reads the audit log back, counted', (tester) async {
      audit = [
        {
          'id': 'l1',
          'action': 'incident.verify',
          'area_id': 'a1',
          'area_designation': 'Area 1.2',
          'actor_agency': 'fire_volunteer',
          'created_at': ago(5),
        },
        {
          'id': 'l2',
          'action': 'incident.resolve',
          'area_id': 'a9',
          'area_designation': 'Area 9.4',
          'created_at': ago(60 * 30),
        },
        {
          'id': 'l3',
          'action': 'incident.post_incident_report',
          'area_id': 'a9',
          'created_at': ago(60 * 29),
        },
        {
          'id': 'l4',
          'action': 'area.merge',
          'area_id': 'a7',
          'area_designation': 'Area 7.1',
          'metadata': {'merged_designation': 'Area 7.3'},
          'created_at': ago(60 * 50),
        },
        {
          'id': 'l5',
          'action': 'incident.self_dispatch',
          'area_id': 'a1',
          'created_at': ago(4),
        },
      ];
      final feed = CoordinatorFeed(me: me, api: api());
      await pump(tester, MyDecisionsScreen(feed: feed));
      expect(find.bySemanticsLabel('1 Accepted'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Fire out'), findsOneWidget);
      expect(find.bySemanticsLabel('0 Rejected'), findsOneWidget);
      expect(find.text('Area 1.2 · Accepted'), findsOneWidget);
      expect(find.text('Area 9.4 · Fire out, report filed'), findsOneWidget);
      expect(find.text('Area 7.3 · Merged into Area 7.1'), findsOneWidget);
      expect(find.text('4 SHOWN'), findsNothing);
      expect(find.text('3 SHOWN'), findsOneWidget);
      feed.dispose();
      await done(tester);
    });
  });

  group('the parts', () {
    test('the rail puts the owed report inside Fire out', () {
      expect(LifecycleRail.indexOf('reported'), 0);
      expect(LifecycleRail.indexOf('arrived'), 3);
      expect(LifecycleRail.indexOf('post_incident_report'), 4);
      expect(LifecycleRail.indexOf('closed'), 5);
    });

    test('alarm levels read as BFP says them', () {
      expect(alarmWord('first_alarm'), '1st alarm');
      expect(alarmWord(null), 'None yet');
    });
  });
}
