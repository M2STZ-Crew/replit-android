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
import 'package:replit/widgets/app_nav_bar.dart';

/// A report in progress is the thing the app is for until the fire is out:
/// it survives a restart, belongs to whoever sent it, and SOS leads back to it.
void main() {
  const me = 'm.reyes@gmail.com';

  ActiveReport report({String owner = me, DateTime? at}) => ActiveReport(
    owner: owner,
    reportId: 'r1',
    areaId: 'a1',
    designation: 'Area 1.2',
    lat: 14.5378,
    lng: 121.0014,
    submittedAt: at ?? DateTime.now(),
    agencies: const ['fire_volunteer', 'medical'],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = me;
  });

  group('the record', () {
    test('survives the app being closed', () async {
      await ActiveReportStore.start(report());
      ActiveReportStore.reset(); // a cold start
      await ActiveReportStore.load();

      final back = ActiveReportStore.mine;
      expect(back, isNotNull);
      expect(back!.reportId, 'r1');
      expect(back.areaId, 'a1');
      expect(back.agencies, ['fire_volunteer', 'medical']);
      expect(back.lat, 14.5378);
    });

    test('is never shown to someone else signing in', () async {
      await ActiveReportStore.start(report());
      Session.instance.email = 'someone.else@gmail.com';
      expect(ActiveReportStore.mine, isNull);
      Session.instance.email = me;
      expect(ActiveReportStore.mine, isNotNull, reason: 'still theirs');
    });

    test('lets go of a report nobody picked up after half a day', () async {
      await ActiveReportStore.start(
        report(at: DateTime.now().subtract(const Duration(hours: 13))),
      );
      expect(ActiveReportStore.mine, isNull);
    });

    test('finishing forgets it for good', () async {
      await ActiveReportStore.start(report());
      await ActiveReportStore.finish();
      ActiveReportStore.reset();
      await ActiveReportStore.load();
      expect(ActiveReportStore.mine, isNull);
    });

    test('a report that waited offline is followed once it lands', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'id': 'r-other',
                'area_id': 'a9',
                'device_lat': 14.6,
                'device_lng': 121.1,
              },
              {
                'id': 'r-queued',
                'area_id': 'a4',
                'area_designation': 'Area 4.1',
                'device_lat': 14.5378,
                'device_lng': 121.0014,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              },
            ]),
            200,
          ),
        ),
      );
      await ActiveReportStore.adoptDelivered(
        lat: 14.5378,
        lng: 121.0014,
        agencies: const ['police'],
        api: api,
      );
      final followed = ActiveReportStore.mine;
      expect(followed?.reportId, 'r-queued', reason: 'matched by exact fix');
      expect(followed?.areaId, 'a4');
      expect(followed?.designation, 'Area 4.1');
    });
  });

  group('SOS', () {
    ApiClient areaApi() => ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'id': 'a1',
            'designation': 'Area 1.2',
            'status': 'en_route',
            'report_count': 2,
          }),
          200,
        ),
      ),
    );

    late _Pops pops;

    Future<void> pumpBar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      pops = _Pops();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          navigatorObservers: [pops],
          home: const Scaffold(
            body: SizedBox.expand(),
            bottomNavigationBar: AppNavBar(active: AppTab.map),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('leads back to the report in progress', (tester) async {
      await ActiveReportStore.start(report());
      await pumpBar(tester);

      await tester.tap(find.bySemanticsLabel('SOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ReportStatusScreen), findsOneWidget);
      expect(
        find.text('HOLD TO SEND'),
        findsNothing,
        reason: 'not a blank dial for a second report of the same fire',
      );
    });

    testWidgets('opens the dial when nothing is in progress', (tester) async {
      await pumpBar(tester);
      await tester.tap(find.bySemanticsLabel('SOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ReportStatusScreen), findsNothing);
    });

    testWidgets('brings a covered report back to the front', (tester) async {
      await ActiveReportStore.start(report());
      await pumpBar(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));

      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: ReportStatusScreen.routeName),
          builder: (_) => ReportStatusScreen.of(report(), api: areaApi()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Something else on top of it — the live map, say.
      const cover = Key('cover');
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            key: cover,
            body: SizedBox.expand(),
            bottomNavigationBar: AppNavBar(active: AppTab.map),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(cover), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('SOS').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Popped back to the report — not a second copy pushed on top of it.
      expect(pops.landedOn, [ReportStatusScreen.routeName]);
      expect(find.byType(ReportStatusScreen), findsOneWidget);
      expect(find.text('ON THE WAY'), findsOneWidget);
    });
  });
}

/// Records which route each pop landed on.
class _Pops extends NavigatorObserver {
  final List<String?> landedOn = [];

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      landedOn.add(previousRoute?.settings.name);
}
