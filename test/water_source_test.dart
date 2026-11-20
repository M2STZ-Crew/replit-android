import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/models/water_source.dart';
import 'package:replit/navigation/nav_route.dart';
import 'package:replit/navigation/routing_service.dart';
import 'package:replit/navigation/voice_guide.dart';
import 'package:replit/screens/directions_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/app_icons.dart';
import 'package:replit/widgets/coordinator_kit.dart';
import 'package:replit/widgets/map_marker.dart';
import 'package:replit/widgets/shelter_sheet.dart';
import 'package:replit/widgets/water_source_sheet.dart';

import 'navigation_test.dart' as nt;

/// v1.12.55 (backend v1.12.43), 19 Nov 2026: water sources from the staff
/// map. Fire Volunteer and BFP coordinators and responders set a hydrant's
/// status at once; their coordinators add, change and switch off sources for
/// an Admin to approve; every staff member gets directions, by car.
Map<String, dynamic> _hydrant() => {
  'id': 'h1',
  'code': 'H-17',
  'latitude': 14.5378,
  'longitude': 121.0014,
  'address': 'F. Victor Street, Pasay',
  'bfp_status': 'operational',
  'effective_status': 'low_pressure',
  'ground_truth_at': DateTime.now()
      .subtract(const Duration(hours: 2))
      .toUtc()
      .toIso8601String(),
  'checked_by_name': 'Ana Cruz',
  'checked_by_org': 'BFP Pasay',
};

Map<String, dynamic> _water() => {
  'id': 'w1',
  'name': 'Tripa de Gallina',
  'water_type': 'river',
  'latitude': 14.536,
  'longitude': 121.004,
  'is_accessible': true,
};

WaterPowers _as(String role, String? agency) =>
    WaterPowers.of({'role': role, 'agency_type': agency});

/// An API that answers every request with [reply], and keeps what was sent.
({ApiClient api, List<http.Request> sent}) _server([
  Map<String, dynamic> reply = const {'id': 'r1', 'status': 'pending'},
]) {
  final sent = <http.Request>[];
  final api = ApiClient(
    client: MockClient((request) async {
      sent.add(request);
      return http.Response(jsonEncode(reply), 201);
    }),
  );
  return (api: api, sent: sent);
}

