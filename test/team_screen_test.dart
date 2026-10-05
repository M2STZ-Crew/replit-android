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
        return http.Response(jsonEncode({'email': '$base.resfir@replit.com'}), 200);
      }
      if (req.method == 'POST' && path == '/team/responders') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final made = {
          'id': 'r9',
          'full_name': '${body['first_name']} ${body['last_name']}',
          'email': 'jdelacruz.resfir@replit.com',
          'agency_type': 'fire_volunteer',
          'is_active': true,
          'responding': false,
        };
        roster.add(made);
        return http.Response(
          jsonEncode({
            'responder': made,
            'email': 'jdelacruz.resfir@replit.com',
            'temporary_password': 'Kq7m-x3Rt-9pWa',
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
    calls = [];
    roster = [
      {
        'id': 'r1',
        'full_name': 'Miguel Bautista',
        'email': 'mbautista.resfir@replit.com',
        'agency_type': 'fire_volunteer',
        'is_active': true,
        'responding': true,
      },
      {
        'id': 'r2',
        'full_name': 'Ana Cruz',
        'email': 'acruz.resfir@replit.com',
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
    expect(find.text('COORDINATOR'), findsOneWidget);
    expect(find.text('Miguel Bautista'), findsOneWidget);
    expect(find.text('mbautista.resfir@replit.com'), findsOneWidget);
    expect(find.text('ON A RUN'), findsOneWidget);
    expect(find.text('DEACTIVATED'), findsOneWidget);
    expect(find.text('1 ACTIVE'), findsOneWidget);
  });

  testWidgets('a new responder: the address as the name is typed, then the '
      'password once', (tester) async {
    await pump(tester);
    await tester.tap(find.text('NEW RESPONDER'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Juan');
    await tester.enterText(fields.at(1), 'Dela Cruz');
    await tester.pump(const Duration(milliseconds: 450)); // the debounce
    await tester.pump();
    expect(find.text('jdelacruz.resfir@replit.com'), findsOneWidget);

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /team/responders'));
    expect(find.text('Account ready'), findsOneWidget);
    expect(find.text('Kq7m-x3Rt-9pWa'), findsOneWidget);
    expect(find.text('jdelacruz.resfir@replit.com'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Kq7m-x3Rt-9pWa'), findsNothing, reason: 'shown once');
    expect(find.text('Juan Dela Cruz'), findsOneWidget, reason: 'now listed');
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
    expect(find.text('DEACTIVATED'), findsNWidgets(2));
  });
}
