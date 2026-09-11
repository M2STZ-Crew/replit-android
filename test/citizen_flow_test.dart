import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/diagnostics/report_timing.dart';
import 'package:replit/location/sos_location.dart';
import 'package:replit/screens/neighbour_alert_screen.dart';
import 'package:replit/screens/sos_report_screen.dart';
import 'package:replit/theme.dart';

/// The citizen reporting flow after Meeting 12 (Master Context v10 §6): the GPS
/// fix starts with the SOS hold and runs alongside the photo and the agency
/// choice, the send waits for it only if it must, and every report logs where
/// its seconds went.

/// Stands in for the phone's location services.
class FakeGeo extends GeolocatorPlatform {
  bool serviceOn = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position? lastKnown;
  Completer<Position>? fresh;
  int freshCalls = 0;
  int permissionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceOn;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    freshCalls++;
    return (fresh ??= Completer<Position>()).future;
  }
}

Position fix(
  double lat,
  double lng, {
  Duration age = Duration.zero,
  double accuracy = 8,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now().subtract(age),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// A 1x1 PNG — the viewfinder draws the photo.
// dart format off
const List<int> kPixel = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
// dart format on

void main() {
  late FakeGeo geo;
  final location = SosLocation.instance;

  setUp(() {
    geo = FakeGeo();
    GeolocatorPlatform.instance = geo;
    location.reset();
  });

  group('report timing', () {
    test('nothing is recorded until a report starts', () {
      final t = ReportTiming.instance;
      t.finish(outcome: 'reset'); // stop anything a previous test left running
      t.mark('photo_taken');
      expect(t.running, isFalse);
      expect(t.finish(outcome: 'sent'), isNull);
    });

    test('logs each step once, in order, as seconds since the first touch', () {
      final t = ReportTiming.instance..start('sos');
      t
        ..mark('hold_complete')
        ..mark('photo_taken')
        ..mark('photo_taken'); // a second press does not move the first
      expect(t.marks.map((m) => m.$1), ['hold_complete', 'photo_taken']);
      final line = t.finish(outcome: 'sent')!;
      expect(
        line,
        startsWith('[report-timing] origin=sos outcome=sent total='),
      );
      expect(
        line,
        matches(RegExp(r'hold_complete=\d+\.\ds photo_taken=\d+\.\ds$')),
      );
      expect(t.running, isFalse);
    });
  });

  group('the GPS fix', () {
    test(
      'shows a recent cached position at once, then the fresh fix',
      () async {
        geo.lastKnown = fix(14.50, 121.00, age: const Duration(seconds: 30));
        final pending = location.warmUp();
        await Future<void>.delayed(Duration.zero);
        expect(location.position.value?.latitude, 14.50);

        geo.fresh!.complete(fix(14.54, 121.01));
        expect((await pending)?.latitude, 14.54);
        expect(location.position.value?.latitude, 14.54);
      },
    );

    test('the hold, the camera and the send all share one fix', () async {
      final a = location.warmUp(requestPermission: false);
      final b = location.warmUp();
      final c = location.forReport();
      await Future<void>.delayed(Duration.zero);
      geo.fresh!.complete(fix(14.54, 121.01));
      final results = await Future.wait([a, b, c]);
      expect(geo.freshCalls, 1);
      expect(results.map((p) => p?.latitude), everyElement(14.54));
    });

    test(
      'a timed-out fix falls back to a cached one rather than no report',
      () async {
        geo.lastKnown = fix(14.50, 121.00, age: const Duration(minutes: 6));
        final pending = location.warmUp();
        await Future<void>.delayed(Duration.zero);
        geo.fresh!.completeError(TimeoutException('no satellites indoors'));
        expect((await pending)?.latitude, 14.50);
      },
    );

    test('with no fix and nothing cached, it says why', () async {
      final pending = location.warmUp();
      await Future<void>.delayed(Duration.zero);
      geo.fresh!.completeError(TimeoutException('no fix'));
      expect(await pending, isNull);
      expect(location.problem.value, contains('pinpoint'));
    });

    test('the hold never pops a permission dialog under the thumb', () async {
      geo.permission = LocationPermission.denied;
      expect(await location.warmUp(requestPermission: false), isNull);
      expect(geo.permissionRequests, 0);
      expect(location.problem.value, isNull); // the camera screen asks instead

      expect(await location.warmUp(), isNull);
      expect(geo.permissionRequests, 1);
      expect(location.problem.value, contains('permission'));
    });

    test('an old fix from an earlier report is not shown as current', () async {
      location.position.value = fix(
        14.40,
        121.10,
        age: const Duration(minutes: 30),
      );
      location.warmUp();
      expect(location.position.value, isNull);
    });
  });

  group('sending', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      double scale = 1,
    }) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('"What are we sending?" fits at ${scale}x', (tester) async {
        await pump(
          tester,
          const SosReportScreen(photoBytes: kPixel),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('WHAT ARE WE SENDING?'), findsOneWidget);
        for (final agency in ['FIRE', 'MEDICAL', 'POLICE', 'BARANGAY']) {
          expect(find.text(agency), findsOneWidget);
        }
        expect(find.text('RETAKE'), findsOneWidget);
        expect(find.text('SEND REPORT'), findsOneWidget);
      });
    }

    testWidgets('waits for a fix still arriving, then sends with it', (
      tester,
    ) async {
      location.warmUp(); // as the SOS hold would have
      http.Request? sent;
      final api = ApiClient(
        client: MockClient((req) {
          sent = req;
          return Completer<http.Response>()
              .future; // the server never answers here
        }),
      );

      await pump(tester, SosReportScreen(photoBytes: kPixel, api: api));
      // The frame's "Location already sent" is not claimed while it is not.
      expect(find.text('FINDING YOUR LOCATION'), findsOneWidget);
      expect(find.textContaining('ALREADY SENT'), findsNothing);

      await tester.tap(find.text('SEND REPORT'));
      await tester.pump();
      expect(
        find.textContaining('sends the moment it is found'),
        findsOneWidget,
      );
      expect(sent, isNull, reason: 'nothing may be sent without a location');

      geo.fresh!.complete(fix(14.5378, 121.0014));
      await tester.pump();
      await tester.pump();
      expect(sent, isNotNull);
      final body = utf8.decode(sent!.bodyBytes, allowMalformed: true);
      expect(body, contains('14.5378'));
      expect(body, contains('121.0014'));
    });
  });

  group('the 300 m alert', () {
    late List<http.Request> seen;

    ApiClient api() => ApiClient(
      client: MockClient((req) async {
        seen.add(req);
        if (req.url.path.endsWith('/notifications/respond')) {
          return http.Response('{"message":"ok"}', 200);
        }
        return http.Response(
          jsonEncode({
            'id': 'a1',
            'designation': 'Area 1.2',
            'status': 'pending',
            'centroid_lat': 14.5394,
            'centroid_lng': 121.0014,
            'report_count': 1,
            'reported_at': DateTime.now()
                .subtract(const Duration(minutes: 2))
                .toUtc()
                .toIso8601String(),
          }),
          200,
        );
      }),
    );

    Future<void> open(WidgetTester tester, {double scale = 1}) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      geo.fresh = Completer<Position>()..complete(fix(14.5378, 121.0014));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NeighbourAlertScreen(areaId: 'a1', api: api()),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    setUp(() => seen = []);

    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('asks, with the distance, at ${scale}x', (tester) async {
        await open(tester, scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('BARANGAY 76 ALERT'), findsOneWidget);
        expect(find.text('DO YOU SEE IT TOO?'), findsOneWidget);
        expect(find.textContaining('reported a fire'), findsOneWidget);
        expect(find.textContaining('2 minutes ago'), findsOneWidget);
        // ~177 m between the fix and the area's centre.
        expect(
          find.textContaining(RegExp(r'^1\d\d M FROM YOU$')),
          findsOneWidget,
        );
        expect(find.text('YES, I CAN SEE IT'), findsOneWidget);
        expect(find.text('NO, AND STOP ASKING ABOUT THIS'), findsOneWidget);
      });
    }

    testWidgets('"No" tells the server to stop asking, and closes', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('NO, AND STOP ASKING ABOUT THIS'));
      await tester.pumpAndSettle();

      final respond = seen.where(
        (r) => r.url.path.endsWith('/notifications/respond'),
      );
      expect(respond, hasLength(1));
      expect(jsonDecode(respond.single.body), {
        'area_id': 'a1',
        'response': 'ignore',
      });
      expect(find.byType(NeighbourAlertScreen), findsNothing);
      expect(
        find.text("You won't be asked about this one again."),
        findsOneWidget,
      );
    });
  });
}
