import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/email_link_sheet.dart';

/// Confirming the email with a link (7 November: "instead of OTP, they will
/// confirm it via email in Gmail"). The last step of a resident's sign-up
/// while SMS is unavailable, and Profile > Verify next to the email.
void main() {
  const device = MethodChannel('replit/device');
  const gmail = 'juan.delacruz@gmail.com';

  late List<String> calls;
  late Map<String, http.Response Function()> routes;
  late List<MethodCall> opened;
  late bool mailOpens;
  bool? result;

  http.Response json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status);

  Map<String, dynamic> standing({required bool email}) => {
    'verified_percent': email ? 10 : 0,
    'badge': 'yellow',
    'channels': [
      if (email) {'type': 'email', 'status': 'verified'},
    ],
  };

  http.Response linkSent() => json(200, {
    'message': 'Verification email sent. Check your inbox.',
    'email': gmail,
    'sent': true,
    'expires_in_seconds': 86400,
    'resend_after_seconds': 60,
  });

  setUp(() {
    calls = [];
    opened = [];
    mailOpens = true;
    result = null;
    routes = {
      '/verification/email/request': linkSent,
      '/verification/status': () => json(200, standing(email: false)),
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, (call) async {
          opened.add(call);
          return mailOpens;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, null);
  });

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      calls.add(req.url.path);
      final route = routes[req.url.path];
      return route == null ? json(404, {'message': 'nope'}) : route();
    }),
  );

  List<String> requests() =>
      calls.where((p) => p == '/verification/email/request').toList();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The sheet over a page, as sign-up ([sendNow]) or Profile opens it.
  Future<void> open(
    WidgetTester tester, {
    String? email = gmail,
    bool sendNow = true,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = api();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await showEmailLinkSheet(
                  context,
                  email: email,
                  api: client,
                  sendNow: sendNow,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  TextButton button(WidgetTester tester, String label) => tester.widget(
    find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
  );

  test('a Gmail address is one Gmail holds', () {
    expect(isGmailAddress(gmail), isTrue);
    expect(isGmailAddress(' Juan@GoogleMail.com '), isTrue);
    expect(isGmailAddress('juan@yahoo.com'), isFalse);
    expect(isGmailAddress('gmail.com'), isFalse);
    expect(isGmailAddress(null), isFalse);
  });

  group('at sign-up', () {
    testWidgets('the link is sent as the sheet opens, and it says where to', (
      tester,
    ) async {
      await open(tester);
      expect(requests(), hasLength(1));
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
      expect(
        find.text(
          'We sent a link to $gmail. Open it in Gmail and tap Verify my '
          'email. It works for 24 hours.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Not in your inbox? Look in Spam or Promotions.'),
        findsOneWidget,
      );
      expect(find.text('Send again in 60 s'), findsOneWidget);
    });

    testWidgets('Open Gmail opens Gmail', (tester) async {
      await open(tester);
      await tap(tester, find.text('OPEN GMAIL'));
      expect(opened.single.method, 'openMailApp');
      expect(opened.single.arguments, {'gmail': true});
      expect(
        find.text('Open your email app and look for the email from RepLiT.'),
        findsNothing,
      );
    });

    testWidgets('when no email app opens, it says where to look', (
      tester,
    ) async {
      mailOpens = false;
      await open(tester);
      await tap(tester, find.text('OPEN GMAIL'));
      expect(
        find.text('Open your email app and look for the email from RepLiT.'),
        findsOneWidget,
      );
    });

    testWidgets("another address: the phone's email app", (tester) async {
      await open(tester, email: 'juan@yahoo.com');
      expect(
        find.text(
          'We sent a link to juan@yahoo.com. Open the email and tap Verify '
          'my email. It works for 24 hours.',
        ),
        findsOneWidget,
      );
      await tap(tester, find.text('OPEN YOUR EMAIL'));
      expect(opened.single.arguments, {'gmail': false});
    });

    testWidgets('Send again waits a minute, then sends a new link', (
      tester,
    ) async {
      await open(tester);
      expect(button(tester, 'Send again in 60 s').onPressed, isNull);
      await tester.pump(const Duration(seconds: 60));
      await tap(tester, find.text('Send the link again'));
      expect(requests(), hasLength(2));
      expect(find.text('Send again in 60 s'), findsOneWidget);
    });

    testWidgets('back from Gmail with the link opened: confirmed, and '
        'Continue goes on', (tester) async {
      await open(tester);
      routes['/verification/status'] = () => json(200, standing(email: true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(find.text('EMAIL CONFIRMED'), findsOneWidget);
      expect(find.text('$gmail is confirmed. Thank you!'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      await tap(tester, find.text('CONTINUE'));
      expect(find.text('EMAIL CONFIRMED'), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('a link opened on a computer counts too: the open sheet '
        'checks every few seconds', (tester) async {
      await open(tester);
      await tester.pump(EmailLinkSheet.checkEvery);
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
      routes['/verification/status'] = () => json(200, standing(email: true));
      await tester.pump(EmailLinkSheet.checkEvery);
      await settle(tester);
      expect(find.text('EMAIL CONFIRMED'), findsOneWidget);
    });

    testWidgets('"Later" goes on unconfirmed', (tester) async {
      await open(tester);
      await tap(tester, find.text('Later'));
      expect(find.text('CHECK YOUR EMAIL'), findsNothing);
      expect(result, isFalse);
    });

    testWidgets('no connection: it says so, and Send the link tries again', (
      tester,
    ) async {
      routes['/verification/email/request'] = () =>
          throw http.ClientException('offline');
      await open(tester);
      expect(find.text('CONFIRM YOUR EMAIL'), findsOneWidget);
      expect(
        find.text('Could not send the email. Check your connection.'),
        findsOneWidget,
      );
      routes['/verification/email/request'] = linkSent;
      await tap(tester, find.text('SEND THE LINK'));
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
      expect(
        find.text('Could not send the email. Check your connection.'),
        findsNothing,
      );
    });

    testWidgets('fits at a large font', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
    });

    testWidgets('in Tagalog', (tester) async {
      addTearDown(LanguageChoice.reset);
      LanguageChoice.current.value = AppLanguage.tl;
      await open(tester);
      expect(find.text('TINGNAN ANG EMAIL MO'), findsOneWidget);
      expect(find.text('BUKSAN ANG GMAIL'), findsOneWidget);
      expect(find.textContaining('Buksan ito sa Gmail'), findsOneWidget);
    });
  });

  group('from Profile', () {
    testWidgets('it waits for Send the link', (tester) async {
      await open(tester, sendNow: false);
      expect(calls, isEmpty);
      expect(find.text('CONFIRM YOUR EMAIL'), findsOneWidget);
      expect(
        find.text(
          "We'll email a link to $gmail. Opening it confirms the address.",
        ),
        findsOneWidget,
      );
      await tap(tester, find.text('SEND THE LINK'));
      expect(requests(), hasLength(1));
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
    });

    testWidgets('an address already confirmed has nothing to open', (
      tester,
    ) async {
      routes['/verification/email/request'] = () => json(200, {
        'message': 'Your email is already confirmed.',
        'email': gmail,
        'sent': false,
        'expires_in_seconds': 0,
        'resend_after_seconds': 0,
      });
      await open(tester, sendNow: false);
      await tap(tester, find.text('SEND THE LINK'));
      expect(find.text('EMAIL CONFIRMED'), findsOneWidget);
    });

    testWidgets('a link sent a moment ago still works: Send again counts '
        'down the rest', (tester) async {
      routes['/verification/email/request'] = () => json(429, {
        'error': 'email_link_cooldown',
        'message':
            'We just sent a link. You can ask for another in 42 seconds.',
        'details': {'retry_after_seconds': 42},
      });
      await open(tester, sendNow: false);
      await tap(tester, find.text('SEND THE LINK'));
      expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
      expect(find.text('Send again in 42 s'), findsOneWidget);
      expect(find.textContaining('We just sent a link'), findsNothing);
    });

    testWidgets("the day's links spent: it says so, and Send again stays off", (
      tester,
    ) async {
      routes['/verification/email/request'] = () => json(429, {
        'error': 'email_link_daily_limit',
        'message': 'That is all the links we can send today.',
        'details': {'retry_after_seconds': 80000},
      });
      await open(tester, sendNow: false);
      await tap(tester, find.text('SEND THE LINK'));
      expect(
        find.text(
          'That is all the links we can send today. Use the newest email '
          'we sent, or ask for another tomorrow.',
        ),
        findsOneWidget,
      );
      expect(button(tester, 'Send the link again').onPressed, isNull);
    });

    testWidgets('an account on a temporary address is told why it cannot '
        'be confirmed', (tester) async {
      routes['/verification/email/request'] = () => json(400, {
        'error': 'disposable_email',
        'message':
            'Your email is from a temporary email service, so it cannot be '
            'confirmed.',
        'details': {'field': 'email', 'domain': 'mailinator.com'},
      });
      await open(tester, email: 'juan@mailinator.com', sendNow: false);
      await tap(tester, find.text('SEND THE LINK'));
      expect(find.text('CONFIRM YOUR EMAIL'), findsOneWidget);
      expect(
        find.text(
          "Your email is from a temporary email service, so it can't be "
          'confirmed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an address not known yet reads "your email"', (tester) async {
      await open(tester, email: null, sendNow: false);
      expect(
        find.text(
          "We'll email a link to your email. Opening it confirms the address.",
        ),
        findsOneWidget,
      );
    });
  });
}
