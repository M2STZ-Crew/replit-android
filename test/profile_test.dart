import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/app_version.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/models/verification_state.dart';
import 'package:replit/models/phone_numbers.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/screens/verification_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/app_icons.dart';
import 'package:replit/widgets/coordinator_kit.dart';

/// "15 Profile" and "16 Verification": every channel says where it really
/// stands, and no setting is shown that does nothing.
void main() {
  ApiClient api({String idStatus = '', String emailStatus = 'verified'}) =>
      ApiClient(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/verification/status')) {
            return http.Response(
              jsonEncode({
                'verified_percent': emailStatus == 'verified' ? 60 : 50,
                'badge': 'light_green',
                'channels': [
                  if (idStatus.isNotEmpty)
                    {'type': 'national_id', 'status': idStatus},
                  {'type': 'email', 'status': emailStatus},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'u1',
              'email': 'm.reyes@gmail.com',
              'full_name': 'Maria Antonette Reyes',
              'role': 'general_user',
              'verified_percent': 60,
              'badge': 'light_green',
              'mobile': null,
            }),
            200,
          );
        }),
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('profile', () {
    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('reads the account, at ${scale}x', (tester) async {
        await pump(tester, ProfileScreen(api: api()), scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('YOUR PROFILE'), findsOneWidget);
        expect(find.text('MARIA ANTONETTE REYES'), findsOneWidget);
        expect(find.text('60% verified'), findsOneWidget);
        expect(find.text('Add your National ID for +50%'), findsOneWidget);
        expect(find.text('VERIFIED'), findsOneWidget, reason: 'the email');
        expect(find.text('Not added yet'), findsOneWidget);
        expect(find.text('ADD'), findsOneWidget);
        expect(find.text('Barangay alerts'), findsOneWidget);
        // Switches with nothing behind them are not drawn (§2.7.1).
        expect(find.text('Share location always'), findsNothing);
      });
    }

    // 8 November: "the components in coordinator have a logo (like change
    // password has a key), while citizen hasn't". The same rows now, icon
    // plate first, with the same icon where staff have the row too.
    testWidgets('every row has its icon, as on a coordinator\'s Profile', (
      tester,
    ) async {
      await pump(tester, ProfileScreen(api: api()));
      for (final (title, icon) in [
        ('Barangay alerts', AppIcons.notificationsActive),
        ('Theme', AppIcons.visibility),
        ('Language', AppIcons.campaign),
        ('Change password', AppIcons.key),
        ('Send a test alert', AppIcons.send),
        ('Your reports', AppIcons.assignment),
        ('Notifications', AppIcons.notifications),
        ('Help center', AppIcons.help),
        ('About RepLiT', AppIcons.info),
        ('Check for updates', AppIcons.download),
      ]) {
        final row = find.widgetWithText(ListRow, title);
        await tester.scrollUntilVisible(
          row,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(row, findsOneWidget, reason: title);
        expect(
          find.descendant(of: row, matching: find.byIcon(icon)),
          findsOneWidget,
          reason: title,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Language switches the whole screen to Tagalog and back', (
      tester,
    ) async {
      addTearDown(LanguageChoice.reset);
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Under LanguageScope, as main.dart mounts the app.
      await tester.pumpWidget(
        LanguageScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ProfileScreen(api: api()),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final tagalog = find.text('Tagalog');
      await tester.scrollUntilVisible(
        tagalog,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Language'), findsOneWidget);

      await tester.tap(tagalog);
      await tester.pump();
      expect(LanguageChoice.current.value, AppLanguage.tl);
      // The same screen, repainted where it stands.
      expect(find.text('Wika'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('English'));
      await tester.pump();
      expect(find.text('Language'), findsOneWidget);
    });

    // 12 Nov 2026: "remove the build number. it is just the version of app
    // will be remain seen in any platforms, no build number".
    testWidgets('shows the version alone, with no build number', (
      tester,
    ) async {
      // What CI stamps on a release: pubspec's name, the run number as build.
      PackageInfo.setMockInitialValues(
        appName: 'RepLiT',
        packageName: 'com.example.replit',
        version: '1.11.0',
        buildNumber: '57',
        buildSignature: '',
      );
      await AppVersion.load();
      addTearDown(() => AppVersion.label = '');
      expect(AppVersion.label, '1.11.0');

      await pump(tester, ProfileScreen(api: api()));
      final footer = find.text('REPLIT · PASAY CITY · V1.11.0');
      await tester.scrollUntilVisible(
        footer,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(footer, findsOneWidget);
    });

    testWidgets('an ID in review is not asked for again', (tester) async {
      await pump(tester, ProfileScreen(api: api(idStatus: 'manual_review')));
      expect(find.text('Add your National ID for +50%'), findsNothing);
      expect(find.text('Your National ID is being checked'), findsOneWidget);
    });
  });

  group('verification', () {
    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('each channel says where it stands, at ${scale}x', (
        tester,
      ) async {
        await pump(
          tester,
          VerificationScreen(api: api(idStatus: 'manual_review')),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('VERIFY YOUR ACCOUNT'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);
        expect(find.text('LIGHT GREEN'), findsOneWidget);
        expect(
          find.text('+40% · Coming soon'),
          findsOneWidget,
          reason: 'phone verification is paused (§10.3)',
        );
        expect(
          find.text('+50% · Submitted — an administrator is checking it'),
          findsOneWidget,
        );
        // Below the fold at a large font scale.
        await tester.scrollUntilVisible(
          find.text('UNDER 50'),
          200,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        // 15 · Verification: a verified address, masked.
        expect(find.text('+10% · m•••@gmail.com'), findsOneWidget);
        expect(find.text('UNDER 50'), findsOneWidget);
      });
    }

    testWidgets('a refused ID can be taken again', (tester) async {
      await pump(tester, VerificationScreen(api: api(idStatus: 'rejected')));
      expect(
        find.text('+50% · Not accepted — take the photos again'),
        findsOneWidget,
      );
    });

    test('the paused phone channel is never the next step', () {
      final s = VerificationState.fromJson({
        'verified_percent': 60,
        'badge': 'light_green',
        'channels': [
          {'type': 'national_id', 'status': 'verified'},
          {'type': 'email', 'status': 'verified'},
        ],
      });
      expect(PhoneNumbers.open, isFalse);
      expect(s.nextStep, isNull);
    });
  });
}
