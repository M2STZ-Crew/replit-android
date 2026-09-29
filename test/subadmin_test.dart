import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/live_hub.dart';
import 'package:replit/api/live_refresh.dart';
import 'package:replit/screens/directions_screen.dart';
import 'package:replit/screens/subadmin/coordinator_nav.dart';
import 'package:replit/screens/subadmin/post_incident_report_screen.dart';
import 'package:replit/screens/subadmin/subadmin_incident_command_screen.dart';
import 'package:replit/screens/subadmin/subadmin_incident_report_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/ops_layers.dart';
import 'package:replit/widgets/photo_viewer.dart';

/// The team captain's side (v12 §2.5 for verify / respond / reject): dispatch asks only who is going (§2.5),
/// BFP and Fire Volunteer captains land in the same coordinator screens
/// (§2.6.1), fire out always offers the Post-Incident Report, and the maps
/// carry only layers with data behind them (§2.4, §2.7.1).
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: child));
    await tester.pumpAndSettle();
  }

  // v11 removed the dispatch screen (Master Context §2.5): choosing a truck and
  // a crew while the incident was live was the paperwork that slowed the
  // response down. Accept sends the crew, and who actually went is recorded
  // afterwards on the Post-Incident Report. The tests that drove that screen
  // went with it.

  group('verify, respond, reject (v12 §2.5)', () {
    late List<String> posted;

    ApiClient api({
      required String status,
      List<Map<String, dynamic>> dispatches = const [],
    }) => ApiClient(
      client: MockClient((req) async {
        if (req.method == 'POST') posted.add(req.url.path);
        final path = req.url.path;
        if (path.endsWith('/dispatches')) {
          return http.Response(jsonEncode(dispatches), 200);
        }
        if (path.endsWith('/responders/locations') ||
            path == '/equipment' ||
            path == '/fire-codes') {
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode({
            'id': 'a1',
            'designation': 'Area 7',
            'status': status,
            'centroid_lat': 14.5378,
            'centroid_lng': 121.0014,
          }),
          200,
        );
      }),
    );

    Future<void> open(
      WidgetTester tester, {
      required String agency,
      required String status,
      List<Map<String, dynamic>> dispatches = const [],
    }) async {
      posted = [];
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SubAdminIncidentReportScreen(
            report: const {
              'device_lat': 14.5378,
              'device_lng': 121.0014,
              'reporter_name': 'Test Fire Reporter',
              'photo_url': 'https://example.invalid/fire.jpg',
            },
            areaId: 'a1',
            status: status,
            agency: agency,
            me: {'id': 'me', 'role': 'sub_admin', 'agency_type': agency},
            api: api(status: status, dispatches: dispatches),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(text));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('a new report: verify (sends nobody) or reject', (
      tester,
    ) async {
      await open(tester, agency: 'bfp', status: 'reported');
      expect(find.text('REJECT'), findsOneWidget);
      expect(find.textContaining('RESPOND'), findsNothing);
      await tapText(tester, 'VERIFY');
      expect(posted, ['/incidents/a1/verify']);
    });

    testWidgets('verified: any coordinator may respond, and lands on command', (
      tester,
    ) async {
      await open(tester, agency: 'bfp', status: 'verified');
      expect(find.text('REJECT'), findsOneWidget, reason: 'a misclick undone');
      expect(find.text('FIRE OUT'), findsOneWidget);
      await tapText(tester, "RESPOND — I'M GOING");
      expect(posted, ['/incidents/a1/self-dispatch']);
      expect(find.byType(SubAdminIncidentCommandScreen), findsOneWidget);
    });

    testWidgets('someone already responding is not offered Respond again', (
      tester,
    ) async {
      await open(
        tester,
        agency: 'fire_volunteer',
        status: 'verified',
        dispatches: const [
          {'responder_id': 'me', 'status': 'active'},
        ],
      );
      expect(find.textContaining('RESPOND'), findsNothing);
      expect(find.textContaining('You are responding'), findsOneWidget);
    });

    testWidgets('on scene: reject gives way to fire out', (tester) async {
      await open(tester, agency: 'fire_volunteer', status: 'arrived');
      expect(find.text('REJECT'), findsNothing);
      expect(find.text('FIRE OUT'), findsOneWidget);
    });

    testWidgets('the photo opens full screen to zoom, and closes again', (
      tester,
    ) async {
      await open(tester, agency: 'bfp', status: 'reported');
      await tester.tap(find.byIcon(Icons.zoom_in));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Pinch or double-tap to zoom'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PhotoViewer), findsNothing);
    });

    testWidgets('the route to the fire needs your real location', (
      tester,
    ) async {
      GeolocatorPlatform.instance = _LocationOff();
      await open(tester, agency: 'bfp', status: 'verified');
      await tapText(tester, 'ROUTE TO THE FIRE');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final directions = tester.widget<DirectionsScreen>(
        find.byType(DirectionsScreen),
      );
      expect(directions.to, DirectionsTo.fire);
      expect(directions.destLat, 14.5378);
      // No GPS in a test: it says so, and invents no starting point.
      expect(find.text('YOUR LOCATION IS OFF'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
    });

    testWidgets('the command screen: join, and reject while on the way', (
      tester,
    ) async {
      posted = [];
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SubAdminIncidentCommandScreen(
            areaId: 'a1',
            me: const {'id': 'me', 'role': 'sub_admin', 'agency_type': 'bfp'},
            api: api(status: 'en_route'),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text("RESPOND — I'M GOING"), findsOneWidget);
      expect(find.text('REJECT INCIDENT'), findsOneWidget);
      await tester.tap(find.text("RESPOND — I'M GOING"));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(posted, ['/incidents/a1/self-dispatch']);
    });
  });

  group('live refresh', () {
    testWidgets('a change on the socket re-reads the screen, once per burst', (
      tester,
    ) async {
      final feed = _FakeFeed();
      final saved = LiveRefresh.feedFor;
      LiveRefresh.feedFor = (_) => feed;
      addTearDown(() => LiveRefresh.feedFor = saved);
      var reads = 0;
      final live = LiveRefresh(['incident:a1'], () => reads++)..start();

      feed.pushes.add({'type': 'incident_verified'});
      feed.pushes.add({'type': 'incident_feed'});
      await tester.pump(const Duration(milliseconds: 300));
      expect(reads, 1, reason: 'one read for the burst');

      feed.pushes.add({'type': 'responder_location'});
      await tester.pump(const Duration(milliseconds: 300));
      expect(reads, 1, reason: 'a GPS fix is not worth a reload');

      feed.pushes.add({'type': 'incident_rejected'});
      await tester.pump(const Duration(milliseconds: 300));
      expect(reads, 2);
      unawaited(live.dispose());
    });
  });

  group('the staff map layers', () {
    test('every chip has data behind it', () {
      final layers = opsLayers(ApiClient());
      expect(layers.first.key, 'incidents');
      for (final layer in layers.skip(1)) {
        expect(layer.load, isNotNull, reason: layer.key);
      }
      // The data-less chips the dashboards used to carry are gone.
      expect(layers.map((l) => l.key), isNot(contains('teams')));
      expect(layers.map((l) => l.key), isNot(contains('hospital')));
      expect(layers.map((l) => l.key), isNot(contains('barangay')));
      expect(layers.map((l) => l.key), contains('cisterns'));
    });

    test('a shelter outside Pasay is marked as such', () async {
      final api = ApiClient(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode([
              {
                'id': 's1',
                'latitude': 14.54,
                'longitude': 121.0,
                'outside_pasay': false,
              },
              {
                'id': 's2',
                'latitude': 14.48,
                'longitude': 121.02,
                'outside_pasay': true,
              },
            ]),
            200,
          ),
        ),
      );
      final evac = opsLayers(api).firstWhere((l) => l.key == 'evac');
      final points = await evac.load!();
      expect(points.map((p) => p.outside), [false, true]);
    });
  });

  group('after fire out', () {
    Widget launcher(Future<void> Function(BuildContext) onTap) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => onTap(context),
            child: const Text('GO'),
          ),
        ),
      ),
    );

    ApiClient reportApi() => ApiClient(
      client: MockClient(
        (req) async => http.Response(
          jsonEncode(
            req.url.path.endsWith('/dispatches') || req.url.path == '/equipment'
                ? []
                : {
                    'id': 'a4',
                    'designation': 'Area 11',
                    'status': 'post_incident_report',
                  },
          ),
          200,
        ),
      ),
    );

    testWidgets('"later" leaves the report in the tray and says so', (
      tester,
    ) async {
      await pump(
        tester,
        launcher((ctx) => offerPostIncidentReport(ctx, areaId: 'a4')),
      );
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
      expect(find.text('Fire out recorded'), findsOneWidget);
      await tester.tap(find.text('LATER'));
      await tester.pumpAndSettle();
      expect(find.textContaining('waiting in Pending reports'), findsOneWidget);
    });

    testWidgets('"file now" opens the report', (tester) async {
      await pump(
        tester,
        launcher(
          (ctx) => offerPostIncidentReport(ctx, areaId: 'a4', api: reportApi()),
        ),
      );
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FILE NOW'));
      await tester.pumpAndSettle();
      expect(find.byType(PostIncidentReportScreen), findsOneWidget);
    });

    testWidgets(
      'a coordinator opening a report-due incident lands on the report',
      (tester) async {
        await pump(
          tester,
          launcher(
            (ctx) => openCoordinatorIncident(
              ctx,
              incident: const {
                'id': 'a4',
                'designation': 'Area 11',
                'status': 'post_incident_report',
              },
              me: const {'role': 'sub_admin', 'agency_type': 'bfp'},
              api: reportApi(),
            ),
          ),
        );
        await tester.tap(find.text('GO'));
        await tester.pumpAndSettle();
        expect(find.byType(PostIncidentReportScreen), findsOneWidget);
      },
    );
  });
}

/// A channel the test pushes messages into.
class _FakeFeed implements LiveFeed {
  final StreamController<Map<String, dynamic>> pushes =
      StreamController.broadcast(sync: true);

  @override
  ValueListenable<bool> get live => ValueNotifier(true);

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

/// A phone with location switched off.
class _LocationOff extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
}
