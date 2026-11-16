import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/confirm_log_out.dart';
import 'package:replit/widgets/design.dart';

/// v1.12.47: Log out asks first (17 Nov 2026: "if the user press logout it
/// make it having a confirmation").
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<bool?> ask(WidgetTester tester, String tap) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await confirmLogOut(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    expect(find.textContaining('no fire alerts'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(tap)));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
    return answer;
  }

  testWidgets('Log out logs out; Cancel does not', (tester) async {
    expect(await ask(tester, 'log-out-confirm'), isTrue);
    expect(await ask(tester, 'log-out-cancel'), isFalse);
  });

  testWidgets('Profile asks before Log out, and Cancel keeps you in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asked = <String>[];
    final api = ApiClient(
      client: MockClient((req) async {
        asked.add('${req.method} ${req.url.path}');
        return http.Response('{}', 503);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ProfileScreen(api: api),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // AppButton shows its label in capitals.
    final logOut = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Log out',
    );
    await tester.scrollUntilVisible(
      logOut,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(logOut);
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('log-out-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(asked.where((a) => a.endsWith('/auth/logout')), isEmpty);
  });
}
