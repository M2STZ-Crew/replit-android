import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/widgets/map_marker.dart';
import 'package:replit/api/api_client.dart';
import 'package:replit/api/report_queue.dart';
import 'package:replit/location/live_position.dart';
import 'package:replit/location/last_place.dart';
import 'package:replit/widgets/responsive_frame.dart';
import 'package:replit/widgets/skeleton.dart';
import 'package:replit/models/hotline.dart';
import 'package:replit/screens/map_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/updates/app_updates.dart';
import 'package:replit/updates/update_nudge.dart';

/// The citizen map ("04 Map" and "05 Map — offline queue"): what the sheet
/// says with signal, and what it says without.

/// Let the areas sheet fold or unfold: the first frame only starts the clock.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

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

/// A phone whose GPS has not answered yet.
class _WaitingGeo extends _HereGeo {
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Completer<Position>().future;
}

/// A phone with location switched off.
class _OffGeo extends _HereGeo {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

/// A phone whose owner said no to location.
class _RefusedGeo extends _HereGeo {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
}

void main() {
  late bool reachable;
  late Directory dir;

  /// What GET /areas answers with, and (when set) what it waits for first.
  late List<Map<String, dynamic>> served;
  late int areasStatus;
  Completer<void>? areasGate;

  // One area ~350 m away, one ~5 km away: only the first is "near you".
  final areas = [
    {
      'id': 'near',
      'designation': 'Area 1.2',
      'status': 'reported',
      'centroid_lat': 14.5410,
      'centroid_lng': 121.0014,
      'report_count': 1,
      'confidence_band': 'low',
    },
    {
      'id': 'far',
      'designation': 'Area 9.1',
      'status': 'en_route',
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
      if (path.endsWith('/areas')) {
        await areasGate?.future;
        return http.Response(jsonEncode(served), areasStatus);
      }
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
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _HereGeo();
    // A fix an earlier test's map offered must not stand in for this one's.
    LivePosition.instance.here.value = null;
    reachable = true;
    served = areas;
    areasStatus = 200;
    areasGate = null;
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
      expect(find.text('REPORTED'), findsOneWidget);
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

  // 8 November: the map is the resident's home screen.
  testWidgets('"There\'s a new update!" under the locality pill while one is '
      'waiting', (tester) async {
    addTearDown(UpdateNudge.reset);
    UpdateNudge.waiting.value = const AvailableRelease(
      version: '1.12.31',
      build: 53,
    );
    await pump(tester);
    expect(tester.takeException(), isNull);
    final banner = find.text("There's a new update!");
    expect(banner, findsOneWidget);
    expect(
      tester.getTopLeft(banner).dy,
      greaterThan(tester.getTopLeft(find.text('RESPONDERS').first).dy),
    );
    UpdateNudge.waiting.value = null;
    await tester.pump();
    expect(banner, findsNothing);
  });

  testWidgets('the areas sheet drags down out of the way, and comes back', (
    tester,
  ) async {
    await pump(tester);
    if (find.text('Got it').evaluate().isNotEmpty) {
      await tester.tap(find.text('Got it'));
      await tester.pump();
    }
    final title = find.text('ACTIVE AREAS NEAR YOU');
    final row = find.text('Area 1.2');
    final open = tester.getTopLeft(title).dy;
    expect(row.hitTestable(), findsOneWidget);

    // Anywhere on the sheet drags it — here, a row.
    await tester.drag(row, const Offset(0, 300));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(title).dy, greaterThan(open + 100));
    expect(title.hitTestable(), findsOneWidget, reason: 'the title stays');
    expect(row.hitTestable(), findsNothing, reason: 'the rows fold away');

    // Tapping the title opens it again.
    await tester.tap(title);
    await settle(tester);
    expect(tester.getTopLeft(title).dy, moreOrLessEquals(open, epsilon: 1));
    expect(row.hitTestable(), findsOneWidget);

    // And a drag up from folded does too.
    await tester.drag(row, const Offset(0, 300));
    await settle(tester);
    await tester.drag(title, const Offset(0, -300));
    await settle(tester);
    expect(row.hitTestable(), findsOneWidget);
  });

  // v1.12.23: signing in showed "Area 50.4" and "Area 50.3" under "Active
  // areas near you" — the newest two Areas anywhere, standing in until the
  // GPS answered. The sheet now names an Area only once it has measured it.
  group('active areas near you, while the sheet cannot know yet', () {
    final incidentMarkers = find.byWidgetPredicate(
      (w) => w is MapMarker && w.kind == MapMarkerKind.incident,
    );

    testWidgets('before the GPS answers: checking, no Area named', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _WaitingGeo();
      await pump(tester);
      expect(tester.takeException(), isNull);

      expect(
        find.text('Checking what is happening around you…'),
        findsOneWidget,
      );
      expect(find.text('Area 1.2'), findsNothing);
      expect(find.text('Area 9.1'), findsNothing);
      expect(find.text('Evacuation site open'), findsNothing);
      expect(find.text('WITHIN 1.5 KM'), findsOneWidget);
      // The records themselves stay on the map.
      expect(incidentMarkers, findsNWidgets(2));
    });

    testWidgets('before the server answers: checking, then the Areas', (
      tester,
    ) async {
      areasGate = Completer<void>();
      await pump(tester);
      expect(
        find.text('Checking what is happening around you…'),
        findsOneWidget,
      );
      expect(find.text('Area 1.2'), findsNothing);

      areasGate!.complete();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Checking what is happening around you…'), findsNothing);
      expect(find.text('Area 1.2'), findsOneWidget);
      expect(find.text('Area 9.1'), findsNothing, reason: 'about 5 km away');
    });

    testWidgets('nothing within 1.5 km: says so, and the shelter still', (
      tester,
    ) async {
      // Only the Area about 5 km away. (Its marker is off screen once the map
      // centres on the phone, so the map builds none: nothing to count here.)
      served = [areas.last];
      await pump(tester);
      expect(tester.takeException(), isNull);

      expect(
        find.text('Nothing active within 1.5 km. That is the good outcome.'),
        findsOneWidget,
      );
      expect(find.text('Area 9.1'), findsNothing);
      expect(find.text('Evacuation site open'), findsOneWidget);
    });

    testWidgets('location off: says to turn it on, names no Area', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _OffGeo();
      await pump(tester);
      expect(tester.takeException(), isNull);

      expect(
        find.text('Location is off. Turn it on to see active areas near you.'),
        findsOneWidget,
      );
      expect(find.text('Area 1.2'), findsNothing);
      expect(find.text('Area 9.1'), findsNothing);
      expect(incidentMarkers, findsNWidgets(2));
    });

    testWidgets('location refused: says to allow it, names no Area', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _RefusedGeo();
      await pump(tester);
      expect(tester.takeException(), isNull);

      expect(
        find.text(
          'Location permission is off. Allow it to see active areas near you.',
        ),
        findsOneWidget,
      );
      expect(find.text('Area 1.2'), findsNothing);
    });

    testWidgets('the server failing is not "nothing active"', (tester) async {
      areasStatus = 500;
      await pump(tester);
      expect(tester.takeException(), isNull);

      expect(
        find.text(
          'Active areas could not be loaded. The map tries again every 15 seconds.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('That is the good outcome'), findsNothing);
    });
  });

  // v1.12.43 (13 November 2026: "the map still locates pasay, what if the map
  // stays still where the user is or was. and it has "LOCATING YOU""; "create
  // a skeleton loading on that map screen"). The map opens where the resident
  // last was, and says LOCATING YOU over a skeleton until the fix answers.
  group('the map opens where the resident last was', () {
    const lastSpot = LatLng(14.5520, 121.0050);

    MapOptions optionsOf(WidgetTester tester) =>
        tester.widget<FlutterMap>(find.byType(FlutterMap)).options;

    testWidgets('on the last spot, at street level, LOCATING YOU over a '
        'skeleton until the GPS answers', (tester) async {
      LastPlace.remember(lastSpot, street: 'Concha Street');
      GeolocatorPlatform.instance = _WaitingGeo();
      await pump(tester);
      expect(tester.takeException(), isNull);

      expect(optionsOf(tester).initialCenter, lastSpot);
      expect(optionsOf(tester).initialZoom, greaterThan(15));
      expect(find.text('LOCATING YOU'), findsOneWidget);
      // Not a made-up place: the card and the sheet show their shape.
      expect(find.text('Showing Pasay City until a fix arrives'), findsNothing);
      expect(find.byType(SkeletonShimmer), findsNWidgets(2));
      expect(
        find.text('Checking what is happening around you…'),
        findsOneWidget,
      );
    });

    testWidgets('the last street names a fix on the same spot at once', (
      tester,
    ) async {
      // The fake GPS answers at Pasay's centre: the street found there.
      LastPlace.remember(
        const LatLng(14.5378, 121.0014),
        street: 'Concha Street',
      );
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('CONCHA STREET'), findsOneWidget);
      expect(find.text('LOCATING YOU'), findsNothing);
      expect(find.byType(SkeletonShimmer), findsNothing);
    });

    testWidgets('a phone that never had a fix starts on Pasay', (tester) async {
      GeolocatorPlatform.instance = _WaitingGeo();
      await pump(tester);
      expect(optionsOf(tester).initialCenter, const LatLng(14.5378, 121.0014));
      expect(optionsOf(tester).initialZoom, 13);
      expect(find.text('LOCATING YOU'), findsOneWidget);
    });

    testWidgets('the fix is kept as the last spot for the next time', (
      tester,
    ) async {
      await pump(tester);
      expect(LastPlace.value, const LatLng(14.5378, 121.0014));
    });

    testWidgets('on a tablet the map fills the screen; its sheet keeps the '
        'column', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MapScreen(api: api()),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FlutterMap)).width, 1280);
      final sheet = tester.getTopLeft(find.text('ACTIVE AREAS NEAR YOU')).dx;
      expect(
        sheet,
        greaterThanOrEqualTo((1280 - ResponsiveFrame.maxWidth) / 2),
        reason: 'the sheet is the column, centred',
      );
    });
  });
}