/// A screen with a button that runs [open], pressed.
Future<void> _open(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A phone at H-17 with a 5 m fix.
class _Geo extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 14.5378,
    longitude: 121.0014,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _Voice extends VoiceGuide {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.instance.clear();
    Session.instance.accessToken = 'token';
  });

  test('who may do what with water', () {
    final fv = _as('sub_admin', 'fire_volunteer');
    expect((fv.setStatus, fv.propose), (true, true));
    final bfp = _as('sub_admin', 'bfp');
    expect((bfp.setStatus, bfp.propose), (true, true));
    final crew = _as('response_team', 'bfp');
    expect((crew.setStatus, crew.propose), (true, false));
    for (final (role, agency) in [
      ('sub_admin', 'police'),
      ('response_team', 'medical'),
      ('general_user', null),
    ]) {
      final none = _as(role, agency);
      expect((none.setStatus, none.propose), (false, false), reason: role);
    }
  });

  test('a source reads its kind, status and who checked it', () {
    final hydrant = WaterSource.from(WaterKind.hydrant, _hydrant())!;
    expect(hydrant.title, 'H-17');
    expect(hydrant.status, WaterStatus.lowPressure);
    expect(hydrant.status!.word, 'Low pressure');
    expect(hydrant.checkedBy, 'BFP Pasay');
    final water = WaterSource.from(WaterKind.water, _water())!;
    expect((water.title, water.status), ('Tripa de Gallina', null));
    expect(WaterSource.from(WaterKind.water, {'id': 'w2'}), isNull);
    expect(WaterKind.ofLayer('cisterns'), WaterKind.cistern);
    expect(WaterKind.ofLayer('evac'), isNull);
    expect(WaterStatus.parse('something new'), WaterStatus.unknown);
    expect(
      WaterStatus.reportable.map((s) => s.word),
      ['Working', 'Low pressure', 'Broken', 'No access', 'Under maintenance'],
    );
  });

  for (final (who, powers, buttons) in [
    ('a police coordinator', _as('sub_admin', 'police'), ['DIRECTIONS']),
    (
      'a BFP responder',
      _as('response_team', 'bfp'),
      ['DIRECTIONS', 'UPDATE STATUS'],
    ),
    (
      'a Fire Volunteer coordinator',
      _as('sub_admin', 'fire_volunteer'),
      ['DIRECTIONS', 'UPDATE STATUS', 'EDIT DETAILS', 'SWITCH OFF'],
    ),
  ]) {
    testWidgets('the hydrant sheet offers $who only what they may do', (
      tester,
    ) async {
      final source = WaterSource.from(WaterKind.hydrant, _hydrant())!;
      await _open(
        tester,
        (context) => showFrameSheet<WaterAction>(
          context,
          builder: (_) => WaterSourceSheet(source: source, powers: powers),
        ),
      );
      expect(find.text('Low pressure'), findsOneWidget);
      expect(find.text('Checked 2 hours ago by BFP Pasay'), findsOneWidget);
      for (final label in [
        'DIRECTIONS',
        'UPDATE STATUS',
        'EDIT DETAILS',
        'SWITCH OFF',
      ]) {
        expect(
          find.text(label),
          buttons.contains(label) ? findsOneWidget : findsNothing,
          reason: label,
        );
      }
    });
  }

  testWidgets('a BFP responder sets a hydrant to No access, at once', (
    tester,
  ) async {
    final server = _server({..._hydrant(), 'effective_status': 'no_access'});
    bool? changed;
    await _open(tester, (context) async {
      changed = await openWaterSource(
        context,
        source: WaterSource.from(WaterKind.hydrant, _hydrant())!,
        powers: _as('response_team', 'bfp'),
        api: server.api,
      );
    });
    await _tap(tester, 'UPDATE STATUS');
    expect(find.text('How is this hydrant?'), findsOneWidget);
    expect(find.text('CHOOSE A STATUS'), findsOneWidget);
    await _tap(tester, 'No access');
    await tester.enterText(find.byType(TextField), 'A car parked on it.');
    await _tap(tester, 'SAVE: NO ACCESS');

    final request = server.sent.single;
    expect(request.url.path, endsWith('/map/hydrants/h1/ground-truth'));
    expect(jsonDecode(request.body), {
      'status': 'no_access',
      'notes': 'A car parked on it.',
    });
    expect(find.text('Status saved. It is on every map now.'), findsOneWidget);
    expect(changed, isTrue);
  });

  testWidgets('switching water off says why and waits for an Admin', (
    tester,
  ) async {
    final server = _server();
    await _open(tester, (context) async {
      await openWaterSource(
        context,
        source: WaterSource.from(WaterKind.water, _water())!,
        powers: _as('sub_admin', 'fire_volunteer'),
        api: server.api,
      );
    });
    expect(find.text('UPDATE STATUS'), findsNothing, reason: 'hydrants only');
    await _tap(tester, 'SWITCH OFF');
    expect(find.text('SAY WHY TO SEND'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Dried up since October.');
    await tester.pump();
    await _tap(tester, 'SEND FOR APPROVAL');

    final request = server.sent.single;
    expect(request.url.path, endsWith('/map-layer-requests'));
    expect(jsonDecode(request.body), {
      'layer_type': 'bodies_of_water',
      'operation': 'update',
      'target_id': 'w1',
      'proposed_data': {'is_active': false},
      'reason': 'Dried up since October.',
    });
    expect(
      find.text('Sent to an Admin to approve. You will be told the answer.'),
      findsOneWidget,
    );
  });

  testWidgets('a new body of water at the pin needs its name', (tester) async {
    final server = _server();
    bool? sent;
    await _open(tester, (context) async {
      sent = await proposeWaterSource(
        context,
        point: const LatLng(14.539, 121.002),
        api: server.api,
      );
    });
    await _tap(tester, 'Body of water');
    expect(find.text('NAME IT TO SEND'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Estero de Pasay');
    await tester.pump();
    await _tap(tester, 'SEND FOR APPROVAL');

    expect(jsonDecode(server.sent.single.body), {
      'layer_type': 'bodies_of_water',
      'operation': 'create',
      'proposed_data': {
        'latitude': 14.539,
        'longitude': 121.002,
        'name': 'Estero de Pasay',
        'is_accessible': true,
      },
    });
    expect(sent, isTrue);
  });

  testWidgets('an edit sends only what changed', (tester) async {
    final server = _server();
    await _open(
      tester,
      (context) => showFrameSheet<bool>(
        context,
        builder: (_) => WaterDetailsSheet.edit(
          source: WaterSource.from(WaterKind.hydrant, _hydrant())!,
          api: server.api,
        ),
      ),
    );
    expect(find.text('CHANGE SOMETHING TO SEND'), findsOneWidget);
    // Code, then address, then the note for the Admin.
    await tester.enterText(
      find.byType(TextField).at(1),
      'F. Victor Street corner Taft Avenue',
    );
    await tester.pump();
    await _tap(tester, 'SEND FOR APPROVAL');

    expect(jsonDecode(server.sent.single.body), {
      'layer_type': 'hydrant',
      'operation': 'update',
      'target_id': 'h1',
      'proposed_data': {'address': 'F. Victor Street corner Taft Avenue'},
    });
  });

  testWidgets('staff tap a shelter for its details and car directions', (
    tester,
  ) async {
    GeolocatorPlatform.instance = _Geo();
    await _open(
      tester,
      (context) => openStaffShelter(context, {
        'id': 's1',
        'name': 'Pasay Sports Complex',
        'latitude': 14.5450,
        'longitude': 121.0014,
        'address': 'P. Burgos Street',
        'city': 'Pasay City',
        'capacity': 300,
        'outside_pasay': false,
      }),
    );
    expect(find.text('Pasay Sports Complex'), findsOneWidget);
    expect(find.text('P. Burgos Street, Pasay City'), findsOneWidget);
    expect(find.text('300 people'), findsOneWidget);
    await tester.tap(find.text('DIRECTIONS'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final screen = tester.widget<DirectionsScreen>(
      find.byType(DirectionsScreen),
    );
    expect(screen.to, DirectionsTo.place);
    expect(screen.placeKind, MapMarkerKind.shelter);
    expect(screen.destName, 'Pasay Sports Complex');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('directions to a hydrant are by car', (tester) async {
    GeolocatorPlatform.instance = _Geo();
    Future<RouteSet> fetch(LatLng from, LatLng to, {double? headingDeg}) async =>
        RouteSet(
          routes: parseRoutes(
            nt.answer([
              (
                points: [from, to],
                steps: [
                  nt.step('depart', from, distance: 800, duration: 120),
                  nt.step('arrive', to),
                ],
                duration: 120,
                summary: '',
                congestion: null,
                typical: null,
              ),
            ]),
          ),
          provider: 'mapbox',
          trafficAware: true,
        );
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: DirectionsScreen(
          destLat: 14.5450,
          destLng: 121.0014,
          destName: 'H-17',
          to: DirectionsTo.place,
          placeKind: MapMarkerKind.hydrant,
          fetchRoute: fetch,
          voice: _Voice(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('DRIVING DIRECTIONS'), findsOneWidget);
    expect(find.byIcon(AppIcons.directionsCar), findsWidgets);
    expect(find.byIcon(AppIcons.directionsWalk), findsNothing);
    expect(find.text('ROUTE TO SAFETY'), findsNothing);
  });
}
