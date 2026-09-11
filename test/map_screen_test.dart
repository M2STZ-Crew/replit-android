import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/report_queue.dart';
import 'package:replit/models/hotline.dart';
import 'package:replit/screens/map_screen.dart';
import 'package:replit/theme.dart';

/// The citizen map ("04 Map" and "05 Map — offline queue"): what the sheet
/// says with signal, and what it says without.

/// A phone standing at Pasay City centre with a 4 m fix.
class _HereGeo extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 14.5378,
    longitude: 121.0014,
    timestamp: DateTime.now(),
    accuracy: 4,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  late bool reachable;
  late Directory dir;

  // One area ~350 m away, one ~5 km away: only the first is "near you".
  final areas = [
    {
      'id': 'near',
      'designation': 'Area 1.2',
      'status': 'pending',
      'centroid_lat': 14.5410,
      'centroid_lng': 121.0014,
      'report_count': 1,
      'confidence_band': 'low',
    },
    {
      'id': 'far',
      'designation': 'Area 9.1',
      'status': 'dispatched',
      'centroid_lat': 14.5830,
      'centroid_lng': 121.0014,
      'report_count': 3,
      'confidence_band': 'medium',
    },
  ];

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      if (!reachable) throw http.ClientException('no route to host');
      final path = req.url.path;
      if (path.endsWith('/areas')) return http.Response(jsonEncode(areas), 200);
      if (path.endsWith('/map/evacuation-sites')) {
        return http.Response(
          jsonEncode([
            {
              'id': 's1',
              'name': 'Pasay Sports Complex',
              'latitude': 14.5390,
              'longitude': 121.0030,
              'capacity': 480,
              'city': 'Pasay City',
              'outside_pasay': false,
              'is_active': true,
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    }),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'sound.report_sent': false});
    GeolocatorPlatform.instance = _HereGeo();
    reachable = true;
    dir = Directory.systemTemp.createTempSync('map_screen_test');
    ReportQueue.instance.reset();
    ReportQueue.instance.configureForTest(api: api(), dir: dir);
  });

  tearDown(() {
    ReportQueue.instance.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: MapScreen(api: api()),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('with signal: active areas within 1.5 km, at ${scale}x', (
      tester,
    ) async {
      await pump(tester, scale: scale);
      expect(tester.takeException(), isNull);

      expect(find.text('ACTIVE AREAS NEAR YOU'), findsOneWidget);
      expect(find.text('WITHIN 1.5 KM'), findsOneWidget);
      expect(find.text('Area 1.2'), findsOneWidget);
      expect(find.text('Area 9.1'), findsNothing, reason: 'about 5 km away');
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('1 REPORT'), findsOneWidget);
      expect(find.text('Evacuation site open'), findsOneWidget);
      expect(find.text('SPACE FOR 480'), findsOneWidget);
      expect(find.text('GPS accurate to 4 m'), findsOneWidget);
      expect(find.text('WATCHING PASAY'), findsOneWidget);
    });

    testWidgets(
      'no signal, one report queued: saved on this phone, at ${scale}x',
      (tester) async {
        await tester.runAsync(
          () => ReportQueue.instance.enqueue(
            lat: 14.5378,
            lng: 121.0014,
            agencies: const ['fire_volunteer'],
            notes: '',
            photoBytes: const [0xFF, 0xD8, 0xFF, 0xD9],
          ),
        );
        reachable = false;

        await pump(tester, scale: scale);
        expect(tester.takeException(), isNull);

        expect(find.text('1 REPORT WAITING'), findsOneWidget);
        expect(find.text('NO SIGNAL — QUEUED'), findsOneWidget);
        expect(find.text('SAVED ON THIS PHONE'), findsOneWidget);
        expect(find.text('Fire report'), findsOneWidget);
        expect(find.text('QUEUED'), findsOneWidget);
        expect(find.text('All ${kHotlines.length} hotlines'), findsOneWidget);
        expect(find.text('TRY NOW'), findsOneWidget);
        expect(find.text('CALL 911'), findsOneWidget);
        // The queue card takes the layer chips' place.
        expect(find.text('HYDRANTS'), findsNothing);
        ReportQueue.instance.reset();
      },
    );
  }
}
