import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/subadmin/coordinator_nav.dart';
import 'package:replit/screens/subadmin/dispatch_screen.dart';
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

  group('dispatch asks only who is going', () {
    late List<Map<String, dynamic>> dispatched;

    ApiClient api({List<Map<String, dynamic>> fleet = const []}) => ApiClient(
      client: MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/available-responders')) {
          return http.Response(jsonEncode([
            {'id': 'u1', 'full_name': 'Juan Dela Cruz', 'agency_type': 'fire_volunteer'},
            {'id': 'u2', 'full_name': 'Maria Santos', 'agency_type': 'fire_volunteer', 'is_busy': true},
            {'id': 'u3', 'full_name': 'Leo Reyes', 'agency_type': 'fire_volunteer', 'on_this_incident': true},
          ]), 200);
        }
        if (path == '/equipment') return http.Response(jsonEncode(fleet), 200);
        if (path.endsWith('/dispatch')) {
          dispatched.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'id': 'a1'}), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    setUp(() => dispatched = []);

    testWidgets('nothing is required but choosing people', (tester) async {
      await pump(tester, DispatchScreen(areaId: 'a1', api: api()));
      expect(find.text('CHOOSE WHO IS GOING'), findsOneWidget);

      await tester.tap(find.text('Juan Dela Cruz'));
      await tester.tap(find.text('Maria Santos'));
      await tester.pump();
      await tester.tap(find.text('DISPATCH 2 RESPONDERS'));
      await tester.pumpAndSettle();

      expect(dispatched.map((d) => d['responder_id']), ['u1', 'u2']);
      // No truck, driver or role was asked for — those go in the report.
      for (final d in dispatched) {
        expect(d.containsKey('vehicle_name'), isFalse);
        expect(d.containsKey('crew_role'), isFalse);
      }
    });

    testWidgets('someone already responding cannot be sent twice', (tester) async {
      await pump(tester, DispatchScreen(areaId: 'a1', api: api()));
      expect(find.text('RESPONDING'), findsOneWidget);
      await tester.tap(find.text('Leo Reyes'));
      await tester.pump();
      expect(find.text('CHOOSE WHO IS GOING'), findsOneWidget);
    });

    testWidgets('a truck can be tagged when it is known', (tester) async {
      await pump(
        tester,
        DispatchScreen(
          areaId: 'a1',
          api: api(fleet: [
            {'id': 'e1', 'name': 'Apollo', 'category': 'fire_truck', 'status': 'available'},
            {'id': 'e2', 'name': 'Hermes', 'category': 'fire_truck', 'status': 'in_use'},
          ]),
        ),
      );
      expect(find.text('Hermes'), findsNothing, reason: 'a truck on another call is not offered');
      await tester.tap(find.text('Apollo'));
      await tester.tap(find.text('Juan Dela Cruz'));
      await tester.pump();
      await tester.tap(find.text('DISPATCH 1 RESPONDER'));
      await tester.pumpAndSettle();
      expect(dispatched.single['vehicle_name'], 'Apollo');
    });

    testWidgets('an empty register means no unit row, not a demo fleet', (tester) async {
      await pump(tester, DispatchScreen(areaId: 'a1', api: api()));
      expect(find.text('UNIT · OPTIONAL'), findsNothing);
      expect(find.text('Apollo'), findsNothing);
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
        client: MockClient((req) async => http.Response(jsonEncode([
          {'id': 's1', 'latitude': 14.54, 'longitude': 121.0, 'outside_pasay': false},
          {'id': 's2', 'latitude': 14.48, 'longitude': 121.02, 'outside_pasay': true},
        ]), 200)),
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
          child: TextButton(onPressed: () => onTap(context), child: const Text('GO')),
        ),
      ),
    );

    ApiClient reportApi() => ApiClient(
      client: MockClient((req) async => http.Response(
        jsonEncode(req.url.path.endsWith('/dispatches') || req.url.path == '/equipment'
            ? []
            : {'id': 'a4', 'designation': 'Area 11', 'status': 'post_incident_report'}),
        200,
      )),
    );

    testWidgets('"later" leaves the report in the tray and says so', (tester) async {
      await pump(tester, launcher((ctx) => offerPostIncidentReport(ctx, areaId: 'a4')));
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
        launcher((ctx) => offerPostIncidentReport(ctx, areaId: 'a4', api: reportApi())),
      );
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FILE NOW'));
      await tester.pumpAndSettle();
      expect(find.byType(PostIncidentReportScreen), findsOneWidget);
    });

    testWidgets('a coordinator opening a report-due incident lands on the report', (tester) async {
      await pump(
        tester,
        launcher((ctx) => openCoordinatorIncident(
              ctx,
              incident: const {'id': 'a4', 'designation': 'Area 11', 'status': 'post_incident_report'},
              me: const {'role': 'sub_admin', 'agency_type': 'bfp'},
              api: reportApi(),
            )),
      );
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
      expect(find.byType(PostIncidentReportScreen), findsOneWidget);
    });
  });
}
