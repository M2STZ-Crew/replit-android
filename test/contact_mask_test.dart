import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/privacy/contact_mask.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/theme.dart';

/// The resident's email and mobile on Profile are masked until the eye is
/// tapped, like a wallet app's balance (the 5 November issue list, 1.1).
void main() {
  group('the masks', () {
    test('an email keeps two letters of the name and its domain', () {
      expect(ContactMask.email('m.reyes@gmail.com'), 'm.••••@gmail.com');
      expect(ContactMask.email('juan@yahoo.com'), 'ju••••@yahoo.com');
      expect(ContactMask.email('a@b.ph'), 'a••••@b.ph');
      expect(ContactMask.email('ab@b.ph'), 'a••••@b.ph');
    });

    test('the dots never give away how long the name is', () {
      expect(ContactMask.email('ab12345678901234@x.com'), 'ab••••@x.com');
    });

    test('a PH mobile keeps its 09 and last two digits, in any shape', () {
      for (final raw in [
        '+639171234567',
        '639171234567',
        '09171234567',
        '9171234567',
        '0917 123 4567',
      ]) {
        expect(ContactMask.mobile(raw), '09•• ••• ••67', reason: raw);
      }
    });

    test('anything else keeps only its ends', () {
      expect(ContactMask.mobile('+1 415 555 0100'), '+1••••00');
      expect(ContactMask.mobile('123'), '••••');
    });
  });

  group('on Profile', () {
    ApiClient api() => ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/verification/status')) {
          return http.Response('{"channels":[]}', 200);
        }
        return http.Response(
          jsonEncode({
            'id': 'u1',
            'email': 'm.reyes@gmail.com',
            'full_name': 'Maria Reyes',
            'role': 'general_user',
            'mobile': '+639171234567',
          }),
          200,
        );
      }),
    );

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ProfileScreen(api: api()),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ContactMask.reset();
    });

    testWidgets('masked at first; the eye shows them, and hides them again', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('m.••••@gmail.com'), findsOneWidget);
      expect(find.text('09•• ••• ••67'), findsOneWidget);
      expect(find.text('m.reyes@gmail.com'), findsNothing);
      expect(find.bySemanticsLabel('Show email and mobile'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('contact-mask-toggle')));
      await tester.pump();
      expect(find.text('m.reyes@gmail.com'), findsOneWidget);
      expect(find.text('+639171234567'), findsOneWidget);
      expect(find.bySemanticsLabel('Hide email and mobile'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('contact-mask-toggle')));
      await tester.pump();
      expect(find.text('m.••••@gmail.com'), findsOneWidget);
    });

    testWidgets('the choice is kept on the phone', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('contact-mask-toggle')));
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('contact_hidden_v1'), isFalse);

      // The next launch reads it back.
      ContactMask.reset();
      await ContactMask.load();
      expect(ContactMask.hidden.value, isFalse);
    });
  });
}
