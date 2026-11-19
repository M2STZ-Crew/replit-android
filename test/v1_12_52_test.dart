import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/api/reporting_standing.dart';
import 'package:replit/models/area_view.dart';
import 'package:replit/screens/coordinator/area_decision_screen.dart';
import 'package:replit/screens/reporting_paused_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/coordinator_kit.dart';
import 'package:replit/widgets/report_gate.dart';

/// v1.12.52 (19 Nov 2026: "a false alarm or prank report can be temporarily
/// cannot report and has a progressive penalty"): a resident paused after
/// prank reports sees when they can report again, why, 911 and their appeal;
/// a coordinator rejects a fire as a prank.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReportingStanding.clear();
  });

  http.Response json(int status, Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  final until = DateTime.now().add(const Duration(hours: 20));
  String iso(DateTime at) => at.toUtc().toIso8601String();

  Map<String, dynamic> paused({bool lesson = false, String appeal = 'none'}) => {
    'can_report': false,
    'removed': false,
    'paused_until': iso(until),
    'verify_first_until': iso(until),
    'step': 1,
    'lesson_due': lesson ? 's1' : null,
    'strikes': [
      {
        'id': 's1',
        'step': 1,
        'status': 'active',
        'reason': 'Prank or misuse: no fire, and the photo was from the internet',
        'given_at': iso(DateTime.now().subtract(const Duration(hours: 4))),
        'starts_at': iso(DateTime.now().subtract(const Duration(hours: 4))),
        'pause_ends_at': iso(until),
        'verify_first_ends_at': iso(until),
        'expires_at': iso(DateTime.now().add(const Duration(days: 360))),
        'lesson_seen': !lesson,
        'can_appeal': appeal == 'none',
        'appeal_state': appeal,
        'appeal_text': appeal == 'pending' ? 'I saw smoke from burning leaves.' : null,
        'appeal_note': null,
      },
    ],
  };

  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('the standing knows when reporting is blocked, and why', () {
    final standing = ReportingStanding.fromJson(paused());
    expect(standing.blocksNow, isTrue);
    expect(standing.latest?.reason, contains('photo was from the internet'));
    expect(standing.latest?.canAppeal, isTrue);

    final removed = ReportingStanding.fromJson({
      ...paused(),
      'removed': true,
      'paused_until': null,
      'step': 4,
    });
    expect(removed.blocksNow, isTrue);

    final over = ReportingStanding.fromJson({
      ...paused(),
      'paused_until': iso(DateTime.now().subtract(const Duration(minutes: 1))),
    });
    expect(over.blocksNow, isFalse);
    expect(
      ReportingStanding.fromJson({'can_report': true, 'step': 0}).blocksNow,
      isFalse,
    );
  });

  test('a refusal is said in the app\'s words and known for the next tap', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => json(403, {
          'error': 'reporting_paused',
          'message': 'Your reporting is paused.',
          'details': {'removed': false, 'paused_until': iso(until), 'step': 2},
        }),
      ),
    );
    try {
      await api.getReportingStanding();
      fail('expected a refusal');
    } on ApiException catch (e) {
      expect(e.code, ReportingStanding.errorCode);
      expect(e.message, startsWith('You can send reports again on '));
      expect(e.message, endsWith('In an emergency, call 911.'));
    }
    expect(ReportingStanding.cached?.blocksNow, isTrue);
    expect(ReportingStanding.cached?.step, 2);
  });

  test('a strike\'s alert opens Reporting', () {
    expect(
      targetFor('report_strike', {'role': 'general_user'}),
      NotificationTarget.reporting,
    );
    expect(canOpen('report_strike', const {}), isTrue);
  });

  testWidgets('Reporting paused: until when, why, 911, and an appeal', (
    tester,
  ) async {
    final posts = <String, Object?>{};
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'POST') {
          posts[req.url.path] = req.body.isEmpty ? null : jsonDecode(req.body);
          return json(200, paused(appeal: 'pending')['strikes'][0] as Object);
        }
        return json(200, paused());
      }),
    );
    await show(tester, ReportingPausedScreen(api: api));

    expect(find.textContaining('You can send reports again on'), findsOneWidget);
    expect(find.byKey(const ValueKey('call-911')), findsOneWidget);
    expect(find.text('Emergency now? Call 911'), findsOneWidget);
    expect(find.textContaining('photo was from the internet'), findsOneWidget);
    expect(find.text('1st strike: reporting paused for 24 hours'), findsWidgets);

    final appeal = find.text('APPEAL THIS STRIKE');
    await tester.ensureVisible(appeal);
    await tester.tap(appeal);
    await tester.pumpAndSettle();
    // Too short to send.
    await tester.enterText(find.byKey(const ValueKey('appeal-text')), 'smoke');
    await tester.pump();
    await tester.tap(find.text('SEND APPEAL'));
    await tester.pump();
    expect(posts, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('appeal-text')),
      'I saw smoke from my neighbour burning leaves.',
    );
    await tester.pump();
    await tester.tap(find.text('SEND APPEAL'));
    await tester.pumpAndSettle();
    expect(posts['/report-strikes/me/s1/appeal'], {
      'text': 'I saw smoke from my neighbour burning leaves.',
    });
    expect(
      find.text('Appeal sent. You will get the answer in RepLiT.'),
      findsOneWidget,
    );
  });

  testWidgets('the lesson shows once a strike is new, and is recorded', (
    tester,
  ) async {
    final posts = <String>[];
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'POST') {
          posts.add(req.url.path);
          return http.Response('', 204);
        }
        return json(200, paused(lesson: true));
      }),
    );
    await show(tester, ReportingPausedScreen(api: api));
    await tester.pumpAndSettle();
    expect(find.text('What a false alarm costs'), findsWidgets);
    expect(find.textContaining('RA 9514'), findsOneWidget);
    await tester.tap(find.text('I UNDERSTAND'));
    await tester.pumpAndSettle();
    expect(posts, ['/report-strikes/me/s1/lesson']);
  });

  testWidgets('the SOS button opens Reporting paused, not the camera, once '
      'the phone knows', (tester) async {
    ReportingStanding.noteRefusal({
      'removed': false,
      'paused_until': iso(until),
      'step': 2,
    });
    final api = ApiClient(client: MockClient((_) async => json(200, paused())));
    await show(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => openReportCamera(context, api: api),
            child: const Text('SOS'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportingPausedScreen), findsOneWidget);
  });

  group('a coordinator rejects a fire', () {
    Future<RejectChoice?> reject(
      WidgetTester tester,
      Future<void> Function() choose,
    ) async {
      RejectChoice? choice;
      final area = AreaView({
        'id': 'a7',
        'designation': 'Area 7',
        'status': 'reported',
        'report_count': 1,
        'confidence_band': 'low',
        'reported_at': iso(DateTime.now().subtract(const Duration(minutes: 5))),
      });
      await show(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                choice = await showFrameSheet<RejectChoice>(
                  context,
                  builder: (_) => RejectSheet(area: area, reports: const []),
                );
              },
              child: const Text('Reject'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await choose();
      final button = find.text('REJECT AREA 7');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      return choice;
    }

    testWidgets('an honest mistake gives no strike', (tester) async {
      final choice = await reject(tester, () async {
        await tester.tap(find.text('False alarm — no fire found'));
        await tester.pump();
      });
      expect(choice?.prank, isFalse);
      expect(choice?.reason, 'False alarm — no fire found');
    });

    testWidgets('a prank needs what was found, and can be serious', (
      tester,
    ) async {
      final choice = await reject(tester, () async {
        final prank = find.text('Prank or misuse');
        await tester.ensureVisible(prank);
        await tester.tap(prank);
        await tester.pump();
        expect(
          find.text('The first resident who reported it gets a strike'),
          findsOneWidget,
        );
        // Not without what showed it was a prank.
        final button = find.text('REJECT AREA 7');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(find.byType(RejectSheet), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('prank-found')),
          'No fire, and the photo was from Facebook',
        );
        await tester.pump();
        final serious = find.text('Serious case');
        await tester.ensureVisible(serious);
        await tester.tap(serious);
        await tester.pump();
      });
      expect(choice?.prank, isTrue);
      expect(choice?.serious, isTrue);
      expect(
        choice?.reason,
        'Prank or misuse: No fire, and the photo was from Facebook',
      );
    });
  });
}
