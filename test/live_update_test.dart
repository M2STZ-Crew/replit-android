import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/live_update_screen.dart';
import 'package:replit/theme.dart';

/// "10 Live tracking": the resident's own incident, followed live.
void main() {
  ApiClient api({String status = 'dispatched', int reports = 3}) => ApiClient(
    client: MockClient((req) async {
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
      expect(find.text('DISPATCHED'), findsOneWidget);
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

  testWidgets('once resolved it says so and stops offering help', (
    tester,
  ) async {
    await pump(tester, api(status: 'post_incident_report'));
    expect(find.text('YOUR REPORT IS RESOLVED'), findsOneWidget);
    expect(find.text('NEED MORE HELP?'), findsNothing);
  });
}
