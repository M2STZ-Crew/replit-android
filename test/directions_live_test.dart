import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/location/live_position.dart';
import 'package:replit/location/route_progress.dart';
import 'package:replit/screens/directions_screen.dart';
import 'package:replit/theme.dart';

const _start = LatLng(14.5378, 121.0014);

/// Metres of latitude per degree around Pasay (the Vincenty value).
const _mPerDegLat = 110630.0;

/// [north] metres north of the start, [east] metres east.
LatLng at(double north, {double east = 0}) => LatLng(
  _start.latitude + north / _mPerDegLat,
  _start.longitude + east / (_mPerDegLat * 0.968),
);

/// A phone standing at the start with a 5 m fix.
class _StartGeo extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: _start.latitude,
    longitude: _start.longitude,
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

/// Directions that keep up with the walker, as Google Maps does.
void main() {
  group('where you are along a route', () {
    // An L-shaped walk: 1 km north, then 1 km east.
    final route = [at(0), at(1000), at(1000, east: 1000)];

    test('at the start the whole route is left', () {
      final p = RouteProgress.of(route, at(0));
      expect(p.remainingMetres, closeTo(2000, 10));
      expect(p.offRouteMetres, closeTo(0, 1));
    });

    test('halfway up the first leg, 1.5 km are left', () {
      final p = RouteProgress.of(route, at(500));
      expect(p.remainingMetres, closeTo(1500, 10));
      expect(p.segment, 0);
    });

    test('on the second leg, only its rest counts', () {
      final p = RouteProgress.of(route, at(1000, east: 700));
      expect(p.remainingMetres, closeTo(300, 10));
      expect(p.segment, 1);
    });

    test('off to the side, the step back is counted and measured', () {
      final p = RouteProgress.of(route, at(500, east: 120));
      expect(p.offRouteMetres, closeTo(120, 3));
      expect(p.remainingMetres, closeTo(1500 + 120, 12));
    });

    test('the walked part and the part ahead meet where you are', () {
      final p = RouteProgress.of(route, at(500));
      expect(p.behind(route).last, p.ahead(route).first);
      expect(p.ahead(route).last, route.last);
    });
  });

  group('the directions screen', () {
    late List<LatLng> asked;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GeolocatorPlatform.instance = _StartGeo();
      asked = [];
    });

    /// A straight 2 km route north, from wherever it is asked.
    Future<RouteResult?> fetch(LatLng from, LatLng to) async {
      asked.add(from);
      return (
        points: [from, to],
        metres: const Distance().as(LengthUnit.Meter, from, to),
        seconds: null,
      );
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dest = at(2000);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: DirectionsScreen(
            destLat: dest.latitude,
            destLng: dest.longitude,
            destName: 'Pasay Sports Complex',
            originLat: _start.latitude,
            originLng: _start.longitude,
            fetchRoute: fetch,
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> walkTo(WidgetTester tester, LatLng p) async {
      LivePosition.instance.offer(p, accuracy: 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('the distance and minutes count down as you walk', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('2.0 km'), findsOneWidget);
      expect(find.text('~24 min'), findsOneWidget);

      await walkTo(tester, at(800));
      expect(find.text('1.2 km'), findsOneWidget);
      expect(find.text('~15 min'), findsOneWidget);

      await walkTo(tester, at(1700));
      expect(find.text('300 m'), findsOneWidget);
    });

    testWidgets('the part already walked fades behind you', (tester) async {
      await pump(tester);
      await walkTo(tester, at(800));
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines, hasLength(2), reason: 'walked + ahead');
      expect(layer.polylines.last.points.last, at(2000));
    });

    testWidgets('two fixes off the route fetch a new one from where you are', (
      tester,
    ) async {
      await pump(tester);
      expect(asked, hasLength(1));

      await walkTo(tester, at(600, east: 200));
      expect(asked, hasLength(1), reason: 'one stray fix is only GPS noise');
      await walkTo(tester, at(620, east: 210));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(asked, hasLength(2));
      expect(asked.last, at(620, east: 210));
    });

    testWidgets('Start follows and turns with you; Stop lets go', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('START'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('STOP'), findsOneWidget);
      expect(find.text('ON YOUR WAY'), findsOneWidget);
      expect(find.byIcon(Icons.explore), findsOneWidget, reason: 'compass');

      await tester.tap(find.text('STOP'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('START'), findsOneWidget);
      expect(find.byIcon(Icons.location_searching), findsOneWidget);
    });

    testWidgets('at the shelter it says you have arrived', (tester) async {
      await pump(tester);
      await walkTo(tester, at(1985));
      expect(find.text('YOU HAVE ARRIVED'), findsOneWidget);
      expect(find.text('START'), findsNothing);
    });
  });

  group('to a fire (v12)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GeolocatorPlatform.instance = _StartGeo();
    });

    /// 2 km by road, driven in 4 minutes (30 km/h): the route's own pace.
    Future<RouteResult?> fetch(LatLng from, LatLng to) async => (
      points: [from, to],
      metres: const Distance().as(LengthUnit.Meter, from, to),
      seconds: 240.0,
    );

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fire = at(2000);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: DirectionsScreen(
            destLat: fire.latitude,
            destLng: fire.longitude,
            destName: 'Area 7',
            to: DirectionsTo.fire,
            fetchRoute: fetch,
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('driving time comes from the road route, and counts down', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('ROUTE TO THE FIRE'), findsOneWidget);
      expect(find.text('~4 min'), findsOneWidget);
      expect(find.text('DRIVING'), findsOneWidget);
      LivePosition.instance.offer(at(1000), accuracy: 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('~2 min'), findsOneWidget);
    });

    testWidgets('within 100 m it says you are at the fire', (tester) async {
      await pump(tester);
      LivePosition.instance.offer(at(1920), accuracy: 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('YOU ARE AT THE FIRE'), findsOneWidget);
    });
  });
}
