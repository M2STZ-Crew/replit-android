import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/api_config.dart';
import 'package:replit/screens/subadmin/ai_summaries_screen.dart';
import 'package:replit/theme.dart';

/// The coordinator's AI summaries (v1.12.5): every summarized incident as
/// "Summarized incident — M/D/YYYY", read as a note, the PDF downloaded in the
/// browser through a short-lived link. Nobody asks for a summary: one still
/// being written shows as such and the list checks back on its own.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const me = {
    'id': 'c1',
    'full_name': 'Ramon Dizon',
    'role': 'sub_admin',
    'agency_type': 'fire_volunteer',
  };

  late List<String> calls;
  late List<Map<String, dynamic>> items;
  late List<Uri> opened;
  int? listStatus;

  Map<String, dynamic> ready() => {
    'area_id': 'a1',
    'designation': 'Area 3',
    'status': 'closed',
    'reports_filed': 2,
    'teams': ['Hercules Fire Brigade', 'BFP Pasay'],
    'last_filed_at': '2026-10-05T01:00:00Z',
    'state': 'ready',
    'summary_text': 'A kitchen fire on Leveriza St. was put out in 40 minutes.',
    'model': 'deepseek-flash',
    // 5:30 PM UTC on the 4th is 1:30 AM on the 5th in the Philippines.
    'generated_at': '2026-10-04T17:30:00Z',
  };

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      calls.add('${req.method} $path');
      if (path == '/ai-summaries') {
        if (listStatus != null) {
          return http.Response(
            jsonEncode({
              'error': 'forbidden',
              'message': 'You do not have permission to read the AI summaries.',
            }),
            listStatus!,
          );
        }
        return http.Response(jsonEncode(items), 200);
      }
      if (req.method == 'POST' && path.endsWith('/report-link')) {
        return http.Response(
          jsonEncode({
            'path': '/incidents/a1/report-download?token=abc.123.sig',
            'expires_at': '2026-10-05T08:05:00Z',
          }),
          200,
        );
      }
      return http.Response('[]', 200);
    }),
  );

  setUp(() {
    calls = [];
    opened = [];
    listStatus = null;
    items = [ready()];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AiSummariesScreen(
          me: me,
          api: api(),
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  int listCalls() => calls.where((c) => c == 'GET /ai-summaries').length;

  test('the date is the Philippine day, written M/D/YYYY', () {
    expect(summaryDate('2026-10-04T17:30:00Z'), '10/5/2026');
    expect(summaryDate('2026-10-05T03:00:00+00:00'), '10/5/2026');
    expect(summaryTime('2026-10-04T17:30:00Z'), '1:30 AM');
    expect(summaryDate(null), '');
    expect(summaryDate('not a date'), '');
  });

  testWidgets('the list: one row per summarized incident', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('AI SUMMARIES'), findsOneWidget, reason: 'the top bar');
    expect(find.text('COORDINATOR'), findsOneWidget);
    expect(find.text('Summarized incident — 10/5/2026'), findsOneWidget);
    expect(
      find.text('Area 3 · Hercules Fire Brigade, BFP Pasay'),
      findsOneWidget,
    );
    expect(find.text('WRITING'), findsNothing);
  });

  testWidgets('a summary being written says so, and the list checks back on '
      'its own until it arrives', (tester) async {
    items = [
      {
        ...ready(),
        'state': 'writing',
        'summary_text': null,
        'model': null,
        'generated_at': null,
      },
    ];
    await pump(tester);
    expect(find.text('WRITING'), findsOneWidget);
    // Titled by the day the last team filed until the summary exists.
    expect(find.text('Summarized incident — 10/5/2026'), findsOneWidget);
    expect(listCalls(), 1);

    items = [ready()];
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(listCalls(), 2);
    expect(find.text('WRITING'), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    expect(listCalls(), 2, reason: 'nothing owed, nothing to check');
  });

  testWidgets('an older summary shows as updating while it is rewritten', (
    tester,
  ) async {
    items = [
      {...ready(), 'state': 'writing'},
      {
        ...ready(),
        'area_id': 'a2',
        'designation': 'Area 4',
        'state': 'unavailable',
        'summary_text': null,
        'generated_at': null,
      },
    ];
    await pump(tester);
    expect(find.text('UPDATING'), findsOneWidget);
    expect(find.text('NO SUMMARY'), findsOneWidget);
  });

  testWidgets('a summary opens as a note, and Download PDF hands the browser '
      'a link', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Summarized incident — 10/5/2026'));
    await tester.pumpAndSettle();

    expect(find.text('AI SUMMARY'), findsOneWidget, reason: 'the note');
    expect(
      find.text('A kitchen fire on Leveriza St. was put out in 40 minutes.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Written by AI (deepseek-flash)'),
      findsOneWidget,
    );
    expect(find.textContaining('on 10/5/2026 at 1:30 AM'), findsOneWidget);

    await tester.tap(find.text('DOWNLOAD PDF'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /incidents/a1/report-link'));
    expect(opened, [
      Uri.parse(
        '${ApiConfig.baseUrl}/incidents/a1/report-download?token=abc.123.sig',
      ),
    ]);
  });

  testWidgets('an incident with no summary still has its PDF', (tester) async {
    items = [
      {
        ...ready(),
        'state': 'unavailable',
        'summary_text': null,
        'model': null,
        'generated_at': null,
      },
    ];
    await pump(tester);
    await tester.tap(find.text('Summarized incident — 10/5/2026'));
    await tester.pumpAndSettle();
    expect(find.textContaining('the server has no AI key'), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-text')), findsNothing);
    await tester.tap(find.text('DOWNLOAD PDF'));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
  });

  testWidgets('no summaries yet', (tester) async {
    items = [];
    await pump(tester);
    expect(find.text('NO SUMMARIES YET'), findsOneWidget);
  });

  testWidgets('the server refusing says why', (tester) async {
    listStatus = 403;
    await pump(tester);
    expect(
      find.text('You do not have permission to read the AI summaries.'),
      findsOneWidget,
    );
  });
}
