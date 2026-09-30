import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/api/tracking_socket.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/screens/live_update_screen.dart';
import 'package:replit/screens/report_status_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

/// A socket the test drives by hand.
class FakeFeed implements TrackingFeed {
  final ValueNotifier<bool> liveNow = ValueNotifier(false);
  final ValueNotifier<bool> deniedNow = ValueNotifier(false);
  final StreamController<Map<String, dynamic>> pushes =
      StreamController.broadcast();
  int starts = 0;
  int pauses = 0;

  @override
  ValueListenable<bool> get live => liveNow;

  @override
  ValueListenable<bool> get denied => deniedNow;

  @override
  Stream<Map<String, dynamic>> get snapshots => pushes.stream;

  @override
  void start() => starts++;

  @override
  void pause() => pauses++;

  @override
  void resume() => starts++;

  @override
  Future<void> dispose() async {}
}

const _fireLat = 14.5380;
const _fireLng = 121.0016;

/// A unit [north] metres north of the fire, its fix [ageS] seconds old.
Map<String, dynamic> unit(
  String key,
  String label, {
  double north = 1500,
  int ageS = 3,
  String? organization = 'Hercules Fire Brigade',
}) => {
  'key': key,
  'label': label,
  'organization': organization,
  'agency': 'fire_volunteer',
  'lat': _fireLat + north / 111195,
  'lng': _fireLng,
  'heading_deg': 180,
  'updated_at': DateTime.now()
      .toUtc()
      .subtract(Duration(seconds: ageS))
      .toIso8601String(),
  'stale': ageS > 60,
};

Map<String, dynamic> snapshot({
  String status = 'en_route',
  List<Map<String, dynamic>> units = const [],
  String? verifiedBy,
}) => {
  'area_id': 'a1',
  'designation': 'Area 1.2',
  'status': status,
  'centroid_lat': _fireLat,
  'centroid_lng': _fireLng,
  'arrival_radius_m': 100,
  'stale_after_seconds': 60,
  'responders': units,
  if (verifiedBy != null) ...{
    'verified_by': verifiedBy,
    'verified_by_agency': 'fire_volunteer',
    'verified_at': DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 4))
        .toIso8601String(),
  },
  'generated_at': DateTime.now().toUtc().toIso8601String(),
};

