import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/screens/report_status_screen.dart';
import 'package:replit/theme.dart';

/// "09 Submitting" — "Getting you help" — followed the whole way to fire out.
/// Every step it ticks is one the server has done.
void main() {
  const me = 'm.reyes@gmail.com';

  /// An area that reads [status]; once merged, `/reports/mine` says where the
  /// report went.
  ApiClient api({
    String status = 'reported',
    int reports = 3,
    Map<String, String> areas = const {},
  }) => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/reports/mine')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'r1',
              'area_id': 'a2',
              'area_designation': 'Area 1.3',
              'device_lat': 14.54,
              'device_lng': 121.0,
            },
          ]),
          200,
        );
      }
      final id = path.split('/').last;
      return http.Response(
        jsonEncode({
          'id': id,
          'designation': id == 'a2' ? 'Area 1.3' : 'Area 1.2',
          'status': areas[id] ?? status,
          'report_count': reports,
          'centroid_lat': 14.54,
          'centroid_lng': 121.0,
        }),
        200,
      );
    }),
  );

  ActiveReport report() => ActiveReport(
    owner: me,
    reportId: 'r1',
    areaId: 'a1',
    designation: 'Area 1.2',
    lat: 14.54,
    lng: 121.0,
    submittedAt: DateTime.now(),
    agencies: const ['fire_volunteer'],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = me;
  });

  Future<void> pump(
    WidgetTester tester,
    ApiClient client, {
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
            child: ReportStatusScreen.of(report(), api: client),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder scroller() => find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  );

  Future<void> see(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 120, scrollable: scroller().first);

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('waiting to be accepted, at ${scale}x', (tester) async {
      await pump(tester, api(), scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('GETTING YOU HELP'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('CONFIRMING'), findsOneWidget);
      await see(tester, find.text('Waiting to be accepted'));
      expect(find.text('Now'), findsOneWidget);
      await see(tester, find.text('Fire out'));
      expect(find.text('Once responders are on scene'), findsOneWidget);
      expect(find.text('TRACK IT LIVE'), findsOneWidget);
      expect(find.text('Report a different emergency'), findsOneWidget);
      expect(find.text('DONE'), findsNothing, reason: 'nothing is over yet');
    });
  }

  testWidgets('the first report opens its own area', (tester) async {
    await pump(tester, api(reports: 1));
    expect(find.text('Area 1.2 opened'), findsOneWidget);
    expect(find.text('A new area — the first report here'), findsOneWidget);
  });

  testWidgets('accepted: responders are on the way', (tester) async {
    await pump(tester, api(status: 'en_route'));
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('ON THE WAY'), findsOneWidget);
    await see(tester, find.text('Accepted'));
    expect(find.text('Responders are on the way'), findsOneWidget);
  });

  testWidgets('on scene: fire out is the open step', (tester) async {
    await pump(tester, api(status: 'arrived'));
    expect(find.text('ON SCENE'), findsOneWidget);
    await see(tester, find.text('Responders are working on it'));
    expect(find.text('Responders reached the scene'), findsOneWidget);
  });

  for (final status in ['fire_out', 'post_incident_report', 'closed']) {
    testWidgets('$status reads as done and fire out', (tester) async {
      await pump(tester, api(status: status));
      expect(find.text('FIRE OUT'), findsWidgets);
      expect(find.text('REPORT DONE'), findsOneWidget);
      expect(
        find.textContaining('Responders have put the fire out'),
        findsOneWidget,
      );
      await see(tester, find.text('Your report is done'));
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('TRACK IT LIVE'), findsNothing);
    });
  }

  testWidgets('Done lets go of the report', (tester) async {
    await ActiveReportStore.start(report());
    await pump(tester, api(status: 'fire_out'));
    expect(ActiveReportStore.mine, isNotNull);

    await tester.tap(find.text('DONE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(ActiveReportStore.mine, isNull);
    final saved = (await SharedPreferences.getInstance()).getString(
      'active_report_v1',
    );
    expect(saved, isNull, reason: 'a relaunch should not bring it back');
  });

  testWidgets('a rejected report says so and offers no tracking', (
    tester,
  ) async {
    await pump(tester, api(status: 'rejected'));
    expect(find.text('NOT CONFIRMED'), findsOneWidget);
    expect(find.text('Not confirmed'), findsOneWidget);
    expect(find.text('TRACK IT LIVE'), findsNothing);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('Fire out'), findsNothing);
  });

  testWidgets('a merged area is followed to where the report went', (
    tester,
  ) async {
    await ActiveReportStore.start(report());
    await pump(tester, api(areas: {'a1': 'merged', 'a2': 'en_route'}));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Matched to Area 1.3'), findsOneWidget);
    expect(find.text('ON THE WAY'), findsOneWidget);
    expect(
      ActiveReportStore.mine?.areaId,
      'a2',
      reason: 'a relaunch should follow it to the new area too',
    );
  });
}
