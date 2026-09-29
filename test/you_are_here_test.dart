import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/you_are_here.dart';

/// The Google-Maps map: it can be turned, it follows the person as they walk,
/// it can turn with them, and a drag lets go.
void main() {
  late StreamController<LocationMarkerPosition?> gps;
  late StreamController<LocationMarkerHeading?> compass;
  late MapController map;
  late MapFollow follow;

  setUp(() {
    gps = StreamController.broadcast();
    compass = StreamController.broadcast();
    MapLocationSource.positions = () => gps.stream;
    MapLocationSource.headings = () => compass.stream;
  });

  tearDown(() {
    MapLocationSource.positions = () => const Stream.empty();
    MapLocationSource.headings = () => const Stream.empty();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    map = MapController();
    follow = MapFollow();
    addTearDown(follow.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: const LatLng(14.5378, 121.0014),
              initialZoom: 15,
              interactionOptions: kMapGestures,
              onMapEvent: follow.onMapEvent,
            ),
            children: [
              YouAreHereLayer(follow: follow),
              MapLocationButtons(follow: follow),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> walkTo(WidgetTester tester, double lat, double lng) async {
    gps.add(LocationMarkerPosition(latitude: lat, longitude: lng, accuracy: 5));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapButton(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('every map can be dragged, pinched and turned', () {
    expect(kMapGestures.flags, InteractiveFlag.all);
    expect(kMapGestures.flags & InteractiveFlag.rotate, isNot(0));
  });

  testWidgets('the location button follows you as you move', (tester) async {
    await pump(tester);
    await walkTo(tester, 14.5500, 121.0100);
    // Free: the dot moves, the map does not.
    expect(map.camera.center.latitude, closeTo(14.5378, 1e-4));

    await tapButton(tester, Icons.location_searching);
    expect(follow.mode, FollowMode.follow);
    expect(map.camera.center.latitude, closeTo(14.5500, 1e-4));
    expect(map.camera.zoom, closeTo(MapFollow.followZoom, 1e-6));

    await walkTo(tester, 14.5600, 121.0200);
    expect(map.camera.center.latitude, closeTo(14.5600, 1e-4));
    expect(map.camera.center.longitude, closeTo(121.0200, 1e-4));
  });

  testWidgets('a second tap turns the map with you; a third puts north back', (
    tester,
  ) async {
    await pump(tester);
    await walkTo(tester, 14.5500, 121.0100);
    await tapButton(tester, Icons.location_searching);
    await tapButton(tester, Icons.my_location);
    expect(follow.mode, FollowMode.compass);

    // Facing east: the map turns so east is up.
    compass.add(LocationMarkerHeading(heading: math.pi / 2, accuracy: 0.1));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(map.camera.rotation.abs() % 360, isNot(closeTo(0, 1)));
    expect(find.byIcon(Icons.navigation), findsOneWidget, reason: 'compass');

    await tapButton(tester, Icons.explore);
    expect(follow.mode, FollowMode.follow);
    expect(map.camera.rotation % 360, closeTo(0, 1e-6));
  });

  testWidgets('dragging the map lets go of you, as in Google Maps', (
    tester,
  ) async {
    await pump(tester);
    await walkTo(tester, 14.5500, 121.0100);
    await tapButton(tester, Icons.location_searching);
    expect(follow.mode, FollowMode.follow);

    await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(follow.mode, FollowMode.free);
    final after = map.camera.center;

    await walkTo(tester, 14.5700, 121.0300);
    expect(map.camera.center, after, reason: 'no longer following');
  });

  testWidgets('a turned map shows a compass; tapping it points north up', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byIcon(Icons.navigation), findsNothing);

    map.rotate(40);
    await tester.pump();
    expect(find.byIcon(Icons.navigation), findsOneWidget);

    await tapButton(tester, Icons.navigation);
    expect(map.camera.rotation % 360, closeTo(0, 1e-6));
    expect(find.byIcon(Icons.navigation), findsNothing);
  });
}
