import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/change_password_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/theme_choice.dart';
import 'package:replit/widgets/staff_account_section.dart';

/// Change password (WHAT'S NEXT, 1.2), the same screen for residents and
/// staff, and the staff Profile's account rows: language, light mode, password.
void main() {
  late List<Map<String, dynamic>> sent;
  late http.Response Function() reply;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    reply = () => http.Response('', 204);
  });

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      if (request.url.path == '/auth/me/password') {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return reply();
      }
      if (request.url.path == '/auth/me/personal-email') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if ('${body['email']}'.endsWith('@mailinator.com')) {
          return http.Response(
            jsonEncode({
              'error': 'disposable_email',
              'message': 'mailinator.com gives out temporary email addresses.',
              'details': {'field': 'email', 'domain': 'mailinator.com'},
            }),
            400,
          );
        }
        sent.add(body);
        return http.Response('{"message":"sent"}', 200);
      }
      return http.Response('{}', 200);
    }),
  );

  Future<void> open(WidgetTester tester, ApiClient client) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    ChangePasswordScreen.open(context, api: client),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );

  Future<void> fill(
    WidgetTester tester, {
    String current = 'old-password',
    String next = 'new-password-1',
    String? again,
  }) async {
    await tester.enterText(field('Current password'), current);
    await tester.enterText(field('New password'), next);
    await tester.enterText(field('New password again'), again ?? next);
    await tester.ensureVisible(find.text('CHANGE PASSWORD').last);
    await tester.tap(find.text('CHANGE PASSWORD').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('sends the current and the new password, and says it worked', (
    tester,
  ) async {
    await open(tester, api());
    await fill(tester);
    expect(sent.single, {
      'current_password': 'old-password',
      'new_password': 'new-password-1',
    });
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.textContaining('Password changed.'), findsOneWidget);
  });

  testWidgets('a mismatch or a short one never leaves the phone', (
    tester,
  ) async {
    await open(tester, api());
    await fill(tester, again: 'something-else');
    expect(
      find.text('The two new passwords are not the same.'),
      findsOneWidget,
    );
    await fill(tester, next: 'short');
    expect(
      find.text('Use 8 to 128 characters for the new password.'),
      findsOneWidget,
    );
    await fill(tester, next: 'old-password');
    expect(
      find.text('The new password is the same as the current one.'),
      findsOneWidget,
    );
    expect(sent, isEmpty);
  });

  testWidgets('a wrong current password says so, and stays signed in', (
    tester,
  ) async {
    reply = () => http.Response(
      jsonEncode({
        'error': 'wrong_password',
        'message': 'The current password is not right.',
      }),
      400,
    );
    await open(tester, api());
    await fill(tester);
    expect(find.text('That is not your current password.'), findsOneWidget);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  group('the staff Profile', () {
    tearDown(ThemeChoice.reset);

    testWidgets('has the language, light mode and the password', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [StaffAccountSection(api: api())],
            ),
          ),
        ),
      );
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Tagalog'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Theme opens the picker: System, Light, Dark.
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('THEME'), findsOneWidget);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(ThemeChoice.pick.value, ThemePick.light);
      expect(ThemeChoice.light.value, isTrue);

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    Future<void> section(WidgetTester tester, Map<String, dynamic> me) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [StaffAccountSection(api: api(), me: me)],
            ),
          ),
        ),
      );
    }

    // The 6 November list: a sign-in at @replit.com has no mailbox, so the
    // password links go to a personal email, which the Profile can add.
    testWidgets('a @replit.com sign-in adds its personal email', (
      tester,
    ) async {
      await section(tester, {'email': 'jdelacruz.firres@replit.com'});
      expect(
        find.text('Add one, so a forgotten password can be reset'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Personal email'));
      await tester.tap(find.text('Personal email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'juan@gmail.com');
      await tester.tap(find.text('SEND LINK'));
      await tester.pumpAndSettle();
      expect(sent.single, {'email': 'juan@gmail.com'});
      expect(
        find.text('We sent a link to juan@gmail.com. Open it to confirm.'),
        findsOneWidget,
      );
      expect(
        find.text('juan@gmail.com · open the link we sent'),
        findsOneWidget,
      );
    });

    testWidgets('a temporary email address is refused, in the app\'s words', (
      tester,
    ) async {
      await section(tester, {'email': 'jdelacruz.firres@replit.com'});
      await tester.ensureVisible(find.text('Personal email'));
      await tester.tap(find.text('Personal email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'juan@mailinator.com');
      await tester.tap(find.text('SEND LINK'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(
        find.text(
          "Temporary email addresses can't be used. Use an email that will "
          'last, like your Gmail.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a confirmed one says so, and other sign-ins have no row', (
      tester,
    ) async {
      await section(tester, {
        'email': 'obryan.fircor@replit.com',
        'personal_email': 'odyssey@gmail.com',
        'personal_email_verified': true,
      });
      expect(find.text('odyssey@gmail.com · confirmed'), findsOneWidget);

      await section(tester, {'email': 'captain@brigade.example.com'});
      expect(find.text('Personal email'), findsNothing);
    });
  });
}
