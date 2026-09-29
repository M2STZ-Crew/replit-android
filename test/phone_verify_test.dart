import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/phone_gate.dart';
import 'package:replit/screens/phone_verify_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

/// Phone verification through Semaphore, and the gate it is for a resident.
void main() {
  late List<Map<String, dynamic>> requested;
  late int verified;

  http.Response json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status);

  http.Response sent() => json(200, {
    'message': 'We texted a code to +639171234567. It expires in 5 minutes.',
    'phone': '+639171234567',
    'sent': true,
    'expires_in_seconds': 300,
    'resend_after_seconds': 60,
  });

  setUp(() {
    requested = [];
    verified = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool gate = true,
    String? initialPhone,
    required Future<http.Response> Function(http.Request) server,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.body.isNotEmpty) {
          requested.add(jsonDecode(req.body) as Map<String, dynamic>);
        }
        return server(req);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: PhoneVerifyScreen(
              gate: gate,
              initialPhone: initialPhone,
              api: api,
              onVerified: () => verified++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('the gate: help and a way out, no way back, at ${scale}x', (
      tester,
    ) async {
      await pump(tester, server: (_) async => sent(), scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('Verify your number'), findsOneWidget);
      expect(find.text('Emergency now? Call 911'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byType(BackWell), findsNothing);
      expect(PhoneGate.isShowing, isTrue);
    });
  }

  testWidgets('from Verification it is an ordinary screen', (tester) async {
    await pump(tester, gate: false, server: (_) async => sent());
    expect(find.byType(BackWell), findsOneWidget);
    expect(find.text('Emergency now? Call 911'), findsNothing);
    expect(find.textContaining('40%'), findsOneWidget);
  });

  testWidgets('the number from sign-up is filled in, written locally', (
    tester,
  ) async {
    await pump(
      tester,
      initialPhone: '+639171234567',
      server: (_) async => sent(),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '0917 123 4567',
    );
  });

  testWidgets('a local number is sent as typed, then a countdown', (
    tester,
  ) async {
    await pump(tester, server: (_) async => sent());
    await tester.enterText(find.byType(TextField), '0917 123 4567');
    await tap(tester, 'SEND CODE');

    expect(requested.single['phone'], '0917 123 4567');
    expect(
      find.text('Enter the code we sent to 0917 123 4567.'),
      findsOneWidget,
    );
    expect(find.text('Send again in 60 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Send again in 59 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Send the code again'), findsOneWidget);
  });

  testWidgets('a number that cannot be a PH mobile is not sent', (
    tester,
  ) async {
    await pump(tester, server: (_) async => sent());
    await tester.enterText(find.byType(TextField), '12345');
    await tap(tester, 'SEND CODE');
    expect(requested, isEmpty);
    expect(
      find.text('Enter a mobile number like 0917 123 4567.'),
      findsOneWidget,
    );
  });

  testWidgets("the server's wait is the countdown", (tester) async {
    await pump(
      tester,
      server: (_) async => json(429, {
        'error': 'phone_code_cooldown',
        'message':
            'We just sent a code. You can ask for another in 42 seconds.',
        'details': {'retry_after_seconds': 42},
      }),
    );
    await tester.enterText(find.byType(TextField), '09171234567');
    await tap(tester, 'SEND CODE');
    expect(find.text('Send again in 42 s'), findsOneWidget);
    expect(find.text('VERIFY CODE'), findsOneWidget, reason: 'type the code');
  });

  testWidgets('SMS not set up reads as plain words, not config', (
    tester,
  ) async {
    await pump(
      tester,
      server: (_) async => json(503, {
        'error': 'semaphore_not_configured',
        'message': 'SMS is not configured (set SEMAPHORE_API_KEY in .env).',
      }),
    );
    await tester.enterText(find.byType(TextField), '09171234567');
    await tap(tester, 'SEND CODE');
    expect(
      find.text('We cannot send texts right now. Please try again later.'),
      findsOneWidget,
    );
    expect(find.textContaining('SEMAPHORE'), findsNothing);
  });

  testWidgets('a wrong code says how many tries are left; the right one lets '
      'them in', (tester) async {
    await pump(
      tester,
      server: (req) async {
        if (req.url.path.endsWith('/request')) return sent();
        final code = (jsonDecode(req.body) as Map)['code'];
        return code == '482913'
            ? json(200, {
                'verified': true,
                'verified_percent': 40,
                'badge': 'light_green',
                'message': 'Your number is verified.',
              })
            : json(400, {
                'error': 'bad_request',
                'message': 'That code is wrong. 4 tries left.',
                'details': {'reason': 'wrong_code', 'attempts_left': 4},
              });
      },
    );
    await tester.enterText(find.byType(TextField), '09171234567');
    await tap(tester, 'SEND CODE');

    await tester.enterText(find.byType(TextField), '000000');
    await tap(tester, 'VERIFY CODE');
    expect(find.text('That code is wrong. 4 tries left.'), findsOneWidget);
    expect(verified, 0);

    await tester.enterText(find.byType(TextField), '482913');
    await tap(tester, 'VERIFY CODE');
    expect(verified, 1);
  });

  testWidgets('a number already verified on the account goes straight in', (
    tester,
  ) async {
    await pump(
      tester,
      server: (_) async => json(200, {
        'message': 'This number is already verified on your account.',
        'phone': '+639171234567',
        'sent': false,
        'expires_in_seconds': 0,
        'resend_after_seconds': 0,
      }),
    );
    await tester.enterText(find.byType(TextField), '09171234567');
    await tap(tester, 'SEND CODE');
    expect(verified, 1);
  });

  test('the gate trips once, however many requests are refused', () {
    var opened = 0;
    PhoneGate.onTrip = () {
      opened++;
      PhoneGate.opened();
    };
    addTearDown(() {
      PhoneGate.onTrip = null;
      PhoneGate.closed();
    });
    PhoneGate.trip();
    PhoneGate.trip();
    PhoneGate.trip();
    expect(opened, 1);
  });
}
