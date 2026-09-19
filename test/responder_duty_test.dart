import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/responder/responder_duty_screen.dart';
import 'package:replit/theme.dart';

/// "02 Duty — standby": what a responder sees before and during a run, and the
/// promise it does not make — no figure on this screen is invented.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const me = {
    'id': 'u9',
    'full_name': 'M. Bautista',
    'role': 'response_team',
    'agency_type': 'fire_volunteer',
    'organization_name': 'Tanker 1',
    'primary_org_id': 'org1',
  };

  ApiClient api({List<Map<String, dynamic>> incidents = const []}) => ApiClient(
    client: MockClient((req) async {
      if (req.url.path.endsWith('/incidents/stats')) {
        return http.Response(
          jsonEncode({
            'active_incidents': 2,
            'pending_verify': 1,
            'units_deployed': 3,
            'units_standby': 4,
            'pending_reports': 0,
          }),
          200,
        );
      }
      if (req.url.path.endsWith('/incidents')) {
        return http.Response(jsonEncode(incidents), 200);
      }
      return http.Response('[]', 200);
    }),
  );

  Future<void> pump(
    WidgetTester tester,
    ApiClient client, {
    double scale = 1,
    AppPalette pal = AppPalette.dark,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(pal),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: ResponderDutyScreen(me: me, api: client),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('standby reads off the API, at ${scale}x', (tester) async {
      await pump(tester, api(), scale: scale);
      expect(tester.takeException(), isNull);

      expect(find.text('DUTY'), findsOneWidget);
      expect(find.text('TANKER 1 · FIRE VOLUNTEER'), findsOneWidget);
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('NO RUN RIGHT NOW'), findsOneWidget);

      // The counters are the ones /incidents/stats actually returns.
      expect(find.text('2'), findsOneWidget, reason: 'live now');
      expect(find.text('3'), findsOneWidget, reason: 'units out');
      expect(find.text('LIVE NOW'), findsOneWidget);
      expect(find.text('UNITS OUT'), findsOneWidget);
      expect(
        find.textContaining('RUNS THIS MONTH'),
        findsNothing,
        reason: 'no endpoint counts a responder past runs',
      );

      expect(find.text('LOCATION SHARING'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);
    });
  }

  testWidgets('a run replaces the standby card and arms the disc', (
    tester,
  ) async {
    await pump(
      tester,
      api(
        incidents: [
          {
            'id': 'i1',
            'designation': 'Area 5.1',
            'status': 'en_route',
            'barangay': 'Barangay 76',
            'i_am_dispatched': true,
          },
        ],
      ),
    );
    expect(find.text('ON A RUN'), findsOneWidget);
    expect(find.text('AREA 5.1'), findsOneWidget);
    expect(find.text('EN ROUTE'), findsOneWidget);
    expect(find.text('NO RUN RIGHT NOW'), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('the note says what this app can actually do', (tester) async {
    await pump(tester, api());
    expect(
      find.textContaining('A dispatch puts your unit on the run'),
      findsOneWidget,
      reason: 'the frame says "Accept", which is the v11 lifecycle',
    );
  });

  testWidgets('it draws in the light palette too', (tester) async {
    await pump(tester, api(), pal: AppPalette.light);
    expect(tester.takeException(), isNull);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppPalette.light.background);
  });
}
