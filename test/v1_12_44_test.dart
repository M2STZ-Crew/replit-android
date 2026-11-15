import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/models/person_rules.dart';
import 'package:replit/screens/delete_account_screen.dart';
import 'package:replit/screens/my_reports_screen.dart';
import 'package:replit/security/developer_mode.dart';
import 'package:replit/store_build.dart';
import 'package:replit/theme.dart';

/// v1.12.44: what the QA run on the Realme C75 (15–16 Nov 2026) found, and
/// what Google Play asks of an app.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('names and email addresses (QA Z-10, D-02)', () {
    test('names people have pass', () {
      for (final name in [
        'Juan Dela Cruz',
        'Ma. Luisa',
        'Juan Dela Cruz Jr.',
        "O'Neil",
        'D’Angelo',
        'Anne-Marie',
        'Niño Peña',
        'José',
      ]) {
        expect(looksLikeName(name), isTrue, reason: name);
      }
    });

    test('digits, emoji and symbols do not', () {
      for (final name in [
        'Juan 😀',
        '😀',
        'Juan123',
        'Juan_Cruz',
        '-Juan',
        'J/C',
      ]) {
        expect(looksLikeName(name), isFalse, reason: name);
      }
    });

    test('an email address must be whole', () {
      for (final email in ['juan@gmail.com', 'ma.luisa+rep@yahoo.com.ph']) {
        expect(looksLikeEmail(email), isTrue, reason: email);
      }
      for (final email in [
        'juan@gmail',
        'juan.gmail.com',
        'juan @gmail.com',
        '@gmail.com',
        'juan@.com',
      ]) {
        expect(looksLikeEmail(email), isFalse, reason: email);
      }
    });
  });

  group('the Google Play copy', () {
    tearDown(() => StoreBuild.playOverride = null);

    test('tells the server it is the Play copy', () {
      StoreBuild.playOverride = false;
      expect(StoreBuild.deviceVersion('1.12.44'), '1.12.44');
      expect(StoreBuild.deviceVersion(''), isNull);
      StoreBuild.playOverride = true;
      expect(StoreBuild.deviceVersion('1.12.44'), '1.12.44 play');
    });

    test('links to the policy pages on the console', () {
      expect(PolicyLinks.privacy.path, '/privacy');
      expect(PolicyLinks.deleteAccount.path, '/delete-account');
    });
  });

  group('how the Play copy is built (PS-01, PS-02, PS-03)', () {
    final workflow = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('the release builds an app bundle for Play, as the Play copy', () {
      expect(workflow, contains('flutter build appbundle --release'));
      expect(workflow, contains('--android-project-arg=playStore=true'));
      expect(workflow, contains('--dart-define=PLAY_STORE=true'));
      expect(workflow, contains('UPLOAD_KEYSTORE_BASE64'));
      // It can never hold back the APK page's release.
      final play = workflow.indexOf("- name: Build Google Play's app bundle");
      expect(
        play,
        greaterThan(workflow.indexOf('- name: Publish on GitHub Releases')),
      );
      expect(
        workflow.substring(play, play + 200),
        contains('continue-on-error: true'),
      );
    });

    test(
      'Play is signed with the upload key, and does not ask to install apps',
      () {
        expect(gradle, contains('signingConfigs.findByName("upload")'));
        expect(
          gradle,
          contains('"android.permission.REQUEST_INSTALL_PACKAGES"'),
        );
        expect(manifest, contains(r'android:name="${installPermission}"'));
        expect(
          manifest,
          isNot(contains('android.permission.REQUEST_INSTALL_PACKAGES')),
        );
      },
    );
  });

  group('Developer options in the Play copy (PS-06)', () {
    var reports = 0;

    setUp(() {
      reports = 0;
      DeveloperMode.enforcedOverride = true;
      DeveloperMode.probeOverride = () async => DeviceRisk.developerOptions;
    });

    tearDown(() {
      DeveloperMode.enforcedOverride = null;
      DeveloperMode.probeOverride = null;
      StoreBuild.playOverride = null;
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => DeveloperModeGate(child: child!),
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => reports++,
                child: const Text('Report a fire'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the APK copy still only offers Exit', (tester) async {
      StoreBuild.playOverride = false;
      await pump(tester);
      expect(
        find.byKey(const ValueKey('developer-mode-warning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('developer-mode-continue')),
        findsNothing,
      );
    });

    testWidgets('the Play copy warns, then lets them in', (tester) async {
      StoreBuild.playOverride = true;
      await pump(tester);
      expect(
        find.byKey(const ValueKey('developer-mode-warning')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('developer-mode-continue')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('developer-mode-warning')),
        findsNothing,
      );
      await tester.tap(find.text('Report a fire'));
      expect(reports, 1);
    });
  });

  testWidgets('Your reports shows the report photo (QA H-16)', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/reports/mine')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'r1',
                'device_lat': 14.5378,
                'device_lng': 121.0014,
                'selected_agencies': ['fire_volunteer'],
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'area_status': 'reported',
                'area_designation': 'Area 1',
                'photo_url':
                    'https://storage.example/incident-photos/r1.jpg?token=x',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MyReportsScreen(api: api),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('report-photo')), findsOneWidget);
  });

  group('Delete my account', () {
    ApiClient api(http.Response Function() answer, List<String> asked) =>
        ApiClient(
          client: MockClient((req) async {
            asked.add('${req.method} ${req.url.path} ${req.body}');
            return answer();
          }),
        );

    Future<void> pump(WidgetTester tester, ApiClient client) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: DeleteAccountScreen(api: client),
        ),
      );
      await tester.pump();
    }

    Finder error() => find.byKey(const ValueKey('delete-account-error'));

    Future<void> tapDelete(WidgetTester tester) async {
      final button = find.byKey(const ValueKey('delete-account-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
    }

    testWidgets('asks for the password, then for the tick', (tester) async {
      final asked = <String>[];
      await pump(tester, api(() => http.Response('', 204), asked));
      await tapDelete(tester);
      await tester.pump();
      expect(tester.widget<Text>(error()).data, 'Enter your password.');
      await tester.enterText(find.byType(TextField), 'secret-1');
      await tapDelete(tester);
      await tester.pump();
      expect(
        tester.widget<Text>(error()).data,
        'Tick the box to confirm. Deleting an account cannot be undone.',
      );
      expect(asked, isEmpty);
    });

    testWidgets('a wrong password is said plainly, and nothing is deleted', (
      tester,
    ) async {
      final asked = <String>[];
      await pump(
        tester,
        api(
          () => http.Response(
            jsonEncode({
              'error': 'wrong_password',
              'message': 'The password is not right.',
            }),
            400,
          ),
          asked,
        ),
      );
      await tester.enterText(find.byType(TextField), 'guess');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tapDelete(tester);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(error()).data, 'The password is not right.');
      expect(asked, hasLength(1));
      expect(asked.single, startsWith('POST /auth/me/delete'));
      expect(asked.single, contains('"password":"guess"'));
    });
  });
}
