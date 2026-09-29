import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/live_hub.dart';
import 'package:replit/api/report_queue.dart';
import 'package:replit/screens/map_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

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

/// `map:areas`, driven by the test.
class FakeMapFeed implements LiveFeed {
  final ValueNotifier<bool> liveNow = ValueNotifier(false);
  final StreamController<Map<String, dynamic>> pushes =
      StreamController.broadcast();

  @override
  ValueListenable<bool> get live => liveNow;

  @override
  ValueListenable<bool> get denied => ValueNotifier(false);

  @override
  Stream<Map<String, dynamic>> get messages => pushes.stream;

  @override
  void start() {}

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> area(
  String id,
  String designation, {
  String status = 'reported',
  double north = 350,
}) => {
  'id': id,
  'designation': designation,
  'status': status,
  'centroid_lat': 14.5378 + north / 111195,
  'centroid_lng': 121.0014,
  'report_count': 1,
  'confidence_score': 0.2,
  'confidence_band': 'low',
  'alarm_level': null,
  'reported_at': DateTime.now().toUtc().toIso8601String(),
  'updated_at': DateTime.now().toUtc().toIso8601String(),
};

/// The citizen map, live: the server's changes on screen without waiting for
/// the next read.
void main() {
  late Directory dir;
  late int areaReads;
  late List<Map<String, dynamic>> served;

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      if (req.url.path.endsWith('/areas')) {
        areaReads++;
        return http.Response(jsonEncode(served), 200);
      }
      return http.Response('[]', 200);
    }),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'sound.report_sent': false});
    GeolocatorPlatform.instance = _HereGeo();
    areaReads = 0;
    served = [area('near', 'Area 1.2')];
    dir = Directory.systemTemp.createTempSync('map_live_test');
    ReportQueue.instance.reset();
    ReportQueue.instance.configureForTest(api: api(), dir: dir);
  });

  tearDown(() {
    ReportQueue.instance.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, FakeMapFeed feed) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MapScreen(api: api(), feed: feed),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> push(
    WidgetTester tester,
    FakeMapFeed feed,
    Map<String, dynamic> a, {
    bool active = true,
  }) async {
    feed.pushes.add({
      'type': 'area',
      'channel': 'map:areas',
      'active': active,
      'area': a,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a new incident appears the moment the server says so', (
    tester,
  ) async {
    final feed = FakeMapFeed()..liveNow.value = true;
    await pump(tester, feed);
    expect(find.text('Area 3'), findsNothing);
    final reads = areaReads;

    await push(tester, feed, area('new', 'Area 3', north: 150));
    expect(find.text('Area 3'), findsOneWidget);
    expect(areaReads, reads, reason: 'no read needed: the message had it');
  });

  testWidgets('a status change moves it on in place', (tester) async {
    final feed = FakeMapFeed()..liveNow.value = true;
    await pump(tester, feed);
    expect(find.text('REPORTED'), findsOneWidget);

    await push(tester, feed, area('near', 'Area 1.2', status: 'en_route'));
    expect(find.text('LIVE'), findsOneWidget, reason: 'past reported');
    expect(find.text('REPORTED'), findsNothing);
    expect(find.text('Area 1.2'), findsOneWidget, reason: 'updated, not added');
  });

  testWidgets('an incident that ends leaves the map', (tester) async {
    final feed = FakeMapFeed()..liveNow.value = true;
    await pump(tester, feed);
    expect(find.text('Area 1.2'), findsOneWidget);

    await push(
      tester,
      feed,
      area('near', 'Area 1.2', status: 'fire_out'),
      active: false,
    );
    expect(find.text('Area 1.2'), findsNothing);
  });

  testWidgets('a live dot shows while the socket is up', (tester) async {
    final feed = FakeMapFeed();
    await pump(tester, feed);
    final idle = find.byType(LiveDot).evaluate().length;

    feed.liveNow.value = true;
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LiveDot).evaluate().length, idle + 1);

    feed.liveNow.value = false;
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LiveDot).evaluate().length, idle);
  });

  testWidgets('live, the full read drops to once a minute; each (re)connect '
      'catches up once', (tester) async {
    final feed = FakeMapFeed();
    await pump(tester, feed);
    final start = areaReads;

    await tester.pump(const Duration(seconds: 15));
    expect(areaReads, start + 1, reason: 'down: every 15 s');

    feed.liveNow.value = true;
    await tester.pump(const Duration(milliseconds: 50));
    expect(areaReads, start + 2, reason: 'connected: one read to catch up');

    await tester.pump(const Duration(seconds: 30));
    expect(areaReads, start + 2, reason: 'live: nothing for a while');
    await tester.pump(const Duration(seconds: 15));
    expect(areaReads, start + 3, reason: 'the once-a-minute safety net');
  });
}
