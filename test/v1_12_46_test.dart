import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/sign_in_limits.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

/// v1.12.46 (backend v1.12.36): five wrong passwords for an account and it
/// waits; the app says how long, and what else to do.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the wait is said in whole minutes, rounded up', () {
    String? say(String code, [int? seconds]) => slowDownMessage(
      ApiException(
        429,
        'server words',
        code: code,
        details: seconds == null ? null : {'retry_after_seconds': seconds},
      ),
    );
    expect(say('too_many_attempts', 841), contains('Wait 15 min'));
    expect(say('too_many_attempts', 59), contains('Wait 1 min'));
    expect(say('too_many_attempts'), contains('Wait 15 min'));
    expect(say('too_many_attempts', 600), contains('Forgot password?'));
    expect(say('too_many_requests'), contains('Wait a few minutes'));
    expect(say('wrong_password'), isNull);
  });

  testWidgets('signing in to an account that has to wait says so', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
      client: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'error': 'too_many_attempts',
            'message': 'Too many wrong passwords for this account.',
            'details': {'retry_after_seconds': 600},
          }),
          429,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LoginScreen(api: api),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'you@email.com'),
      'm@x.ph',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Your password'),
      'guess-6',
    );
    await tester.tap(
      find.byWidgetPredicate((w) => w is AppButton && w.label == 'Sign in'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Wait 10 min'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
