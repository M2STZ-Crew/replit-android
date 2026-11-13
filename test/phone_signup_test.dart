import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/models/phone_numbers.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/register_screen.dart';
import 'package:replit/screens/role_gate.dart';
import 'package:replit/theme.dart';

/// Email first (WHAT'S NEXT, 2.2): signing up and signing in take an email.
/// Until SMS is settled the mobile number is optional at sign-up (7 November)
/// and the email is checked instead, by a link to open in Gmail
/// (test/email_link_sheet_test.dart has the sheet). Then ([PhoneNumbers.open])
/// signing up with a number — the code taken in a sheet over the form — and
/// signing in with it.
void main() {
  late List<(String, Map<String, dynamic>)> calls;
  late Map<String, http.Response Function(Map<String, dynamic>)> routes;

  http.Response json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status);

  final session = {
    'access_token': 'access',
    'refresh_token': 'refresh',
    'user_id': '5b0f3c1e-8a55-4a5e-9d3c-1f2e3d4c5b6a',
    'email': 'juan@example.com',
  };

  setUp(() {
    calls = [];
    routes = {
      '/auth/signup': (_) => json(201, session),
      '/auth/login': (_) => json(200, session),
      '/verification/email/request': (_) => json(200, {
        'message': 'Verification email sent. Check your inbox.',
        'email': 'juan@example.com',
        'sent': true,
        'expires_in_seconds': 86400,
        'resend_after_seconds': 60,
      }),
      '/verification/status': (_) =>
          json(200, {'verified_percent': 0, 'badge': 'yellow', 'channels': []}),
      '/verification/phone/request': (_) => json(200, {
        'message': 'We texted a code to +639171234567.',
        'phone': '+639171234567',
        'sent': true,
        'expires_in_seconds': 300,
        'resend_after_seconds': 60,
      }),
      '/verification/phone/verify': (body) => body['code'] == '482913'
          ? json(200, {
              'verified': true,
              'verified_percent': 40,
              'badge': 'light_green',
              'message': 'Your number is verified.',
            })
          : json(400, {
              'error': 'bad_request',
              'message': 'That code is wrong. 4 tries left.',
            }),
    };
    SharedPreferences.setMockInitialValues({});
    Session.instance.accessToken = null;
  });

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      // The sign-in screen wakes the server as it opens; that says nothing
      // about what the screen sends.
      if (req.url.path == '/health') return json(200, {'status': 'ok'});
      final body = req.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(req.body) as Map<String, dynamic>;
      calls.add((req.url.path, body));
      final route = routes[req.url.path];
      return route == null ? json(404, {'message': 'nope'}) : route(body);
    }),
  );

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder field(String hint) =>
      find.ancestor(of: find.text(hint), matching: find.byType(TextField));

  /// The field under the label [label].
  Finder labeled(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );

  Future<void> fillSignup(
    WidgetTester tester, {
    String? mobile = '0917 123 4567',
    String first = 'Juan',
    String last = 'dela Cruz',
  }) async {
    await tester.enterText(labeled('First name'), first);
    await tester.enterText(labeled('Last name'), last);
    if (mobile != null) await tester.enterText(field('09XX XXX XXXX'), mobile);
    await tester.enterText(field('you@email.com'), 'juan@example.com');
    await tester.enterText(field('At least 8 characters'), 'long-enough-1');
    await tap(tester, find.textContaining('I agree that my location'));
  }

  List<String> paths() => [for (final c in calls) c.$1];

  // 7 November: first name, last name and email are required; the mobile
  // number is optional while SMS is unavailable.
  group('sign up, email first', () {
    testWidgets('first and last name, then the email, then the optional '
        'mobile number', (tester) async {
      await pump(tester, RegisterScreen(api: api()));
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(labeled('First name')), lessThan(top(labeled('Last name'))));
      expect(top(labeled('Last name')), lessThan(top(field('you@email.com'))));
      expect(
        top(field('you@email.com')),
        lessThan(top(field('09XX XXX XXXX'))),
      );
      expect(find.text('Mobile number (optional)'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('09XX XXX XXXX')).enabled,
        isNot(false),
      );
      expect(find.text('Checking it by SMS is coming soon.'), findsOneWidget);
    });

    testWidgets('the account is made with the email, and a link to confirm '
        'it is emailed in place of a texted code', (tester) async {
      await pump(tester, RegisterScreen(api: api()));
      expect(
        find.text(
          'You sign in with your email. We will email you a link to confirm '
          'it.',
        ),
        findsOneWidget,
      );
      await fillSignup(tester, mobile: null);
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(paths(), ['/auth/signup', '/verification/email/request']);
      expect(calls.first.$2['email'], 'juan@example.com');
      expect(calls.first.$2['full_name'], 'Juan dela Cruz');
      expect(calls.first.$2.containsKey('mobile'), isFalse);
      expect(find.text('ENTER THE CODE'), findsNothing);
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
      expect(find.textContaining('a link to juan@example.com'), findsOneWidget);

      // "Later" still goes on into the app; Profile asks again.
      await tap(tester, find.text('Later'));
      expect(find.text('CHECK YOUR EMAIL'), findsNothing);
      expect(find.byType(RoleGate), findsOneWidget);
    });

    testWidgets('a mobile number may be given, and no code is texted', (
      tester,
    ) async {
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester);
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(paths(), ['/auth/signup', '/verification/email/request']);
      expect(calls.first.$2['mobile'], '0917 123 4567');
      expect(find.text('ENTER THE CODE'), findsNothing);
      await tap(tester, find.text('Later'));
      expect(find.byType(RoleGate), findsOneWidget);
    });

    testWidgets('the email link sheet fits at a large font', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester, mobile: null);
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(tester.takeException(), isNull);
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
    });

    testWidgets('a temporary email address is refused, in the app\'s words, '
        'and nothing is sent to it', (tester) async {
      routes['/auth/signup'] = (_) => json(400, {
        'error': 'disposable_email',
        'message':
            'mailinator.com gives out temporary email addresses, which '
            'RepLiT cannot use. Use an email you will keep, such as Gmail or '
            'Yahoo.',
        'details': {'field': 'email', 'domain': 'mailinator.com'},
      });
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester, mobile: null);
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(
        find.text(
          "Temporary email addresses can't be used. Use an email that will "
          'last, like your Gmail.',
        ),
        findsOneWidget,
      );
      expect(paths(), ['/auth/signup']);
      expect(find.text('CHECK YOUR EMAIL'), findsNothing);
      expect(find.byType(RoleGate), findsNothing);
    });

    testWidgets('a number given has to be a PH mobile', (tester) async {
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester, mobile: '12345');
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(
        find.text('Enter your mobile number, like 0917 123 4567.'),
        findsOneWidget,
      );
      expect(calls, isEmpty);
    });

    for (final (missing, first, last, message) in [
      ('first', '', 'dela Cruz', 'Please enter your first name.'),
      ('last', 'Juan', '  ', 'Please enter your last name.'),
    ]) {
      testWidgets('the $missing name is required', (tester) async {
        await pump(tester, RegisterScreen(api: api()));
        await fillSignup(tester, mobile: null, first: first, last: last);
        await tap(tester, find.text('CREATE ACCOUNT'));
        expect(find.text(message), findsOneWidget);
        expect(calls, isEmpty);
      });
    }
  });

  group('sign up with a mobile number, once SMS is settled', () {
    setUp(() => PhoneNumbers.open = true);
    tearDown(() => PhoneNumbers.open = PhoneNumbers.live);

    testWidgets('asks for the mobile number', (tester) async {
      await pump(tester, RegisterScreen(api: api()));
      expect(find.text('Mobile number'), findsOneWidget);
    });

    testWidgets('a number that cannot be a PH mobile never leaves the phone', (
      tester,
    ) async {
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester, mobile: '12345');
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(
        find.text('Enter your mobile number, like 0917 123 4567.'),
        findsOneWidget,
      );
      expect(calls, isEmpty);
    });

    testWidgets('the account is made, a code is texted, and a sheet takes it', (
      tester,
    ) async {
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester);
      await tap(tester, find.text('CREATE ACCOUNT'));

      expect(paths(), ['/auth/signup', '/verification/phone/request']);
      expect(calls[0].$2['mobile'], '0917 123 4567');
      expect(calls[1].$2['phone'], '0917 123 4567');
      expect(find.text('ENTER THE CODE'), findsOneWidget);
      expect(
        find.textContaining('We sent a 6-digit code to 0917 123 4567'),
        findsOneWidget,
      );
      expect(find.text('Send again in 60 s'), findsOneWidget);

      // A wrong code keeps the sheet open and says so.
      await tester.enterText(field('••••••'), '000000');
      await tap(tester, find.text('VERIFY'));
      expect(find.text('That code is wrong. 4 tries left.'), findsOneWidget);
      expect(find.text('ENTER THE CODE'), findsOneWidget);

      // The right one closes it and goes on into the app.
      await tester.enterText(field('••••••'), '482913');
      await tap(tester, find.text('VERIFY'));
      expect(find.text('ENTER THE CODE'), findsNothing);
      expect(find.byType(RoleGate), findsOneWidget);
    });

    testWidgets('"Later" still goes on; the gate asks again there', (
      tester,
    ) async {
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester);
      await tap(tester, find.text('CREATE ACCOUNT'));
      await tap(tester, find.text('Later'));
      expect(find.byType(RoleGate), findsOneWidget);
      expect(paths(), isNot(contains('/verification/phone/verify')));
    });

    testWidgets('a number another account verified is refused, and no code '
        'is sent', (tester) async {
      routes['/auth/signup'] = (_) => json(409, {
        'error': 'phone_number_taken',
        'message':
            'This number is already used by another RepLiT account. Sign in '
            'with it, or use a different number.',
      });
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester);
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(find.textContaining('already used by another'), findsOneWidget);
      expect(find.text('ENTER THE CODE'), findsNothing);
      expect(paths(), ['/auth/signup']);
    });

    testWidgets('the sheet fits at a large font', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, RegisterScreen(api: api()));
      await fillSignup(tester);
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(tester.takeException(), isNull);
      expect(find.text('ENTER THE CODE'), findsOneWidget);
    });
  });

  group('sign in', () {
    // "New to the barangay app?" named the wrong place; the link reads in
    // capitals, in either language.
    testWidgets('the way to sign up: "New to the app? CREATE ACCOUNT"', (
      tester,
    ) async {
      addTearDown(LanguageChoice.reset);
      await pump(tester, LoginScreen(api: api()));
      expect(find.text('New to the app?'), findsOneWidget);
      expect(find.textContaining('barangay'), findsNothing);
      await tap(tester, find.text('CREATE ACCOUNT'));
      expect(find.byType(RegisterScreen), findsOneWidget);

      // A fresh screen: the one above still has Register open on top.
      LanguageChoice.current.value = AppLanguage.tl;
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, LoginScreen(api: api()));
      expect(find.text('Bago ka sa app?'), findsOneWidget);
      expect(find.text('GUMAWA NG ACCOUNT'), findsOneWidget);
      expect(find.text('Gusto mo bang maging affiliate?'), findsOneWidget);
      expect(find.text('MAGPAREHISTRO DITO'), findsOneWidget);
    });

    // 8 November: an organisation applies to join in the Admin console.
    testWidgets('"Want to be an affiliate? REGISTER HERE" opens the '
        'affiliation form', (tester) async {
      final opened = <Uri>[];
      await pump(
        tester,
        LoginScreen(
          api: api(),
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );
      expect(find.text('Want to be an affiliate?'), findsOneWidget);
      await tap(tester, find.text('REGISTER HERE'));
      expect(opened, [
        Uri.parse('https://replit-backend-5u9u.vercel.app/register'),
      ]);
    });

    testWidgets('no browser to open it: it says where the form is', (
      tester,
    ) async {
      await pump(tester, LoginScreen(api: api(), openLink: (_) async => false));
      await tap(tester, find.text('REGISTER HERE'));
      expect(
        find.text(
          'Could not open the page. Visit '
          'replit-backend-5u9u.vercel.app/register.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('by email, first', (tester) async {
      await pump(tester, LoginScreen(api: api()));
      expect(find.text('Email address'), findsOneWidget);
      await tester.enterText(field('you@email.com'), 'captain@example.com');
      await tester.enterText(field('Your password'), 'long-enough-1');
      await tap(tester, find.text('SIGN IN'));
      expect(calls.first.$1, '/auth/login');
      expect(calls.first.$2, {
        'email': 'captain@example.com',
        'password': 'long-enough-1',
      });
      // v1.12.42: then the account, so an Admin is kept out (WebOnly).
      expect(paths(), contains('/auth/me'));
      expect(find.byType(RoleGate), findsOneWidget);
    });

    testWidgets('the mobile number is greyed out, "Coming soon"', (
      tester,
    ) async {
      await pump(tester, LoginScreen(api: api()));
      expect(find.text('Use mobile number'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      await tester.tap(find.text('Use mobile number'));
      await tester.pump();
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Mobile number'), findsNothing);
    });

    testWidgets('a wrong email or password says so', (tester) async {
      routes['/auth/login'] = (_) => json(401, {
        'error': 'auth_error',
        'message': 'Invalid login credentials',
      });
      await pump(tester, LoginScreen(api: api()));
      await tester.enterText(field('you@email.com'), 'me@example.com');
      await tester.enterText(field('Your password'), 'nope');
      await tap(tester, find.text('SIGN IN'));
      expect(find.text('Wrong email or password.'), findsOneWidget);
      expect(find.byType(RoleGate), findsNothing);
    });

    group('once SMS is settled', () {
      setUp(() => PhoneNumbers.open = true);
      tearDown(() => PhoneNumbers.open = PhoneNumbers.live);

      Future<void> byNumber(WidgetTester tester) async {
        await pump(tester, LoginScreen(api: api()));
        await tap(tester, find.text('Use mobile number'));
        expect(find.text('Mobile number'), findsOneWidget);
      }

      testWidgets('by mobile number, from the link', (tester) async {
        await byNumber(tester);
        await tester.enterText(field('09XX XXX XXXX'), '0917 123 4567');
        await tester.enterText(field('Your password'), 'long-enough-1');
        await tap(tester, find.text('SIGN IN'));

        expect(calls.first.$1, '/auth/login');
        expect(calls.first.$2, {
          'phone': '0917 123 4567',
          'password': 'long-enough-1',
        });
        // v1.12.42: then the account, so an Admin is kept out (WebOnly).
        expect(paths(), contains('/auth/me'));
        expect(find.byType(RoleGate), findsOneWidget);
      });

      testWidgets('a wrong number or password says what to try', (
        tester,
      ) async {
        routes['/auth/login'] = (_) => json(401, {
          'error': 'auth_error',
          'message': 'Invalid login credentials',
        });
        await byNumber(tester);
        await tester.enterText(field('09XX XXX XXXX'), '09171234567');
        await tester.enterText(field('Your password'), 'nope');
        await tap(tester, find.text('SIGN IN'));
        expect(
          find.textContaining('Wrong mobile number or password.'),
          findsOneWidget,
        );
        expect(find.byType(RoleGate), findsNothing);
      });

      testWidgets('a landline is caught before sending', (tester) async {
        await byNumber(tester);
        await tester.enterText(field('09XX XXX XXXX'), '02 8123 4567');
        await tester.enterText(field('Your password'), 'x');
        await tap(tester, find.text('SIGN IN'));
        expect(
          find.text('Enter your mobile number, like 0917 123 4567.'),
          findsOneWidget,
        );
        expect(calls, isEmpty);
      });
    });
  });
}
