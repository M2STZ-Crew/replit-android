import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/my_reports_screen.dart';
import 'package:replit/theme.dart';

/// "17 My reports": counts, month groups, and each report's real standing.
void main() {
  final now = DateTime.now();
  final lastYear = DateTime(now.year - 1, 8, 14, 9, 41);

  Map<String, dynamic> report(
    String id, {
    required DateTime at,
    required List<String> agencies,
    String? status,
    String? designation,
    String? band,
    bool flagged = false,
  }) => {
    'id': id,
    'device_lat': 14.5378,
    'device_lng': 121.0014,
    'has_exif': true,
    'gps_discrepancy_flag': flagged,
    'selected_agencies': agencies,
    'user_verified_percent': 60,
    'created_at': at.toUtc().toIso8601String(),
    'area_id': status == null ? null : 'a-$id',
    'area_designation': designation,
    'area_status': status,
    'area_confidence_band': band,
  };

  ApiClient api(List<Map<String, dynamic>> reports) => ApiClient(
    client: MockClient((req) async {
      if (req.url.path.endsWith('/reports/mine')) {
        return http.Response(jsonEncode(reports), 200);
      }
      return http.Response('[]', 200);
    }),
  );

  final sample = [
    report(
      'r1',
      at: now,
      agencies: ['bfp', 'medical'],
      status: 'en_route',
      designation: 'Area 3',
      band: 'high',
    ),
    report('r2', at: now, agencies: ['police']),
    report(
      'r3',
      at: lastYear,
      agencies: ['fire_volunteer'],
      status: 'post_incident_report',
      designation: 'Area 1',
      flagged: true,
    ),
    report(
      'r4',
      at: lastYear,
      agencies: ['barangay'],
      status: 'rejected',
      designation: 'Area 2',
    ),
  ];

  setUp(() => SharedPreferences.setMockInitialValues({}));

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
            child: MyReportsScreen(api: client),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder list() => find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('counts and groups what was sent, at ${scale}x', (
      tester,
    ) async {
      await pump(tester, api(sample), scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('YOUR REPORTS'), findsOneWidget);
      expect(find.text('4'), findsOneWidget, reason: 'sent');
      expect(
        find.text('2'),
        findsOneWidget,
        reason: 'active — the en-route one and the one not yet grouped',
      );
      expect(find.text('1'), findsOneWidget, reason: 'resolved');
      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text('FIRE + MEDICAL REPORT'), findsOneWidget);
      expect(find.text('EN ROUTE'), findsOneWidget);
      expect(find.text('Area 3 · high confidence'), findsOneWidget);
      expect(find.text('Waiting to be grouped with others'), findsOneWidget);

      // Last year's, below the fold.
      await tester.scrollUntilVisible(
        find.text('AUGUST ${lastYear.year}'),
        200,
        scrollable: list(),
      );
      expect(
        find.text('AUGUST ${lastYear.year}'),
        findsOneWidget,
        reason: 'older months name a year',
      );
      await tester.scrollUntilVisible(
        find.text('Closed — it could not be confirmed'),
        200,
        scrollable: list(),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('14 August'), findsWidgets);
      expect(find.text('NOT CONFIRMED'), findsOneWidget);
    });
  }

  testWidgets('a filed Post-Incident Report reads as resolved', (tester) async {
    await pump(tester, api([sample[2]]));
    expect(find.text('RESOLVED'), findsWidgets);
    expect(find.text('Area 1 · resolved'), findsOneWidget);
    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('TRACK'), findsNothing);
    expect(
      find.textContaining('disagreed on where it was taken'),
      findsOneWidget,
    );
  });

  testWidgets('nothing sent says so plainly', (tester) async {
    await pump(tester, api([]));
    expect(find.text('NOTHING SENT YET'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
  });

  testWidgets('the footnote makes no claim the app cannot keep', (
    tester,
  ) async {
    await pump(tester, api(sample));
    await tester.scrollUntilVisible(
      find.textContaining('Other residents never see'),
      200,
      scrollable: list(),
    );
    expect(find.textContaining('on your phone'), findsNothing);
  });
}
