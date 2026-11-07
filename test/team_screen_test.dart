import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/subadmin/team_screen.dart';
import 'package:replit/theme.dart';

/// A coordinator's responder accounts (v1.12.4): where responders get their
/// accounts, with the address shown as the name is typed and the password
/// shown once.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const me = {
    'id': 'c1',
    'full_name': 'Ramon Dizon',
    'role': 'sub_admin',
    'agency_type': 'fire_volunteer',
  };

  late List<Map<String, dynamic>> sent;
  late List<String> calls;
  late List<Map<String, dynamic>> roster;

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      calls.add('${req.method} $path');
      if (path.endsWith('/email-preview')) {
        final first = req.url.queryParameters['first_name']!;
        final last = req.url.queryParameters['last_name']!;
        final base = '${first[0]}$last'.toLowerCase().replaceAll(' ', '');
        return http.Response(
          jsonEncode({'email': '$base.firres@replit.com'}),
          200,
        );
      }
      if (req.method == 'POST' && path == '/team/responders') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if ('${body['personal_email']}'.endsWith('@mailinator.com')) {
          return http.Response(
            jsonEncode({
              'error': 'disposable_email',
              'message': 'mailinator.com gives out temporary email addresses.',
              'details': {
                'field': 'personal_email',
                'domain': 'mailinator.com',
              },
            }),
            400,
          );
        }
        final made = {
          'id': 'r9',
          'full_name': '${body['first_name']} ${body['last_name']}',
          'email': 'jdelacruz.firres@replit.com',
          'agency_type': 'fire_volunteer',
          'is_active': true,
          'responding': false,
        };
        roster.add(made);
        sent.add(body);
        return http.Response(
          jsonEncode({
            'responder': made,
            'email': 'jdelacruz.firres@replit.com',
            'temporary_password': null,
            'personal_email': body['personal_email'],
            'invite_email_sent': true,
          }),
          201,
        );
      }
      if (path.endsWith('/deactivate')) {
        roster.first['is_active'] = false;
        return http.Response(jsonEncode(roster.first), 200);
      }
      if (path == '/team/responders') {
        return http.Response(jsonEncode(roster), 200);
      }
      return http.Response('[]', 200);
    }),
  );

  setUp(() {
    sent = [];
    calls = [];
    roster = [
      {
        'id': 'r1',
        'full_name': 'Miguel Bautista',
        'email': 'mbautista.firres@replit.com',
        'agency_type': 'fire_volunteer',
        'is_active': true,
        'responding': true,
      },
      {
        'id': 'r2',
        'full_name': 'Ana Cruz',
        'email': 'acruz.firres@replit.com',
        'agency_type': 'fire_volunteer',
        'is_active': false,
        'responding': false,
      },
    ];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: TeamScreen(me: me, api: api()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the roster: who is on a run, who is deactivated', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('RESPONDERS'), findsOneWidget, reason: 'the top bar');
    expect(find.text('Coordinator'), findsOneWidget);
    expect(find.text('Miguel Bautista'), findsOneWidget);
    expect(find.text('mbautista.firres@replit.com'), findsOneWidget);
    expect(find.text('On a run'), findsOneWidget);
    expect(find.text('Deactivated'), findsOneWidget);
    expect(find.text('1 ACTIVE'), findsOneWidget);
  });

  // The 6 November list: their own email instead of a mobile number, and
  // a link there to set the password, so nothing to hand over.
  testWidgets('a new responder: the address as the name is typed, and the '
      'link to set a password goes to their own email', (tester) async {
    await pump(tester);
    await tester.tap(find.text('NEW RESPONDER'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Juan');
    await tester.enterText(fields.at(1), 'Dela Cruz');
    await tester.pump(const Duration(milliseconds: 450)); // the debounce
    await tester.pump();
    expect(find.text('jdelacruz.firres@replit.com'), findsOneWidget);
    expect(find.text('Mobile (optional)'), findsNothing);
    await tester.enterText(fields.at(2), 'juan.delacruz@gmail.com');
    await tester.pump();

    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /team/responders'));
    expect(sent.single['personal_email'], 'juan.delacruz@gmail.com');
    expect(sent.single.containsKey('mobile'), isFalse);
    expect(find.text('Account ready'), findsOneWidget);
    expect(find.text('jdelacruz.firres@replit.com'), findsOneWidget);
    expect(
      find.textContaining('We emailed juan.delacruz@gmail.com'),
      findsOneWidget,
    );
    expect(find.text('Password'), findsNothing, reason: 'nothing to hand over');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Juan Dela Cruz'), findsOneWidget, reason: 'now listed');
  });

  testWidgets('a @replit.com address is not their own email', (tester) async {
    await pump(tester);
    await tester.tap(find.text('NEW RESPONDER'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Juan');
    await tester.enterText(fields.at(1), 'Dela Cruz');
    await tester.enterText(fields.at(2), 'jdelacruz.firres@replit.com');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.textContaining('have no mailbox'), findsOneWidget);
    expect(sent, isEmpty);
  });

  testWidgets('a temporary email address is refused, in the app\'s words', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('NEW RESPONDER'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Juan');
    await tester.enterText(fields.at(1), 'Dela Cruz');
    await tester.enterText(fields.at(2), 'juan@mailinator.com');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Temporary email addresses can't be used. Use an email that will "
        'last, like your Gmail.',
      ),
      findsOneWidget,
    );
    expect(find.text('Account ready'), findsNothing);
  });

  testWidgets('deactivating asks first, then turns the account off', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Miguel Bautista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEACTIVATE ACCOUNT'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('on a response now'),
      findsOneWidget,
      reason: 'they are told their run is released',
    );
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /team/responders/r1/deactivate'));
    expect(find.text('Deactivated'), findsNWidgets(2));
  });
}
