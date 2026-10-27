import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/location/place_names.dart';
import 'package:replit/screens/bfp/bfp_alarm_requests_screen.dart';
import 'package:replit/screens/coordinator/coordinator_shell.dart';
import 'package:replit/screens/coordinator/live_incident.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/alarm_ask_sheet.dart';
import 'package:replit/widgets/design.dart';

/// Alarm escalation on mobile (27 Oct 2026, PRD v14 §4.5.3: Fire Volunteer
/// requests, BFP executes). A Fire Volunteer coordinator asks BFP for a level
/// above the Area's and sees the request wait, then the answer; BFP finds it
/// in the Queue and in its own queue, sets or declines it, and is told
/// plainly when another phone answered first.
void main() {
  const fv = {
    'id': 'fv1',
    'role': 'sub_admin',
    'agency_type': 'fire_volunteer',
    'organization_name': 'Hercules Fire & Rescue',
    'full_name': 'R. Alonzo',
  };
  const bfp = {
    'id': 'bfp1',
    'role': 'sub_admin',
    'agency_type': 'bfp',
    'organization_name': 'BFP Pasay',
    'full_name': 'C. Reyes',
  };

  final now = DateTime.now().toUtc();
  String ago(int minutes) =>
      now.subtract(Duration(minutes: minutes)).toIso8601String();

  Map<String, dynamic> request(
    String id, {
    String level = 'second_alarm',
    String status = 'pending',
    String? areaLevel = 'first_alarm',
    int minutes = 2,
    String? notes,
  }) => {
    'id': id,
    'area_id': 'a3',
    'area_designation': '3.1',
    'area_status': 'en_route',
    'area_alarm_level': areaLevel,
    'area_centroid_lat': 14.5378,
    'area_centroid_lng': 121.0014,
    'requested_by': 'fv1',
    'requested_by_name': 'R. Alonzo',
    'requested_by_organization_name': 'Hercules Fire & Rescue',
    'requested_alarm_level': level,
    'justification': 'Spreading to the next house',
    'status': status,
    'reviewed_by_name': status == 'pending' ? null : 'C. Reyes',
    'reviewed_at': status == 'pending' ? null : ago(1),
    'review_notes': notes,
    'created_at': ago(minutes),
    'updated_at': ago(minutes),
  };

  late List<Map<String, dynamic>> requests;
  late List<Map<String, dynamic>> mine;
  late List<(String, String, Map<String, dynamic>)> calls;
  late Map<String, dynamic> incident;
  String? conflict;

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
    requests = [];
    mine = [];
    calls = [];
    conflict = null;
    incident = {
      'id': 'a3',
      'designation': '3.1',
      'status': 'en_route',
      'alarm_level': 'first_alarm',
      'centroid_lat': 14.5378,
      'centroid_lng': 121.0014,
      'report_count': 3,
      'confidence_score': 0.46,
      'confidence_band': 'medium',
      'reported_at': ago(5),
      'verified_at': ago(4),
      'requested_agencies': ['fire_volunteer'],
      'accepted_agencies': ['fire_volunteer'],
      'updated_at': ago(1),
    };
  });

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      http.Response json(Object body, [int code = 200]) =>
          http.Response(jsonEncode(body), code);
      if (req.method == 'POST') {
        final body = req.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(req.body) as Map<String, dynamic>;
        calls.add(('POST', path, body));
        final refused = conflict;
        if (refused != null && path.startsWith('/alarm-requests/')) {
          conflict = null;
          return json({'error': 'conflict', 'message': refused}, 409);
        }
        if (path == '/alarm-requests') {
          return json(
            request('new', level: body['requested_alarm_level'] as String),
            201,
          );
        }
        return json({'message': 'ok'});
      }
      calls.add(('GET', path, req.url.queryParameters));
      if (path == '/alarm-requests') {
        final status = req.url.queryParameters['status'];
        return json([
          for (final r in requests)
            if (status == null || r['status'] == status) r,
        ]);
      }
      if (path == '/alarm-requests/mine') return json(mine);
      if (path == '/incidents') return json([incident]);
      if (path == '/incidents/a3') return json(incident);
      return json([]);
    }),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(402, 1600);
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

  List<String> posted() => [
    for (final c in calls)
      if (c.$1 == 'POST') c.$2,
  ];

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  group("BFP's queue", () {
    testWidgets('shows what is asked, for where, by whom, newest first', (
      tester,
    ) async {
      requests = [
        request('q1', minutes: 5),
        request('q2', level: 'third_alarm', minutes: 1),
      ];
      await pump(tester, BfpAlarmRequestsScreen(api: api()));

      expect(find.text('ALARM REQUESTS'), findsOneWidget);
      expect(find.bySemanticsLabel('2 Waiting'), findsOneWidget);
      expect(find.bySemanticsLabel('0 Answered'), findsOneWidget);
      expect(
        find.text('Area 3.1 · F. Victor Street, Barangay 76, Pasay City'),
        findsNWidgets(2),
      );
      expect(find.text('En route · now at 1st alarm'), findsNWidgets(2));
      expect(
        find.text('Asked by R. Alonzo · Hercules Fire & Rescue · 5 min ago'),
        findsOneWidget,
      );
      expect(find.text('“Spreading to the next house”'), findsNWidgets(2));
      expect(
        find.descendant(of: find.byType(Tag), matching: find.text('Waiting')),
        findsNWidgets(2),
      );
      expect(
        top(tester, 'SET 3RD ALARM'),
        lessThan(top(tester, 'SET 2ND ALARM')),
        reason: 'the newest first',
      );
      await done(tester);
    });

    testWidgets('a tapped push puts its request first', (tester) async {
      requests = [
        request('q1', minutes: 5),
        request('q2', level: 'third_alarm', minutes: 1),
      ];
      await pump(
        tester,
        BfpAlarmRequestsScreen(api: api(), focusRequestId: 'q1'),
      );
      expect(
        top(tester, 'SET 2ND ALARM'),
        lessThan(top(tester, 'SET 3RD ALARM')),
      );
      await done(tester);
    });

    testWidgets('Set confirms, then sets the level', (tester) async {
      requests = [request('q1')];
      await pump(tester, BfpAlarmRequestsScreen(api: api()));
      await tester.tap(find.text('SET 2ND ALARM'));
      await settle(tester);
      expect(find.text('Set 2nd alarm?'), findsOneWidget);
      expect(posted(), isEmpty, reason: 'nothing until it is confirmed');
      await tester.tap(find.text('SET 2ND ALARM').last);
      await settle(tester);
      expect(posted(), ['/alarm-requests/q1/execute']);
      expect(find.text('Area 3.1 is now at 2nd alarm.'), findsOneWidget);
      await done(tester);
    });

    testWidgets('answered on another phone: says so, shows it as it is', (
      tester,
    ) async {
      requests = [request('q1')];
      conflict = 'This alarm request has already been reviewed.';
      await pump(tester, BfpAlarmRequestsScreen(api: api()));
      final reads = calls.where((c) => c.$2 == '/alarm-requests').length;
      await tester.tap(find.text('SET 2ND ALARM'));
      await settle(tester);
      await tester.tap(find.text('SET 2ND ALARM').last);
      await settle(tester);
      expect(
        find.text('This alarm request has already been reviewed.'),
        findsOneWidget,
      );
      expect(
        calls.where((c) => c.$2 == '/alarm-requests').length,
        greaterThan(reads),
        reason: 'the queue is read again',
      );
      await done(tester);
    });

    testWidgets('Decline asks why, optionally, and sends it', (tester) async {
      requests = [request('q1')];
      await pump(tester, BfpAlarmRequestsScreen(api: api()));
      await tester.tap(find.text('DECLINE'));
      await settle(tester);
      expect(find.text('Decline this request?'), findsOneWidget);
      expect(find.text('Reason (optional)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Contained at 1st alarm');
      await tester.tap(find.text('DECLINE').last);
      await settle(tester);
      expect(posted(), ['/alarm-requests/q1/reject']);
      expect(
        calls.lastWhere((c) => c.$1 == 'POST').$3['notes'],
        'Contained at 1st alarm',
      );
      await done(tester);
    });

    testWidgets('a request that would not raise the Area cannot be set', (
      tester,
    ) async {
      requests = [
        request('q1', level: 'first_alarm', areaLevel: 'second_alarm'),
      ];
      await pump(tester, BfpAlarmRequestsScreen(api: api()));
      expect(find.textContaining('already at 2nd alarm'), findsOneWidget);
      await tester.tap(find.text('SET 1ST ALARM'));
      await settle(tester);
      expect(find.text('Set 1st alarm?'), findsNothing);
      expect(posted(), isEmpty);
      expect(find.text('DECLINE'), findsOneWidget, reason: 'it can still go');
      await done(tester);
    });

    testWidgets('answered and taken-back requests read as such', (
      tester,
    ) async {
      requests = [
        request('q1', status: 'approved'),
        request('q2', status: 'rejected', notes: 'Contained'),
        request('q3', status: 'cancelled'),
      ];
      await pump(tester, BfpAlarmRequestsScreen(api: api()));
      expect(find.text('NOTHING WAITING'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('3 Answered'));
      await settle(tester);
      expect(find.text('Set'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.textContaining('Declined by C. Reyes'), findsOneWidget);
      expect(find.textContaining('Contained'), findsOneWidget);
      expect(find.text('DECLINE'), findsNothing, reason: 'nothing to answer');
      await done(tester);
    });

    testWidgets('the Queue tab shows BFP what waits on it', (tester) async {
      requests = [request('q1')];
      await pump(tester, CoordinatorShell(me: bfp, api: api()));
      expect(find.text('Area 3.1 asks for 2nd alarm'), findsOneWidget);
      expect(
        find.textContaining('R. Alonzo · Hercules Fire & Rescue'),
        findsOneWidget,
      );
      await tester.tap(find.text('Answer'));
      await settle(tester);
      expect(find.byType(BfpAlarmRequestsScreen), findsOneWidget);
      expect(find.text('SET 2ND ALARM'), findsOneWidget);
      await done(tester);
    });
  });

  group('the Fire Volunteer coordinator who asks', () {
    Future<void> openLive(WidgetTester tester) => pump(
      tester,
      Scaffold(
        body: LiveIncidentView(areaId: 'a3', me: fv, api: api()),
      ),
    );

    Future<void> showAlarmRow(WidgetTester tester) => tester.dragUntilVisible(
      find.text('Alarm level'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );

    Finder inSheet(String text) => find.descendant(
      of: find.byType(AlarmAskSheet),
      matching: find.text(text),
    );

    testWidgets('may ask only for a level above the Area, with why', (
      tester,
    ) async {
      await openLive(tester);
      await showAlarmRow(tester);
      expect(find.text('Set by BFP · ask them to raise it'), findsOneWidget);
      await tester.tap(find.text('Alarm level'));
      await settle(tester);

      expect(inSheet('Ask BFP to raise the alarm?'), findsOneWidget);
      expect(inSheet('Positive fire alarm'), findsNothing);
      expect(inSheet('1st alarm'), findsNothing, reason: 'the level it is at');
      for (final l in [
        '2nd alarm',
        '4th alarm',
        '5th alarm',
        'General alarm',
      ]) {
        expect(inSheet(l), findsOneWidget);
      }
      await tester.tap(inSheet('3rd alarm'));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlarmAskSheet),
          matching: find.byType(TextField),
        ),
        'Spreading to the next house',
      );
      await settle(tester);
      await tester.tap(inSheet('ASK FOR 3RD ALARM'));
      await settle(tester);
      expect(posted(), ['/alarm-requests']);
      expect(calls.lastWhere((c) => c.$1 == 'POST').$3, {
        'area_id': 'a3',
        'requested_alarm_level': 'third_alarm',
        'justification': 'Spreading to the next house',
      });
      expect(
        find.text('Asked BFP for 3rd alarm. You are told when they answer.'),
        findsOneWidget,
      );
      await done(tester);
    });

    testWidgets('sees the request wait, may take it back, then the answer', (
      tester,
    ) async {
      mine = [request('m1')];
      await openLive(tester);
      await showAlarmRow(tester);
      expect(
        find.text('You asked for 2nd alarm · waiting for BFP'),
        findsOneWidget,
      );

      await tester.tap(find.text('Alarm level'));
      await settle(tester);
      expect(inSheet('Waiting for BFP'), findsOneWidget);
      expect(inSheet('2nd alarm · asked'), findsOneWidget);
      await tester.tap(inSheet('Take it back'));
      await settle(tester);
      expect(posted(), ['/alarm-requests/m1/cancel']);

      // BFP answers on another phone; the next read shows it.
      mine = [request('m1', status: 'rejected', notes: 'Contained')];
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(
        find.text('BFP declined 2nd alarm 1 min ago: Contained'),
        findsOneWidget,
      );
      await done(tester);
    });
  });

  group('the notification', () {
    test("BFP's push opens its queue; the answer opens the Area", () {
      expect(targetFor('alarm_request', bfp), NotificationTarget.alarmRequests);
      expect(
        targetFor('alarm_request_answered', fv),
        NotificationTarget.staffIncident,
      );
      expect(
        targetFor('alarm_request_answered', const {'role': 'general_user'}),
        NotificationTarget.none,
      );
      expect(
        canOpen('alarm_request_answered', const {'area_id': 'a3'}),
        isTrue,
      );
      expect(
        fireAlertTypes.contains('alarm_request_answered'),
        isFalse,
        reason: 'an answer, not a new fire',
      );
    });
  });
}
