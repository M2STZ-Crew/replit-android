import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/api/web_only.dart';
import 'package:replit/location/location_beacon.dart';
import 'package:replit/screens/email_gate_screen.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/role_gate.dart';
import 'package:replit/store_build.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/email_link_sheet.dart';

import 'real_font.dart';

/// v1.12.65: Google Play's copy is for residents (answered "go with the
/// safest", 27 Nov 2026).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => StoreBuild.playOverride = null);

  /// A token whose subject is [sub], as Supabase signs them (unsigned here).
  String jwt(String sub) {
    String part(Map<String, Object> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'none'})}.${part({'sub': sub})}.signature';
  }

  group('who each copy opens', () {
    test('Play: residents only', () {
      StoreBuild.playOverride = true;
      expect(WebOnly.account({'role': 'general_user'}), isFalse);
      for (final role in ['sub_admin', 'response_team', 'admin']) {
        expect(WebOnly.account({'role': role}), isTrue, reason: role);
      }
      expect(WebOnly.account(null), isFalse);
    });

    test('the APK page: everyone but an Admin, as before', () {
      StoreBuild.playOverride = false;
      for (final role in ['general_user', 'sub_admin', 'response_team']) {
        expect(WebOnly.account({'role': role}), isFalse, reason: role);
      }
      expect(WebOnly.account({'role': 'admin'}), isTrue);
    });

    test('each is told where they work, with no link to install', () {
      StoreBuild.playOverride = true;
      final staff = WebOnly.messageFor({'role': 'sub_admin'});
      expect(staff, WebOnly.playStaffMessage);
      expect(staff, contains('welcome email'));
      expect(staff, isNot(contains('http')));
      expect(staff, isNot(contains('.vercel.app')));
      expect(
        WebOnly.messageFor({'role': 'admin'}),
        contains('reportwhatslit.vercel.app'),
      );
    });
  });

  group('the location foreground service', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('the manifest names it through the Play switch', () {
      expect(
        manifest,
        contains(r'android:name="${foregroundLocationPermission}"'),
      );
      expect(
        manifest,
        isNot(contains('"android.permission.FOREGROUND_SERVICE_LOCATION"')),
      );
    });

    test('only the APK page\'s copy asks for it', () {
      final at = gradle.indexOf(
        'manifestPlaceholders["foregroundLocationPermission"]',
      );
      expect(at, greaterThan(0));
      final block = gradle.substring(at, at + 400);
      expect(block, contains('if (playStore)'));
      expect(
        block.indexOf('NO_FOREGROUND_LOCATION_ON_PLAY'),
        lessThan(
          block.indexOf('android.permission.FOREGROUND_SERVICE_LOCATION'),
        ),
      );
    });
  });

  _emailGateCentred();

  group('signing in to Play\'s copy', () {
    setUp(() => LocationBeacon.schedulerOverride = const _Scheduler());
    tearDown(() => LocationBeacon.schedulerOverride = null);

    testWidgets('a coordinator is refused, and nothing is kept', (
      tester,
    ) async {
      StoreBuild.playOverride = true;
      final seen = <String>[];
      final api = ApiClient(
        client: MockClient((req) async {
          seen.add('${req.method} ${req.url.path}');
          final path = req.url.path;
          if (path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'access_token': jwt('u-coord'),
                'refresh_token': 'r',
                'email': 'fv.coordinator@replit.com',
              }),
              200,
            );
          }
          if (path.endsWith('/auth/me')) {
            return http.Response(
              jsonEncode({
                'id': 'u-coord',
                'role': 'sub_admin',
                'agency_type': 'fire_volunteer',
                'language': 'en',
              }),
              200,
            );
          }
          if (path.endsWith('/auth/logout')) return http.Response('', 204);
          return http.Response('{}', 200);
        }),
      );
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LoginScreen(api: api),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.enterText(
        find.byType(TextField).at(0),
        'fv.coordinator@replit.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'a-password');
      await tester.ensureVisible(find.text('SIGN IN'));
      await tester.tap(find.text('SIGN IN'));
      for (
        var waited = Duration.zero;
        waited < WebOnly.cleanupFor * 3 &&
            find.text(WebOnly.playStaffMessage).evaluate().isEmpty;
        waited += const Duration(milliseconds: 250)
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(find.text(WebOnly.playStaffMessage), findsOneWidget);
      expect(find.byType(RoleGate), findsNothing);
      expect(Session.instance.isAuthenticated, isFalse);
      expect(seen, contains('POST /auth/logout'));
    });
  });
}

/// "Confirm your email" as a full screen (27 Nov 2026: "it is not centered").
void _emailGateCentred() {
  testWidgets('Confirm your email sits in the middle, centred', (tester) async {
    await loadAppFont();
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
      client: MockClient((req) async => http.Response('{}', 200)),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: EmailGateScreen(email: 'play@x.ph', api: api),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    const mid = 402 / 2;
    final title = tester.getRect(find.text('CONFIRM YOUR EMAIL'));
    final badge = tester.getRect(find.text('+10%'));
    final startOver = tester.getRect(
      find.byKey(const ValueKey('email-start-over')),
    );
    final button = tester.getRect(find.text('SEND THE LINK'));
    // Across: the title with its +10%, the button's label and "Wrong
    // email? Start over" all down the middle, like Log out below them.
    expect(((title.left + badge.right) / 2 - mid).abs(), lessThan(1.5));
    expect((button.center.dx - mid).abs(), lessThan(1.5));
    expect((startOver.center.dx - mid).abs(), lessThan(1.5));

    // Down: as much room above the block as below it, in the space above
    // the hotline (the page's own padding is 10 above and 20 below).
    final area = tester.getRect(find.byType(EmailLinkSheet));
    final above = title.top - (area.top + 10);
    final below = (area.bottom - 20) - startOver.bottom;
    expect(above, greaterThan(100));
    expect((above - below).abs(), lessThan(3));
  });
}

/// Stands in for WorkManager.
class _Scheduler extends BeaconScheduler {
  const _Scheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(String name, Duration every) async {}

  @override
  Future<void> cancel(String name) async {}
}
