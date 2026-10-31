import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/push_service.dart';
import 'package:replit/models/hotline.dart';
import 'package:replit/screens/call_screen.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/screens/role_gate.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/app_nav_bar.dart';
import 'package:replit/widgets/design.dart';

/// The 30 Oct 2026 issue report, where it touches the phone.
///
/// The rest is beside what it changed: "I am safe" in citizen_flow_test.dart,
/// the Route button in coordinator_experience_test.dart, alarm levels in
/// alarm_escalation_test.dart.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(402, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: home));
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('Issue 05: hotlines with no account and no signal', () {
    // No server at all: every request fails, as it does offline.
    ApiClient offline() => ApiClient(
      client: MockClient((_) async => throw const SocketException('offline')),
    );

    testWidgets('Sign in leads to every number, with nothing asked', (
      tester,
    ) async {
      await pump(tester, LoginScreen(api: offline()));
      expect(find.text('EMERGENCY HOTLINES'), findsOneWidget);
      await tester.ensureVisible(find.text('EMERGENCY HOTLINES'));
      await tester.tap(find.text('EMERGENCY HOTLINES'));
      await tester.pumpAndSettle();

      expect(find.text('CALL FOR HELP'), findsOneWidget);
      expect(find.text('911'), findsOneWidget);
      expect(find.text('8 numbers'.toUpperCase()), findsOneWidget);
    });

    testWidgets('a guest has no way on to the rest of the app', (tester) async {
      await pump(tester, const CallScreen(guest: true));
      expect(find.byType(AppNavBar), findsNothing);
      expect(find.byType(AvatarWell), findsNothing);

      await pump(tester, const CallScreen());
      expect(find.byType(AppNavBar), findsOneWidget, reason: 'signed in: tabs');
    });

    testWidgets('Back returns to sign in, and the form is as it was', (
      tester,
    ) async {
      await pump(tester, LoginScreen(api: offline()));
      await tester.enterText(find.byType(TextField).first, '0917 123 4567');
      await tester.ensureVisible(find.text('EMERGENCY HOTLINES'));
      await tester.tap(find.text('EMERGENCY HOTLINES'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackWell));
      await tester.pumpAndSettle();
      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text('0917 123 4567'), findsOneWidget);
    });

    testWidgets('an account that will not load still leads to them', (
      tester,
    ) async {
      await pump(tester, const RoleGate());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.text('Could not load your account.'), findsOneWidget);
      await tester.tap(find.text('Emergency hotlines'));
      await tester.pumpAndSettle();
      expect(find.text('CALL FOR HELP'), findsOneWidget);
      expect(find.byType(AppNavBar), findsNothing);
    });

    test('the numbers are the verified list, and dial as digits', () {
      expect(kHotlines, hasLength(8));
      expect(kHotlines.first.dialNumber, '911');
      for (final h in kHotlines) {
        expect(h.dialNumber, matches(RegExp(r'^\d{3,10}$')), reason: h.name);
      }
    });
  });

  group('Issue 06: signing in after a quiet spell', () {
    ApiClient server(
      Future<http.Response> Function(http.Request) answer, {
      List<String>? seen,
    }) => ApiClient(
      client: MockClient((req) {
        seen?.add('${req.method} ${req.url.path}');
        return answer(req);
      }),
    );

    Future<void> fill(WidgetTester tester) async {
      await tester.tap(find.text('Use email instead'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), 'me@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'not-a-real-one');
      await tester.ensureVisible(find.text('SIGN IN'));
      await tester.tap(find.text('SIGN IN'));
      await tester.pump();
    }

    testWidgets('the server is woken as the screen opens', (tester) async {
      final seen = <String>[];
      await pump(
        tester,
        LoginScreen(
          api: server((_) async => http.Response('{}', 200), seen: seen),
        ),
      );
      expect(seen, ['GET /health']);
    });

    testWidgets('a long wait says why, and a fast one never does', (
      tester,
    ) async {
      final reply = Completer<http.Response>();
      await pump(
        tester,
        LoginScreen(
          api: server(
            (r) => r.url.path == '/health'
                ? Future.value(http.Response('{}', 200))
                : reply.future,
          ),
        ),
      );
      await fill(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Still signing in'), findsNothing);

      await tester.pump(ApiClient.slowAfter);
      expect(find.textContaining('Still signing in'), findsOneWidget);

      reply.complete(
        http.Response(
          jsonEncode({'error': 'auth_error', 'message': 'Wrong'}),
          401,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Still signing in'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('no answer at all ends in words, not a spinner', (
      tester,
    ) async {
      await pump(
        tester,
        LoginScreen(
          api: server(
            (r) => r.url.path == '/health'
                ? Future.value(http.Response('{}', 200))
                : Completer<http.Response>().future,
          ),
        ),
      );
      await fill(tester);
      await tester.pump(ApiClient.signInTimeout);
      await tester.pump();
      expect(find.textContaining('did not answer in time'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('SIGN IN'), findsOneWidget, reason: 'it can be retried');
    });
  });

  group('Issue 07: a test alert', () {
    testWidgets('answers on its row: one banner, not two in a queue', (
      tester,
    ) async {
      var sent = 0;
      final api = ApiClient(
        client: MockClient((req) async {
          if (req.url.path == '/devices/test') {
            sent++;
            return http.Response('{"message":"Sent to 1 device(s)."}', 200);
          }
          if (req.url.path.endsWith('/verification/status')) {
            return http.Response('{"channels":[]}', 200);
          }
          return http.Response('{"id":"u1","role":"general_user"}', 200);
        }),
      );
      await pump(tester, ProfileScreen(api: api));
      await tester.ensureVisible(find.text('Send a test alert'));
      await tester.tap(find.text('Send a test alert'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(sent, 1);
      expect(find.textContaining('Sent. It should reach'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('its banner goes quickly, and a real alert keeps its 10 s', (
      tester,
    ) async {
      final key = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: key,
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      key.currentState!.showSnackBar(
        PushService.inAppBanner(
          title: 'RepLiT test',
          body: 'Push notifications are working.',
          fire: false,
          duration: PushService.testBannerFor,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('RepLiT test'), findsOneWidget);
      await tester.pump(PushService.testBannerFor);
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('RepLiT test'), findsNothing);
      expect(PushService.bannerFor, const Duration(seconds: 10));
    });
  });

  group('Issue 08: Center', () {
    test('no string the app shows spells it the other way', () {
      // Code inside a string ('${...centre...}') and widget keys are not text.
      final strings = RegExp(r"'[^']*[Cc]entre[^']*'");
      final code = RegExp(r'\$\{[^}]*\}?\)*\}?|ValueKey\([^)]*\)');
      final found = [
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart'))
            for (final (i, line) in file.readAsLinesSync().indexed)
              if (!line.trimLeft().startsWith('//') &&
                  strings.hasMatch(line.replaceAll(code, '')))
                '${file.path}:${i + 1}',
      ];
      expect(found, isEmpty);
    });
  });

  group('Issue 10: the location plate', () {
    double luminance(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final (hi, lo) = luminance(a) > luminance(b)
          ? (luminance(a), luminance(b))
          : (luminance(b), luminance(a));
      return (hi + 0.05) / (lo + 0.05);
    }

    testWidgets('one treatment, readable on both ends of the gradient', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: CoralPlate(Icons.place)));
      final icon = tester.widget<Icon>(find.byIcon(Icons.place));
      expect(icon.color, AppColors.accentText);
      for (final stop in [AppColors.gradientStart, AppColors.gradientEnd]) {
        expect(contrast(icon.color!, stop), greaterThan(4.5));
        // Why not white, which the resident's map used to draw.
        expect(contrast(Colors.white, stop), lessThan(3));
      }
    });

    test('every role draws it from the one widget', () {
      for (final path in [
        'lib/screens/map_screen.dart',
        'lib/screens/coordinator/map_tab.dart',
        'lib/screens/responder/field_map_tab.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('CoralPlate('),
          reason: path,
        );
      }
    });
  });

  group('Issue 02', () {
    test('the neighbourhood alert reads 150 m wherever it is named', () {
      for (final path in [
        'lib/screens/profile_screen.dart',
        'lib/screens/report_status_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('within 150 m'), reason: path);
        expect(source, isNot(contains('Fires reported within 300')));
        expect(source, isNot(contains('Neighbours within 300')));
      }
    });
  });
}
