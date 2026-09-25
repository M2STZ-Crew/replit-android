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
import 'package:replit/api/session.dart';
import 'package:replit/location/sos_location.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/screens/home_screen.dart';
import 'package:replit/screens/map_screen.dart';
import 'package:replit/screens/report_status_screen.dart';
import 'package:replit/screens/sos_report_screen.dart';
import 'package:replit/theme.dart';

import 'citizen_flow_test.dart' show kPixel;

/// One report at a time. While a resident's report is live they cannot start
/// another — not from the dial, not from a form left open, not from a phone
/// that lost track of it — and once a report is sent, Back from it is the map,
/// never the dial or the filled-in form it came from.

/// A phone that knows where it is at once.
class _Here extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 14.5378,
    longitude: 121.0014,
    timestamp: DateTime.now(),
    accuracy: 6,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  const me = 'm.reyes@gmail.com';
  late Directory dir;
  late List<http.Request> sent;

  ActiveReport out() => ActiveReport(
    owner: me,
    reportId: 'r1',
    areaId: 'a1',
    designation: 'Area 1.2',
    lat: 14.5378,
    lng: 121.0014,
    submittedAt: DateTime.now(),
    agencies: const ['fire_volunteer'],
  );

  /// The server: [submit] answers POST /reports/submit; /reports/mine lists
  /// [mine]; anything else gets an empty list.
  ApiClient server({
    http.Response Function()? submit,
    List<Map<String, dynamic>> mine = const [],
  }) => ApiClient(
    client: MockClient((req) async {
      sent.add(req);
      final path = req.url.path;
      if (path.endsWith('/reports/submit')) {
        return submit?.call() ?? http.Response('{}', 500);
      }
      if (path.endsWith('/reports/mine')) {
        return http.Response(jsonEncode(mine), 200);
      }
      return http.Response('[]', 200);
    }),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'map_coach_seen_v1': true});
    ActiveReportStore.reset();
    Session.instance.email = me;
    GeolocatorPlatform.instance = _Here();
    SosLocation.instance.reset();
    sent = [];
    dir = Directory.systemTemp.createTempSync('one_report_test');
    ReportQueue.instance.reset();
    ReportQueue.instance.configureForTest(
      api: ApiClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
      ),
      dir: dir,
    );
  });

  tearDown(() {
    Session.instance.accessToken = null;
    ReportQueue.instance.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: home));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  NavigatorState nav(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator));

  bool submitted() => sent.any((r) => r.url.path.endsWith('/reports/submit'));

  testWidgets('the dial goes to the report already out, not a second one', (
    tester,
  ) async {
    await ActiveReportStore.start(out());
    await pump(tester, const HomeScreen());
    await settle(tester);

    expect(find.byType(ReportStatusScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      find.textContaining('already have a report in progress'),
      findsOneWidget,
    );
  });

  testWidgets('with a report waiting for signal, the dial goes to the map', (
    tester,
  ) async {
    await tester.runAsync(
      () => ReportQueue.instance.enqueue(
        lat: 14.5378,
        lng: 121.0014,
        agencies: const ['fire_volunteer'],
        notes: '',
        photoBytes: kPixel,
      ),
    );
    await pump(tester, const HomeScreen());
    await settle(tester);

    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.textContaining('saved on this phone'), findsWidgets);
  });

  testWidgets('a form left open does not send a second report', (tester) async {
    await ActiveReportStore.start(out());
    await pump(tester, SosReportScreen(photoBytes: kPixel, api: server()));

    await tester.tap(find.text('SEND REPORT'));
    await settle(tester);

    expect(submitted(), isFalse);
    expect(find.byType(ReportStatusScreen), findsOneWidget);
  });

  testWidgets('a report the server knows of is followed, not duplicated', (
    tester,
  ) async {
    // This phone lost track of it (reinstalled, say); the server has not.
    Session.instance.accessToken = 'token';
    final api = server(
      submit: () => http.Response(
        jsonEncode({
          'error': 'report_in_progress',
          'message': 'You already have a report in progress.',
        }),
        409,
      ),
      mine: [
        {
          'id': 'r-live',
          'area_id': 'a7',
          'area_designation': 'Area 7',
          'area_status': 'en_route',
          'device_lat': 14.5378,
          'device_lng': 121.0014,
          'selected_agencies': ['fire_volunteer'],
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    );
    SosLocation.instance.warmUp();
    await pump(tester, SosReportScreen(photoBytes: kPixel, api: api));

    await tester.tap(find.text('SEND REPORT'));
    await settle(tester);

    expect(ActiveReportStore.mine?.reportId, 'r-live');
    expect(find.byType(ReportStatusScreen), findsOneWidget);
    expect(find.byType(SosReportScreen), findsNothing);
  });

  testWidgets('Back from a report just sent is the map, not the form', (
    tester,
  ) async {
    final api = server(
      submit: () => http.Response(
        jsonEncode({
          'id': 'r9',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'area_id': 'a9',
          'area_designation': 'Area 9',
          'message': 'Report submitted.',
        }),
        201,
      ),
    );
    SosLocation.instance.warmUp();
    await pump(tester, SosReportScreen(photoBytes: kPixel, api: api));
    // Choices made on the form, which must not be waiting behind the report.
    await tester.tap(find.text('MEDICAL'));
    await tester.pump();

    await tester.tap(find.text('SEND REPORT'));
    await settle(tester);
    expect(find.byType(ReportStatusScreen), findsOneWidget);

    nav(tester).pop();
    await settle(tester);

    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(SosReportScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
