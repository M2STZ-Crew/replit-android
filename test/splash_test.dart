import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/phone_verify_screen.dart';
import 'package:replit/screens/role_gate.dart';
import 'package:replit/screens/splash_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';
import 'package:replit/widgets/launch_mark.dart';
import 'package:replit/widgets/loading.dart';

/// "01 Splash" in two states (WHAT'S NEXT, 2.1). The trigger: the
/// flame-and-pin mark alone, where and as big as the phone's own launch screen
/// drew it, so the hand-off doesn't show. Then loading: the same, with the
/// loader and "Connecting to RepLiT" at the foot, as the reference has them.
/// No wordmark, glow or footer. Signed in, the splash stays until home is
/// ready, so opening the app shows no skeleton.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.instance.clear();
  });

  Finder mark() => find.byWidgetPredicate(
    (w) => w is Image && (w.image as AssetImage).assetName == Art.logoMark,
  );

  Future<void> open(
    WidgetTester tester,
    Size size, {
    AppPalette pal = AppPalette.dark,
    ApiClient? api,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(pal),
        home: SplashScreen(api: api),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  // Let the hand-off to the next screen run, so no timer outlives the test.
  Future<void> handOff(WidgetTester tester) async {
    await tester.pump(SplashScreen.shownAtLeast);
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (ground, pal) in [
    ('dark', AppPalette.dark),
    ('light', AppPalette.light),
  ]) {
    for (final size in const [Size(402, 874), Size(320, 640), Size(430, 932)]) {
      testWidgets('on the $ground ground at $size, the mark alone, then the '
          'loader at the foot', (tester) async {
        await open(tester, size, pal: pal);

        // The trigger: the mark in the middle of the screen, nothing else.
        expect(mark(), findsOneWidget);
        expect(find.byType(Image), findsOneWidget, reason: 'no wordmark');
        expect(find.byType(Text), findsNothing);
        final at = tester.getCenter(mark());
        expect(at.dx, moreOrLessEquals(size.width / 2, epsilon: 0.5));
        expect(at.dy, moreOrLessEquals(size.height / 2, epsilon: 0.5));

        // Loading: the loader and the status line come in near the foot,
        // 58 above it, as on the reference's 874-high phone.
        await tester.pump(SplashScreen.triggerFor);
        await tester.pump(const Duration(milliseconds: 300));
        final status = find.text('Connecting to RepLiT');
        expect(status, findsOneWidget);
        expect(
          tester.getCenter(status).dx,
          moreOrLessEquals(size.width / 2, epsilon: 1),
        );
        expect(
          tester.getBottomLeft(status).dy,
          moreOrLessEquals(size.height - 58, epsilon: 1),
        );
        expect(find.text('Pasay City'), findsNothing, reason: 'no footer');
        // The mark stays where it was.
        expect(tester.getCenter(mark()), at);
        expect(tester.takeException(), isNull);

        await handOff(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    }
  }

  testWidgets('the status line keeps clear of a navigation bar', (
    tester,
  ) async {
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    await open(tester, const Size(412, 915));
    await tester.pump(SplashScreen.triggerFor);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getBottomLeft(find.text('Connecting to RepLiT')).dy,
      moreOrLessEquals(915 - 72, epsilon: 1),
    );
    await handOff(tester);
  });

  group('the mark is the size the launch screen drew it at', () {
    // 80 wide on the design's 402-wide phone, following the screen within
    // 64 and 100, in the image's own 410:576.
    for (final (side, width) in const [
      (402.0, 80.0),
      (320.0, 64.0),
      (375.0, 74.63),
      (440.0, 87.56),
      (834.0, 100.0),
    ]) {
      testWidgets(
        'on an iPhone ${side.toInt()} wide, ${width}pt like the storyboard',
        (tester) async {
          await open(tester, Size(side, side * 2.17));
          final drawn = tester.getSize(mark());
          expect(drawn.width, moreOrLessEquals(width, epsilon: 0.01));
          expect(
            drawn.height,
            moreOrLessEquals(width * 576 / 410, epsilon: 0.01),
          );
          await handOff(tester);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }

    // Android's launch screens come in 20 dp steps of screen width.
    for (final (side, width) in const [
      (411.43, 79.6), // Pixel 6: the 400 dp step
      (393.0, 75.62), // Pixel 8: 380
      (360.0, 71.64),
      (320.0, 64.0),
      (834.0, 99.5), // a tablet: the last step, 500
    ]) {
      testWidgets('on an Android phone $side wide, ${width}dp like '
          'res/values-sw*dp', (tester) async {
        await open(tester, Size(side, side * 2.17));
        final drawn = tester.getSize(mark());
        expect(drawn.width, moreOrLessEquals(width, epsilon: 0.01));
        expect(
          drawn.height,
          moreOrLessEquals(width * 576 / 410, epsilon: 0.01),
        );
        await handOff(tester);
      });
    }

    test('every Android step draws the size the app does', () {
      // Android 12+ scales a splash icon without a background to a 288 dp
      // box (developer.android.com, "Splash screens"), so there the size is
      // set by the clear space around the mark.
      const box = 288.0;
      final steps = <double>[];
      for (final dir in Directory(
        'android/app/src/main/res',
      ).listSync().whereType<Directory>()) {
        final name = dir.path
            .split(Platform.pathSeparator)
            .last
            .split('/')
            .last;
        final step = RegExp(r'^values(?:-sw(\d+)dp)?$').firstMatch(name);
        final file = File('${dir.path}/dimens.xml');
        if (step == null || !file.existsSync()) continue;
        final xml = file.readAsStringSync();
        double value(String kind, String key, String unit) => double.parse(
          RegExp(
            '<$kind name="$key">([0-9.]+)$unit</$kind>',
          ).firstMatch(xml)!.group(1)!,
        );
        final side = double.parse(step.group(1) ?? '320');
        steps.add(side);
        final size = LaunchMark.sizeFor(side, platform: TargetPlatform.android);
        expect(
          value('dimen', 'launch_mark_width', 'dp'),
          moreOrLessEquals(size.width, epsilon: 0.01),
          reason: name,
        );
        expect(
          value('dimen', 'launch_mark_height', 'dp'),
          moreOrLessEquals(size.height, epsilon: 0.01),
          reason: name,
        );
        final x = value('fraction', 'launch_mark_inset_x', '%') / 100;
        final y = value('fraction', 'launch_mark_inset_y', '%') / 100;
        expect(box * (1 - 2 * x), moreOrLessEquals(size.width, epsilon: 0.05));
        expect(box * (1 - 2 * y), moreOrLessEquals(size.height, epsilon: 0.05));
      }
      steps.sort();
      expect(steps, [320, 340, 360, 380, 400, 420, 440, 460, 480, 500]);
      for (final side in steps) {
        expect(LaunchMark.androidStep(side), side);
        expect(LaunchMark.androidStep(side + 19.9), side);
      }
    });
  });

  testWidgets('Android 14 and older: the middle of the display, as the '
      'launch screen had it, not of the app above the navigation bar', (
    tester,
  ) async {
    tester.view.display.size = const Size(412, 915);
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.display.reset);
    await open(tester, const Size(412, 867));
    expect(
      tester.getCenter(mark()).dy,
      moreOrLessEquals(915 / 2, epsilon: 0.5),
    );
    await handOff(tester);
  });

  testWidgets('in split screen, the middle of the window', (tester) async {
    tester.view.display.size = const Size(412, 915);
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.display.reset);
    await open(tester, const Size(412, 450));
    expect(tester.getCenter(mark()).dy, moreOrLessEquals(225, epsilon: 0.5));
    await handOff(tester);
  });

  testWidgets('the mark is decoded before the first frame, so it never '
      'blinks as the launch screen goes', (tester) async {
    imageCache.clear();
    imageCache.clearLiveImages();
    await tester.runAsync(LaunchMark.precache);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const SplashScreen()),
    );
    // The very first frame, before any time passes.
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    await handOff(tester);
  });

  group('signed in', () {
    setUp(
      () => SharedPreferences.setMockInitialValues({
        'access_token': 'token',
        'push_enabled': false,
      }),
    );

    testWidgets('the account loads behind the splash, and home opens with no '
        'skeleton on the way', (tester) async {
      var asked = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (!request.url.path.endsWith('/auth/me')) {
            return http.Response('{}', 404);
          }
          asked++;
          return http.Response(
            jsonEncode({
              'id': 'u1',
              'role': 'general_user',
              'phone_verification_required': true,
            }),
            200,
          );
        }),
      );
      await open(tester, const Size(402, 874), api: api);
      await handOff(tester);

      expect(asked, 1);
      expect(find.byType(SplashScreen), findsNothing);
      expect(
        tester.widget<RoleGate>(find.byType(RoleGate)).initialMe?['id'],
        'u1',
      );
      expect(find.byType(LoadingInline), findsNothing);
      expect(find.byType(PhoneVerifyScreen), findsOneWidget);
    });

    testWidgets('a failed load is answered on the splash: try again, sign in '
        'again, or the hotlines', (tester) async {
      var fail = true;
      final api = ApiClient(
        client: MockClient(
          (request) async => fail
              ? http.Response('{"error":"down"}', 503)
              : http.Response(
                  jsonEncode({
                    'id': 'u1',
                    'role': 'general_user',
                    'phone_verification_required': true,
                  }),
                  200,
                ),
        ),
      );
      await open(tester, const Size(402, 874), api: api);
      await tester.pump(SplashScreen.shownAtLeast);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Could not load your account.'), findsOneWidget);
      expect(find.text('Sign in again'), findsOneWidget);
      expect(find.text('Emergency hotlines'), findsOneWidget);
      expect(find.text('Connecting to RepLiT'), findsNothing);
      final at = tester.getCenter(mark());
      expect(at.dy, moreOrLessEquals(874 / 2, epsilon: 0.5));

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Connecting to RepLiT'), findsOneWidget);
      await handOff(tester);
      expect(find.byType(PhoneVerifyScreen), findsOneWidget);
      expect(find.byType(LoadingInline), findsNothing);
    });

    testWidgets('Sign in again drops the stored session', (tester) async {
      final api = ApiClient(
        client: MockClient((request) async => http.Response('{}', 503)),
      );
      await open(tester, const Size(402, 874), api: api);
      await tester.pump(SplashScreen.shownAtLeast);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sign in again'));
      await handOff(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(Session.instance.isAuthenticated, isFalse);
    });
  });
}
