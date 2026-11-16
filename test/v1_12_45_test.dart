import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/account_freeze.dart';
import 'package:replit/api/api_client.dart';
import 'package:replit/screens/delete_account_screen.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/store_build.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

/// v1.12.45: an account asked to be deleted is frozen for 30 days first, and
/// the privacy and account pages live on the residents' site.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const goes = '2026-12-15T17:00:00+00:00'; // 16 December, 1 AM in Manila

  test('the day it goes is said in Philippine time', () {
    expect(AccountFreeze.day(goes), '16 December 2026');
    expect(AccountFreeze.day(null), isNull);
    expect(AccountFreeze.notice(goes), contains('16 December 2026'));
    expect(AccountFreeze.notice(goes), contains('Restore my account'));
  });

  test('the policy pages are on the residents\' site, not the console', () {
    expect(PolicyLinks.privacy.host, 'reportwhatslit-app.vercel.app');
    expect(PolicyLinks.deleteAccount.host, 'reportwhatslit-app.vercel.app');
    expect(PolicyLinks.deleteAccount.path, '/delete-account');
  });

  test(
    'a request refused mid-session for a frozen account trips the sign-out',
    () async {
      String? tripped;
      AccountFreeze.onTrip = (deleteAfter) => tripped = deleteAfter;
      addTearDown(() => AccountFreeze.onTrip = null);
      final api = ApiClient(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'error': 'account_pending_deletion',
              'message':
                  'This account is set to be deleted on 16 December 2026.',
              'details': {'delete_after': goes},
            }),
            403,
          ),
        ),
      );
      await expectLater(
        api.restoreAccount(email: 'm@x.ph', password: 'p'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            AccountFreeze.errorCode,
          ),
        ),
      );
      expect(tripped, goes);
    },
  );

  testWidgets(
    'a frozen account signing in is offered Restore, then signs in again',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final asked = <String>[];
      var logins = 0;
      final api = ApiClient(
        client: MockClient((req) async {
          asked.add('${req.method} ${req.url.path}');
          if (req.url.path.endsWith('/auth/login')) {
            logins++;
            if (logins == 1) {
              return http.Response(
                jsonEncode({
                  'error': 'account_pending_deletion',
                  'message': 'frozen',
                  'details': {'delete_after': goes},
                }),
                403,
              );
            }
            // The second try stops here: enough to see it was made.
            return http.Response(
              jsonEncode({
                'error': 'invalid_credentials',
                'message': 'Invalid login credentials',
              }),
              401,
            );
          }
          if (req.url.path.endsWith('/auth/restore')) {
            expect(jsonDecode(req.body), {
              'email': 'm@x.ph',
              'password': 'secret-1',
            });
            return http.Response(
              jsonEncode({'message': 'Your account is restored.'}),
              200,
            );
          }
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }),
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
        'secret-1',
      );
      await tester.tap(
        find.byWidgetPredicate((w) => w is AppButton && w.label == 'Sign in'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore your account?'), findsOneWidget);
      expect(find.textContaining('16 December 2026'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('restore-account')));
      await tester.pumpAndSettle();

      expect(asked.where((a) => a == 'POST /auth/restore'), hasLength(1));
      expect(logins, 2, reason: 'signed in again after the restore');
    },
  );

  testWidgets('Delete my account freezes it and says the day it goes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/me/delete')) {
          return http.Response(
            jsonEncode({'delete_after': goes, 'message': 'frozen'}),
            200,
          );
        }
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: DeleteAccountScreen(api: api),
      ),
    );
    await tester.pump();
    expect(find.text('For 30 days'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'secret-1');
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final button = find.byKey(const ValueKey('delete-account-button'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.textContaining('frozen and will be deleted on 16 December 2026'),
      findsOneWidget,
    );
  });
}
