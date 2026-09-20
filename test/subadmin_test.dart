import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/subadmin/coordinator_nav.dart';
import 'package:replit/screens/subadmin/post_incident_report_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/ops_layers.dart';

/// The team captain's side after v10: dispatch asks only who is going (§2.5),
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
