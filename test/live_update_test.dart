import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/screens/live_update_screen.dart';
import 'package:replit/theme.dart';

/// "10 Live tracking": the resident's own incident, followed live.
void main() {
  /// What the server has on the resident's own report in this area.
  var asked = <String>['fire_volunteer'];
  final added = <List<String>>[];

  ApiClient api({String status = 'en_route', int reports = 3}) => ApiClient(
    client: MockClient((req) async {
      if (req.url.path.endsWith('/reports/mine')) {
        return http.Response(
          jsonEncode([
            {'id': 'r1', 'area_id': 'a1', 'selected_agencies': asked},
            {
              'id': 'r0',
              'area_id': 'a0',
              'selected_agencies': ['police'],
            },
          ]),
          200,
        );
      }
      if (req.url.path.endsWith('/request-agencies')) {
        final more = [
          for (final a in (jsonDecode(req.body)['agencies'] as List)) '$a',
        ];
        added.add(more);
        asked = {...asked, ...more}.toList();
        return http.Response(
          jsonEncode({'area_id': 'a1', 'agencies': asked, 'message': 'ok'}),
          200,
        );
      }
      if (req.url.path.endsWith('/map/evacuation-sites')) {
        return http.Response(
          jsonEncode([
            {
              'id': 's1',
              'name': 'Pasay Sports Complex',
              'latitude': 14.5390,
              'longitude': 121.0030,
              'is_active': true,
            },
          ]),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'id': 'a1',
          'designation': 'Area 1.2',
          'status': status,
          'report_count': reports,
          'centroid_lat': 14.5380,
          'centroid_lng': 121.0016,
          'reported_at': DateTime.now()
              .subtract(const Duration(minutes: 4))
              .toUtc()
              .toIso8601String(),
        }),
        200,
      );
    }),
  );

  setUp(() {
    asked = ['fire_volunteer'];
    added.clear();
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = 'm.reyes@gmail.com';
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
            child: LiveUpdateScreen(
              areaId: 'a1',
              lat: 14.5378,
              lng: 121.0014,
              alreadySelected: const ['fire_volunteer'],
              api: client,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('a live report, at ${scale}x', (tester) async {
      await pump(tester, api(), scale: scale);
      expect(tester.takeException(), isNull);

      expect(find.text('YOUR REPORT IS LIVE'), findsOneWidget);
      expect(find.text('Area 1.2'), findsOneWidget);
      expect(find.text('EN ROUTE'), findsOneWidget);
      expect(find.text('Reported 4 min ago'), findsOneWidget);
      expect(find.text('WHAT HAPPENS NEXT'), findsOneWidget);
      expect(find.text('2 neighbours confirmed'), findsOneWidget);
      // Below the fold at a large font scale; the sheet scrolls to it.
      await tester.scrollUntilVisible(
        find.text('Pasay Sports Complex'),
        150,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Pasay Sports Complex'), findsOneWidget);
      // No endpoint lets a resident call off a response, so no button does.
      expect(find.textContaining('STAND DOWN'), findsNothing);
    });
  }

  testWidgets('more help lists only what was not asked for', (tester) async {
    await pump(tester, api());
    await tester.scrollUntilVisible(
      find.text('CHOOSE WHO TO ADD'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('NEED MORE HELP?'), findsOneWidget);
    expect(find.text('FIRE DEPARTMENT'), findsNothing, reason: 'already asked');
    expect(find.text('MEDICAL SUPPORT'), findsOneWidget);
  });

  Finder sheet() => find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );

  testWidgets('help added on an earlier visit is not offered again', (
    tester,
  ) async {
    // Added last time; this visit was only told about the SOS choice.
    asked = ['fire_volunteer', 'medical'];
    await pump(tester, api());
    await tester.scrollUntilVisible(
      find.text('CHOOSE WHO TO ADD'),
      200,
      scrollable: sheet(),
    );
    expect(find.text('MEDICAL SUPPORT'), findsNothing);
    expect(find.text('FIRE DEPARTMENT'), findsNothing);
    expect(
      find.text('POLICE DEPARTMENT'),
      findsOneWidget,
      reason: 'police was asked for on a different incident',
    );
  });

  testWidgets('adding help takes it off the list and remembers it', (
    tester,
  ) async {
    await ActiveReportStore.start(
      ActiveReport(
        owner: 'm.reyes@gmail.com',
        reportId: 'r1',
        areaId: 'a1',
        lat: 14.5378,
        lng: 121.0014,
        submittedAt: DateTime.now(),
        agencies: const ['fire_volunteer'],
      ),
    );
    await pump(tester, api());
    await tester.scrollUntilVisible(
      find.text('CHOOSE WHO TO ADD'),
      200,
      scrollable: sheet(),
    );
    await tester.tap(find.text('MEDICAL SUPPORT'));
    await tester.pump();
    await tester.tap(find.text('ADD MORE HELP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(added, [
      ['medical'],
    ]);
    expect(find.text('MEDICAL SUPPORT'), findsNothing);
    expect(
      ActiveReportStore.mine?.agencies,
      containsAll(['fire_volunteer', 'medical']),
      reason: 'the next Track it live starts from this',
    );
  });

  testWidgets('once the fire is out it says so and stops offering help', (
    tester,
  ) async {
    await pump(tester, api(status: 'post_incident_report'));
    expect(find.text('YOUR REPORT IS FIRE OUT'), findsOneWidget);
    expect(find.text('NEED MORE HELP?'), findsNothing);
  });
}
