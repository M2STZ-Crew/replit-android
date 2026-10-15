import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/location/live_position.dart';
import 'package:replit/location/place_names.dart';
import 'package:replit/location/responder_tracker.dart';
import 'package:replit/screens/responder/responder_incident_screen.dart';
import 'package:replit/screens/responder/responder_shell.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/coordinator_kit.dart';
import 'package:replit/widgets/map_layers.dart';

/// A location service that answers but never moves: sharing can start, and
/// nothing is sent unless a test feeds it.
class _QuietGeo extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      StreamController<Position>().stream;
}

/// The Responder app (REPLIT (MAIN) 07): one bar with the same disc as every
/// role, Duty listing what needs the unit, the brief and "I am going", the
/// run from on the way to stood down, the field map's legend, and Profile.
void main() {
  const me = {
    'id': 'me',
    'role': 'response_team',
    'agency_type': 'fire_volunteer',
    'organization_name': 'Tanker 1',
    'full_name': 'J. Pineda',
  };

  final now = DateTime.now().toUtc();
  String ago(int minutes) =>
      now.subtract(Duration(minutes: minutes)).toIso8601String();

  Map<String, dynamic> area(String id, String designation, String status) => {
    'id': id,
    'designation': designation,
    'status': status,
    'centroid_lat': 14.5378,
    'centroid_lng': 121.0014,
    'report_count': 3,
    'confidence_score': 0.46,
    'confidence_band': 'medium',
    'active_dispatch_count': status == 'en_route' ? 1 : 0,
    'reported_at': ago(3),
    'verified_at': status == 'reported' ? null : ago(2),
    'arrived_at': const {'arrived', 'fire_out'}.contains(status)
        ? ago(1)
        : null,
    'resolved_at': status == 'fire_out' ? ago(0) : null,
    'requested_agencies': ['fire_volunteer', 'medical'],
    'accepted_agencies': status == 'reported' ? [] : ['fire_volunteer'],
  };

  late List<String> posted;
  late Map<String, Map<String, dynamic>> incidents;
  late List<Map<String, dynamic>> dispatches;

  setUpAll(() {
    // The maps' tile cache asks for a cache folder; tests have no plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _QuietGeo();
    PlaceNames.clear();
    PlaceNames.lookUp = (_, _) async => const PlaceName(
      street: 'F. Victor Street',
      place: 'Barangay 76, Pasay City',
    );
    posted = [];
    dispatches = [];
    incidents = {
      'a1': area('a1', 'Area 1.2', 'reported'),
      'a2': area('a2', 'Area 2.1', 'verified'),
    };
  });

  tearDown(() => ResponderTracker.instance.stop());

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      http.Response json(Object body) => http.Response(jsonEncode(body), 200);
      if (req.method == 'POST') {
        posted.add(path);
        final id = path.split('/').length > 2 ? path.split('/')[2] : '';
        if (path.endsWith('/verify')) incidents[id]?['status'] = 'verified';
        if (path.endsWith('/self-dispatch')) {
          incidents[id]?['status'] = 'en_route';
          dispatches.add({
            'id': 'd-$id',
            'responder_id': 'me',
            'status': 'active',
          });
        }
        return json(incidents[id] ?? {'message': 'ok'});
      }
      if (path == '/incidents') return json(incidents.values.toList());
      if (path == '/incidents/stats') {
        return json({
          'active_incidents': 2,
          'pending_verify': 1,
          'units_deployed': 3,
          'units_standby': 4,
          'pending_reports': 0,
        });
      }
      if (path.endsWith('/dispatches')) return json(dispatches);
      if (path.endsWith('/reports')) {
        return json([
          {
            'id': 'r1',
            'reporter_name': 'Ana',
            'photo_url': null,
            'device_lat': 14.5378,
            'device_lng': 121.0014,
            'user_verified_percent': 100,
            'selected_agencies': ['fire_volunteer'],
            'created_at': ago(3),
          },
        ]);
      }
      if (path == '/fire-codes') {
        return json([
          {'id': 'c6', 'code_number': 'FC-6'},
          {'id': 'c7', 'code_number': 'FC-7'},
          {'id': 'c3', 'code_number': 'FC-3'},
        ]);
      }
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

  Future<ApiClient> pump(
    WidgetTester tester,
    Widget Function(ApiClient) home,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = api();
    ResponderTracker.instance.api = client;
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: home(client)),
    );
    await settle(tester);
    return client;
  }

  Future<void> shell(WidgetTester tester) =>
      pump(tester, (client) => ResponderShell(me: me, api: client));

  /// Tears the screen down so its polls stop before the test ends.
  Future<void> done(WidgetTester tester) async {
    await ResponderTracker.instance.stop();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^$label, tab ')));
    await settle(tester);
  }

  group('the bar', () {
    testWidgets('Duty, Map, the RUN disc, Alerts and Profile — no Runs', (
      tester,
    ) async {
      await shell(tester);
      for (final (i, label) in ['Duty', 'Map', 'Alerts', 'Profile'].indexed) {
        final position = i < 2 ? i + 1 : i + 2;
        expect(
          find.bySemanticsLabel('$label, tab $position of 5'),
          findsOneWidget,
          reason: label,
        );
      }
      expect(
        find.bySemanticsLabel('Run — the Area you are going to'),
        findsOneWidget,
      );
      expect(
        find.text('Runs'),
        findsNothing,
        reason: 'no endpoint lists a responder past runs (R12 is standby)',
      );
      await done(tester);
    });
  });

  group('Duty', () {
    testWidgets('what needs the unit, newest first, and the counters', (
      tester,
    ) async {
      await shell(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('TANKER 1 — FIRE VOLUNTEER'), findsOneWidget);
      expect(find.text('DUTY'), findsOneWidget);
      expect(find.text('Location sharing is off'), findsOneWidget);
      expect(find.text('NEEDS A UNIT'), findsOneWidget);
      expect(find.text('2 AREAS'), findsOneWidget);
      expect(find.text('REVIEW'), findsNWidgets(2));

      // Below the fold: the counters /incidents/stats returns, none invented.
      for (final label in ['PASAY NOW', 'LIVE NOW', 'TO VERIFY', 'UNITS OUT']) {
        expect(find.text(label, skipOffstage: false), findsOneWidget);
      }
      await done(tester);
    });

    testWidgets('nothing waiting says what will arrive (R02)', (tester) async {
      incidents.clear();
      await shell(tester);
      expect(find.text('NO AREA NEEDS TANKER 1'), findsOneWidget);
      expect(
        find.textContaining('When an Area asks for Fire Volunteer'),
        findsOneWidget,
      );
      expect(find.text('REVIEW'), findsNothing);
      await done(tester);
    });
  });

  group('the brief', () {
    testWidgets('a Reported Area: I am going verifies, then responds (R03, '
        'R04)', (tester) async {
      await shell(tester);
      await tester.tap(find.text('REVIEW').first);
      await settle(tester);
      expect(find.text('AREA 1.2'), findsOneWidget);
      expect(find.text('F. VICTOR STREET'), findsOneWidget);
      expect(find.text('3 residents'), findsOneWidget);
      expect(find.text('Fire, Medical', skipOffstage: false), findsOneWidget);
      expect(find.text('I AM GOING'), findsOneWidget);
      expect(find.text('VERIFY, WITHOUT GOING'), findsOneWidget);

      await tester.tap(find.text('I AM GOING'));
      await settle(tester);
      expect(find.text('Go to Area 1.2?'), findsOneWidget);
      expect(find.textContaining('You go as Tanker 1'), findsOneWidget);
      expect(
        find.textContaining('This Area is still Reported'),
        findsOneWidget,
      );
      await tester.tap(find.text('I AM GOING').last);
      await settle(tester);
      expect(posted, ['/incidents/a1/verify', '/incidents/a1/self-dispatch']);
      await done(tester);
    });

    testWidgets('Reports opens every report', (tester) async {
      await pump(
        tester,
        (client) => ResponderIncidentScreen(
          incidentId: 'a2',
          myId: 'me',
          agency: 'fire_volunteer',
          unit: 'Tanker 1',
          api: client,
        ),
      );
      expect(find.text('BACK TO DUTY'), findsOneWidget);
      await tester.tap(find.text('Reports'));
      await settle(tester);
      expect(find.text('1 report'), findsOneWidget);
      expect(find.text('Resident · 100% verified'), findsOneWidget);
      await done(tester);
    });
  });

  group('the run', () {
    Future<void> run(WidgetTester tester, String status, {bool active = true}) {
      incidents['a3'] = area('a3', 'Area 3.1', status);
      dispatches.add({
        'id': 'd1',
        'responder_id': 'me',
        'status': active ? 'active' : 'completed',
        'vehicle_name': 'Tanker 1',
        'crew_role': 'driver',
        'responder_name': 'J. Pineda',
      });
      return pump(
        tester,
        (client) => ResponderIncidentScreen(
          incidentId: 'a3',
          myId: 'me',
          agency: 'fire_volunteer',
          unit: 'Tanker 1',
          api: client,
        ),
      ).then((_) {});
    }

    testWidgets('on the way: navigate, mark arrived, and the codes', (
      tester,
    ) async {
      await run(tester, 'en_route');
      expect(find.text('AREA 3.1 — EN ROUTE'), findsOneWidget);
      expect(find.text('ON THE WAY'), findsOneWidget);
      expect(find.text('NAVIGATE'), findsOneWidget);
      await tester.tap(find.text('MARK ARRIVED'));
      await settle(tester);
      expect(find.text('Mark arrived?'), findsOneWidget);
      await tester.tap(find.text('MARK ARRIVED').last);
      await settle(tester);
      expect(posted, ['/incidents/a3/arrived']);
      // Further down: the unit and the codes a crew sends command.
      for (final row in [
        'Tanker 1',
        'Need water',
        'Need assistance',
        'Escalate to BFP',
      ]) {
        await tester.scrollUntilVisible(find.text(row), 150);
        expect(find.text(row), findsOneWidget, reason: row);
      }
      await done(tester);
    });

    testWidgets('on scene: what happens next, and telling command it is out '
        '(R09)', (tester) async {
      await run(tester, 'arrived');
      expect(find.text('ON SCENE'), findsOneWidget);
      expect(find.text('WHAT HAPPENS NEXT'), findsOneWidget);
      expect(find.textContaining('Arrived '), findsOneWidget);
      expect(find.text('Your location is still shared'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Fire is out'), 200);
      await tester.tap(find.text('Fire is out'));
      await settle(tester);
      expect(posted, ['/fire-codes/c3/press']);
      await done(tester);
    });

    testWidgets('stood down after fire out (R10)', (tester) async {
      await run(tester, 'fire_out', active: false);
      expect(find.text('STOOD DOWN'), findsOneWidget);
      expect(find.text('Location sharing stopped'), findsOneWidget);
      expect(find.text('WHAT HAPPENED'), findsOneWidget);
      expect(find.text('Need water'), findsNothing, reason: 'the run is over');
      await tester.scrollUntilVisible(find.text('BACK TO DUTY'), 200);
      expect(find.text('BACK TO DUTY'), findsOneWidget);
      await done(tester);
    });

    testWidgets('RUN with no run says how one starts', (tester) async {
      await shell(tester);
      await tester.tap(
        find.bySemanticsLabel('Run — the Area you are going to'),
      );
      await settle(tester);
      expect(find.text('NO RUN'), findsOneWidget);
      await tester.tap(find.text('OPEN DUTY'));
      await settle(tester);
      expect(find.text('NEEDS A UNIT'), findsOneWidget);
      await done(tester);
    });
  });

  group('the field map', () {
    testWidgets('its legend: Areas coral, risk zones red, as every map', (
      tester,
    ) async {
      await shell(tester);
      await tab(tester, 'Map');
      // The chip row scrolls sideways; the later chips are past its edge.
      MapLayerChip chip(String label) => tester.widget<MapLayerChip>(
        find.byWidgetPredicate(
          (w) => w is MapLayerChip && w.label == label,
          skipOffstage: false,
        ),
      );
      final pal = AppPalette.dark;
      expect(chip('Areas').tone, pal.accentInk);
      expect(chip('Areas').on, isTrue);
      expect(chip('Hydrants').tone, pal.water);
      expect(chip('Shelters').tone, pal.ok);
      expect(chip('Risk zones').tone, pal.live);

      final circles = tester
          .widget<CircleLayer>(find.byType(CircleLayer))
          .circles;
      expect(circles, isNotEmpty);
      expect(circles.first.color, pal.accentInk.withValues(alpha: 0.10));
      expect(find.text('TANKER 1'), findsOneWidget);
      expect(find.text('Location sharing is off'), findsOneWidget);
      expect(find.text('AROUND YOU'), findsOneWidget);
      await done(tester);
    });

    testWidgets('around you: what is near, nearest first', (tester) async {
      LivePosition.instance.offer(const LatLng(14.5378, 121.0014));
      await shell(tester);
      await tab(tester, 'Map');
      expect(find.text('WITHIN 500 M'), findsOneWidget);
      await done(tester);
    });
  });

  group('Profile', () {
    testWidgets('settings, and what a responder can do (R13, R14)', (
      tester,
    ) async {
      await shell(tester);
      await tab(tester, 'Profile');
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Responder — Fire Volunteer, Tanker 1'), findsOneWidget);
      expect(find.text('Incident sounds'), findsOneWidget);
      expect(find.text('Voice directions'), findsOneWidget);
      expect(find.text('Map rotation'), findsOneWidget);
      expect(
        find.text('Affiliate registration'),
        findsNothing,
        reason: 'no registration URL yet (standby)',
      );
      // The row may sit under the bar at this size; open it as a tap would.
      tester
          .widget<ListRow>(find.widgetWithText(ListRow, 'What you can do'))
          .onTap!();
      await settle(tester);
      expect(find.text('WHAT YOU CAN DO'), findsOneWidget);
      expect(find.text('Reject an Area', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Coordinators only', skipOffstage: false),
        findsOneWidget,
      );
      await done(tester);
    });
  });
}
