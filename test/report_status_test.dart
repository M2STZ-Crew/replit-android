import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/report_status_screen.dart';
import 'package:replit/theme.dart';

/// "09 Submitting" — "Getting you help". Every step it ticks is one the
/// server has done; the one it holds open is the coordinator's confirmation.
void main() {
  ApiClient api({String status = 'pending', int reports = 3}) => ApiClient(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'id': 'a1',
          'designation': 'Area 1.2',
          'status': status,
          'report_count': reports,
          'centroid_lat': 14.54,
          'centroid_lng': 121.0,
        }),
        200,
      ),
    ),
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
            child: ReportStatusScreen(
              designation: 'Area 1.2',
              lat: 14.54,
              lng: 121.0,
              submittedAt: DateTime(2026, 9, 11, 21, 38),
              areaId: 'a1',
              api: client,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('while a coordinator has not confirmed, at ${scale}x', (
      tester,
    ) async {
      await pump(tester, api(), scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('GETTING YOU HELP'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('CONFIRMING'), findsOneWidget);
      expect(find.text('Matched to Area 1.2'), findsOneWidget);
      expect(find.text('Within 300 m of an active area'), findsOneWidget);
      expect(find.text('Coordinator confirms it'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('TRACK IT LIVE'), findsOneWidget);
    });
  }

  testWidgets('the first report opens its own area', (tester) async {
    await pump(tester, api(reports: 1));
    expect(find.text('Area 1.2 opened'), findsOneWidget);
    expect(find.text('A new area — the first report here'), findsOneWidget);
  });

  testWidgets('once verified, the last step ticks', (tester) async {
    await pump(tester, api(status: 'verified'));
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('CONFIRMED'), findsOneWidget);
    expect(find.text('Responders are being assigned'), findsOneWidget);
  });

  testWidgets('a rejected report says so and offers no tracking', (
    tester,
  ) async {
    await pump(tester, api(status: 'rejected'));
    expect(find.text('Not confirmed'), findsOneWidget);
    expect(find.text('TRACK IT LIVE'), findsNothing);
  });
}