/// Track It Live: the trucks on their way to the resident's own report.
void main() {
  late int trackingReads;
  late bool reporter;
  late String areaStatus;
  late Map<String, dynamic> served;

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/tracking')) {
        trackingReads++;
        return reporter
            ? http.Response(jsonEncode(served), 200)
            : http.Response(
                jsonEncode({
                  'error': 'forbidden',
                  'message':
                      'You can follow live tracking only for an '
                      'incident you reported.',
                }),
                403,
              );
      }
      if (path.endsWith('/reports/mine') ||
          path.endsWith('/map/evacuation-sites')) {
        return http.Response('[]', 200);
      }
      return http.Response(
        jsonEncode({
          'id': 'a1',
          'designation': 'Area 1.2',
          'status': areaStatus,
          'report_count': 2,
          'centroid_lat': _fireLat,
          'centroid_lng': _fireLng,
          'reported_at': DateTime.now().toUtc().toIso8601String(),
        }),
        200,
      );
    }),
  );

  setUp(() {
    trackingReads = 0;
    reporter = true;
    areaStatus = 'en_route';
    served = snapshot();
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = 'm.reyes@gmail.com';
  });

  Future<void> pump(
    WidgetTester tester,
    FakeFeed feed, {
    double scale = 1,
  }) async {
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
            child: LiveUpdateScreen(
              areaId: 'a1',
              lat: 14.5378,
              lng: 121.0014,
              api: api(),
              feed: feed,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> push(WidgetTester tester, FakeFeed feed, Object json) async {
    feed.pushes.add(json as Map<String, dynamic>);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // the glide
  }

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('each truck is named, placed and measured, at ${scale}x', (
      tester,
    ) async {
      final feed = FakeFeed()..liveNow.value = true;
      await pump(tester, feed, scale: scale);
      await push(
        tester,
        feed,
        snapshot(
          units: [
            unit('unit-1', 'Apollo'),
            unit('unit-2', 'Unit 2', ageS: 130, organization: null),
          ],
        ),
      );
      expect(tester.takeException(), isNull);

      expect(find.text('RESPONDERS'), findsOneWidget);
      expect(find.text('Apollo'), findsOneWidget);
      expect(
        find.text('Hercules Fire Brigade · On the way · 1.5 km from the fire'),
        findsOneWidget,
      );
      expect(find.text('Unit 2'), findsOneWidget);
      expect(find.text('Location lost · last seen 2 min ago'), findsOneWidget);
      // One marker per unit, and no line drawn between truck and fire.
      expect(find.byIcon(Icons.fire_truck), findsNWidgets(4));
      expect(find.byType(PolylineLayer), findsNothing);
    });
  }

  testWidgets('the rail names every step', (tester) async {
    await pump(tester, FakeFeed());
    for (final step in [
      'Reported',
      'Verified',
      'On the way',
      'On scene',
      'Fire out',
    ]) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    expect(find.text('ON THE WAY'), findsOneWidget, reason: 'the status');
  });

  testWidgets('a truck inside the arrival radius is on scene', (tester) async {
    final feed = FakeFeed()..liveNow.value = true;
    await pump(tester, feed);
    await push(
      tester,
      feed,
      snapshot(status: 'arrived', units: [unit('unit-1', 'Apollo', north: 40)]),
    );
    expect(find.text('ON SCENE'), findsOneWidget);
    expect(find.text('Hercules Fire Brigade · On scene'), findsOneWidget);
  });

  testWidgets('the resident sees which team verified it (v1.12.1)', (
    tester,
  ) async {
    final feed = FakeFeed()..liveNow.value = true;
    await pump(tester, feed);
    expect(find.textContaining('Verified by'), findsNothing);
    await push(
      tester,
      feed,
      snapshot(status: 'verified', verifiedBy: 'Hercules Fire Brigade'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Verified by Hercules Fire Brigade'), findsOneWidget);
    expect(find.text('Confirmed as a real fire · 4 min ago'), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
  });

  testWidgets('someone who did not report it is not told who verified it', (
    tester,
  ) async {
    reporter = false;
    served = snapshot(verifiedBy: 'Hercules Fire Brigade');
    await pump(tester, FakeFeed());
    expect(find.textContaining('Verified by'), findsNothing);
  });

  testWidgets('the sheet drags down out of the way; the handle brings it back', (
    tester,
  ) async {
    await pump(tester, FakeFeed());
    final status = find.text('STATUS');
    final next = find.text('WHAT HAPPENS NEXT');
    final open = tester.getTopLeft(status).dy;
    expect(next.hitTestable(), findsOneWidget);

    await tester.drag(status, const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(status).dy, greaterThan(open + 200));
    expect(status.hitTestable(), findsOneWidget, reason: 'the status stays');
    expect(next.hitTestable(), findsNothing, reason: 'the rest folds away');

    await tester.tap(find.byType(SheetHandle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getTopLeft(status).dy, moreOrLessEquals(open, epsilon: 1));
    expect(next.hitTestable(), findsOneWidget);
  });

  testWidgets('fire out on your own report goes straight to its Done screen', (
    tester,
  ) async {
    await ActiveReportStore.start(
      ActiveReport(
        owner: 'm.reyes@gmail.com',
        reportId: 'r1',
        areaId: 'a1',
        designation: 'Area 1.2',
        lat: 14.5378,
        lng: 121.0014,
        submittedAt: DateTime.now(),
      ),
    );
    final feed = FakeFeed()..liveNow.value = true;
    await pump(tester, feed);
    expect(find.byType(LiveUpdateScreen), findsOneWidget);

    await push(tester, feed, snapshot(status: 'fire_out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // the route
    expect(tester.takeException(), isNull);
    expect(find.byType(LiveUpdateScreen), findsNothing);
    expect(find.byType(ReportStatusScreen), findsOneWidget);
    expect(find.text('REPORT DONE'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget, reason: 'no need to back out');
  });

  testWidgets('a report already finished with just shows how it ended', (
    tester,
  ) async {
    // No report in progress: opened again from Your reports.
    final feed = FakeFeed()..liveNow.value = true;
    await pump(tester, feed);
    await push(tester, feed, snapshot(status: 'fire_out'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LiveUpdateScreen), findsOneWidget);
    expect(find.byType(ReportStatusScreen), findsNothing);
  });

  testWidgets('on the way with no position yet says a crew is coming', (
    tester,
  ) async {
    await pump(tester, FakeFeed());
    expect(find.text('A crew is on the way'), findsOneWidget);
  });

  testWidgets('the status follows the socket and never steps back', (
    tester,
  ) async {
    final feed = FakeFeed()..liveNow.value = true;
    await pump(tester, feed);
    await push(
      tester,
      feed,
      snapshot(status: 'arrived', units: [unit('unit-1', 'Apollo', north: 40)]),
    );
    expect(find.text('ON SCENE'), findsOneWidget);
    // A slower area read, still saying en route, lands afterwards.
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('ON SCENE'), findsOneWidget);
  });

  testWidgets('with the socket down it polls; with it up it does not', (
    tester,
  ) async {
    final feed = FakeFeed();
    await pump(tester, feed);
    final first = trackingReads;
    await tester.pump(const Duration(seconds: 13));
    expect(trackingReads, first + 2, reason: 'every 6 s while down');

    feed.liveNow.value = true;
    await tester.pump(const Duration(seconds: 13));
    expect(trackingReads, first + 2, reason: 'the socket carries it now');
  });

  testWidgets('someone who did not report it sees the status, not the trucks', (
    tester,
  ) async {
    reporter = false;
    final feed = FakeFeed();
    await pump(tester, feed);
    expect(find.text('ON THE WAY'), findsOneWidget);
    expect(find.text('RESPONDERS'), findsNothing);
    expect(find.text('A crew is on the way'), findsNothing);
    expect(feed.pauses, 1, reason: 'the socket stops asking');
    final reads = trackingReads;
    await tester.pump(const Duration(seconds: 13));
    expect(trackingReads, reads, reason: 'and so does the polling');
  });

  testWidgets('the socket closes in the background and catches up after', (
    tester,
  ) async {
    final feed = FakeFeed()..liveNow.value = true;
    await pump(tester, feed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(feed.pauses, 1);
    final reads = trackingReads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));
    expect(feed.starts, 2);
    expect(trackingReads, reads + 1, reason: 'one read to catch up');
  });
}
