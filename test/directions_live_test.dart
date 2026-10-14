import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/location/live_position.dart';
import 'package:replit/location/route_progress.dart';
import 'package:replit/navigation/nav_route.dart';
import 'package:replit/navigation/routing_service.dart';
import 'package:replit/navigation/voice_guide.dart';
import 'package:replit/screens/directions_screen.dart';
import 'package:replit/theme.dart';

import 'navigation_test.dart' as nt;

const _start = LatLng(14.5378, 121.0014);

/// [north] metres north of the start, [east] metres east (as navigation_test).
LatLng at(double north, {double east = 0}) => nt.at(north, east: east);

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

/// Says nothing aloud; remembers what it would have said.
class _Voice extends VoiceGuide {
  final List<String> said = [];

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async {}
}

/// Directions as Google Maps gives them.
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

    test('a search window keeps a place on the part of the route searched', () {
      // A route that comes back past its own start: 1 km north and back.
      final there = [at(0), at(1000), at(0, east: 20)];
      final p = RouteProgress.of(there, at(100), fromSegment: 1, toSegment: 1);
      expect(p.segment, 1, reason: 'not pulled back onto the way out');
    });
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> moveTo(WidgetTester tester, LatLng p) async {
    LivePosition.instance.offer(p, accuracy: 5, speed: 8, heading: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('to a shelter, on foot', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GeolocatorPlatform.instance = _StartGeo();
    });

    /// A straight 2 km walk north, at walking pace.
    Future<RouteSet> fetch(LatLng from, LatLng to, {double? headingDeg}) async {
      return RouteSet(
        routes: parseRoutes(
          nt.answer([
            (
              points: [from, to],
              steps: [
                nt.step('depart', from, distance: 2000, duration: 2000 / 1.39),
                nt.step('arrive', to),
              ],
              duration: 2000 / 1.39,
              summary: '',
              congestion: null,
              typical: null,
            ),
          ]),
        ),
        provider: 'mapbox',
        trafficAware: false,
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
            voice: _Voice(),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('the distance and minutes count down as you walk', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('2.0 km'), findsOneWidget);
      expect(find.text('~24 min'), findsOneWidget);

      await moveTo(tester, at(800));
      expect(find.text('1.2 km'), findsOneWidget);
      expect(find.text('~15 min'), findsOneWidget);

      await moveTo(tester, at(1700));
      expect(find.text('300 m'), findsOneWidget);
    });

    testWidgets('the part already walked fades behind you', (tester) async {
      await pump(tester);
      await moveTo(tester, at(800));
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines, hasLength(2), reason: 'walked + ahead');
      expect(layer.polylines.last.points.last, at(2000));
    });

    testWidgets('off the route, it says so', (tester) async {
      await pump(tester);
      await moveTo(tester, at(600, east: 200));
      expect(
        find.text('You are off the route. We will find you a new one.'),
        findsOneWidget,
      );
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
      await moveTo(tester, at(1985));
      expect(find.text('YOU HAVE ARRIVED'), findsOneWidget);
      expect(find.text('START'), findsNothing);
    });
  });

  group('to a fire, by road', () {
    late List<LatLng> askedTo;
    late List<dynamic> offered;
    late bool traffic;
    late _Voice voice;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GeolocatorPlatform.instance = _StartGeo();
      askedTo = [];
      offered = [nt.lRoute];
      traffic = true;
      voice = _Voice();
    });

    Future<RouteSet> fetch(LatLng from, LatLng to, {double? headingDeg}) async {
      askedTo.add(to);
      return RouteSet(
        routes: parseRoutes(nt.answer(offered.cast())),
        provider: traffic ? 'mapbox' : 'osrm',
        trafficAware: traffic,
      );
    }

    Future<void> pump(
      WidgetTester tester, {
      Future<LatLng?> Function()? refresh,
    }) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fire = at(1000, east: 1000);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: DirectionsScreen(
            destLat: fire.latitude,
            destLng: fire.longitude,
            destName: 'Area 7',
            to: DirectionsTo.fire,
            fetchRoute: fetch,
            refreshDestination: refresh,
            voice: voice,
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('driving time comes from the road route, and counts down', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('ROUTE TO THE FIRE'), findsOneWidget);
      expect(find.text('~4 min'), findsOneWidget);
      expect(find.text('DRIVING'), findsOneWidget);
      expect(find.text('Times include live traffic.'), findsOneWidget);
      await moveTo(tester, at(1000));
      expect(find.text('~2 min'), findsOneWidget);
    });

    testWidgets('without traffic data, it says the times are estimates', (
      tester,
    ) async {
      traffic = false;
      await pump(tester);
      expect(
        find.text('No live traffic data — times are estimates.'),
        findsOneWidget,
      );
      expect(find.text('Times include live traffic.'), findsNothing);
    });

    testWidgets('every route offered, the fastest chosen; another can be', (
      tester,
    ) async {
      offered = [nt.longRoute, nt.lRoute];
      await pump(tester);
      expect(find.text('FASTEST'), findsOneWidget);
      expect(find.text('~4 min'), findsOneWidget);
      expect(find.text('~7 min'), findsOneWidget);
      List<LatLng> grey() => tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .first
          .points;
      expect(grey().last, at(3000), reason: 'the long way, in grey');

      await tester.tap(find.byKey(const ValueKey('route-0')));
      await tester.pump();
      expect(
        grey().last,
        at(1000, east: 1000),
        reason: 'now the other is grey',
      );
    });

    testWidgets('Start: the next turn in the banner, counting down, then the '
        'next; the voice says each', (tester) async {
      await pump(tester);
      await tester.tap(find.text('START'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Turn right onto Gil Puyat Avenue'), findsOneWidget);
      expect(find.text('1.0 km'), findsWidgets);
      expect(
        voice.said.first,
        'In 1.0 kilometres, turn right onto Gil Puyat Avenue',
      );

      await moveTo(tester, at(800));
      final distance = tester.widget<Text>(
        find.byKey(const ValueKey('maneuver-distance')),
      );
      expect(distance.data, '200 m');
      expect(
        voice.said.last,
        'In 200 metres, turn right onto Gil Puyat Avenue.',
      );

      await moveTo(tester, at(1000, east: 60));
      expect(find.text('You have arrived at the fire'), findsOneWidget);
      expect(find.text('ARRIVE'), findsOneWidget, reason: 'the arrival clock');
    });

    testWidgets('looking around the map stops following; Re-centre brings the '
        'navigation view back', (tester) async {
      await pump(tester);
      await tester.tap(find.text('START'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('recentre')), findsNothing);

      await tester.drag(find.byType(FlutterMap), const Offset(0, 140));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('recentre')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recentre')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('recentre')), findsNothing);
      expect(find.byIcon(Icons.explore), findsOneWidget, reason: 'heading-up');
    });

    testWidgets('the destination follows the incident as reports move it', (
      tester,
    ) async {
      final moved = at(1000, east: 1300);
      await pump(tester, refresh: () async => moved);
      expect(askedTo, [at(1000, east: 1000)]);
      await tester.pump(DirectionsScreen.destinationEvery);
      await tester.pump();
      expect(askedTo.last, moved);
    });

    testWidgets('within 100 m it says you are at the fire', (tester) async {
      await pump(tester);
      await moveTo(tester, at(1000, east: 920));
      expect(find.text('YOU ARE AT THE FIRE'), findsOneWidget);
    });
  });
}
