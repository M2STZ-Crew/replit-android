import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/i18n/language_switch.dart';
import 'package:replit/screens/splash_screen.dart';
import 'package:replit/theme.dart';

/// The app follows the account's language (WHAT'S NEXT, 1.3): a choice made in
/// the Admin console or on another phone reaches this one, unless this phone
/// has a choice of its own the account does not have yet.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LanguageChoice.reset();
    await Session.instance.clear();
  });
  tearDown(LanguageChoice.reset);

  test("the account's language is taken up", () async {
    await LanguageChoice.adopt('tl');
    expect(LanguageChoice.tagalog, isTrue);
    await LanguageChoice.adopt('en');
    expect(LanguageChoice.tagalog, isFalse);
    await LanguageChoice.adopt(null);
    expect(LanguageChoice.tagalog, isFalse);
  });

  test('a choice the account does not have yet stands over it', () async {
    await LanguageSwitch.choose(AppLanguage.tl); // signed out: not sent
    expect(LanguageChoice.unsaved, isTrue);
    await LanguageChoice.adopt('en');
    expect(LanguageChoice.tagalog, isTrue);
  });

  test('a choice that reaches the account is saved there', () async {
    Session.instance.accessToken = 'token';
    final sent = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        sent.add(request.body);
        return http.Response('', 204);
      }),
    );
    await LanguageSwitch.choose(AppLanguage.tl, api: api);
    expect(sent.single, jsonEncode({'language': 'tl'}));
    expect(LanguageChoice.unsaved, isFalse);
  });

  testWidgets('opening the app signed in, it starts in the account language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'push_enabled': false,
    });
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'id': 'u1',
            'role': 'general_user',
            'language': 'tl',
            'phone_verification_required': true,
          }),
          200,
        ),
      ),
    );
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: SplashScreen(api: api)),
    );
    await tester.pump(SplashScreen.shownAtLeast);
    await tester.pump(const Duration(seconds: 1));
    expect(LanguageChoice.tagalog, isTrue);
  });
}
