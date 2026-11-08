import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/push_service.dart';
import 'package:replit/theme.dart';
import 'package:replit/updates/app_updates.dart';
import 'package:replit/updates/update_banner.dart';
import 'package:replit/updates/update_nudge.dart';

/// "There's a new update!" (WHAT'S NEXT, 1.1) on the home screens. The app
/// looks every time it opens, and on coming back to the front at most every
/// 15 minutes; the banner stays until UPDATE or ×.
///
/// 8 November, "why there's no banner in the home screen?": it looked at
/// most every six hours, counting a look that found nothing, and showed a
/// pop-up for ten seconds, so a release out an hour after a look went unseen
/// for hours. And an iPhone never looked.
void main() {
  late int looks;
  late UpdateCheck answer;
  var clock = DateTime(2026, 11, 8, 9);

  AvailableRelease release(int build) => AvailableRelease(
    version: '1.12.${build - 22}',
    build: build,
    tag: 'android-v1.12.${build - 22}-$build',
    apk: 'RepLiT-1.12.${build - 22}-$build.apk',
    size: 24 * 1024 * 1024,
    sha256: 'ab' * 32,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UpdateNudge.reset();
    clock = DateTime(2026, 11, 8, 9);
    UpdateNudge.now = () => clock;
    looks = 0;
    answer = UpdateAvailable(release(53));
    AppUpdates.supportedOverride = true;
    AppUpdates.checkOverride = () async {
      looks++;
      return answer;
    };
  });

  tearDown(() {
    UpdateNudge.reset();
    AppUpdates.supportedOverride = null;
    AppUpdates.checkOverride = null;
  });

  /// A home screen with the banner at its top.
  Future<void> home(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        navigatorKey: PushService.navigatorKey,
        home: const Scaffold(
          body: SafeArea(
            child: Column(children: [UpdateBanner(), Text('Home')]),
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> look(WidgetTester tester, Future<void> Function() how) async {
    await how();
    await settle(tester);
  }

  final banner = find.text("There's a new update!");

  test('versions compare number by number', () {
    expect(isNewerVersion('1.12.31', than: '1.12.30'), isTrue);
    expect(isNewerVersion('1.12.30', than: '1.12.31'), isFalse);
    expect(isNewerVersion('1.12.31', than: '1.12.31'), isFalse);
    expect(isNewerVersion('1.13.0', than: '1.12.99'), isTrue);
    expect(isNewerVersion('1.12.100', than: '1.12.99'), isTrue);
    expect(isNewerVersion('2.0', than: '1.99.99'), isTrue);
    expect(isNewerVersion('1.12.31+60', than: '1.12.31'), isFalse);
    expect(isNewerVersion('1.12.31', than: ''), isFalse);
    expect(isNewerVersion('soon', than: '1.12.30'), isFalse);
  });

  testWidgets('a newer release: the banner, with UPDATE, and it stays', (
    tester,
  ) async {
    await home(tester);
    await look(tester, UpdateNudge.start);
    expect(banner, findsOneWidget);
    expect(find.text('RepLiT 1.12.31 is ready to install.'), findsOneWidget);
    expect(find.text('UPDATE'), findsOneWidget);
    expect(
      tester.getTopLeft(banner).dy,
      lessThan(tester.getTopLeft(find.text('Home')).dy),
    );
    await tester.pump(const Duration(minutes: 5));
    expect(banner, findsOneWidget, reason: 'no pop-up that times out');
  });

  testWidgets('UPDATE opens Check for updates', (tester) async {
    await home(tester);
    await look(tester, UpdateNudge.start);
    await tester.tap(find.text('UPDATE'));
    await settle(tester);
    expect(find.byType(UpdateSheet), findsOneWidget);
  });

  testWidgets('up to date: nothing above the home screen', (tester) async {
    answer = const UpToDate();
    await home(tester);
    await look(tester, UpdateNudge.start);
    expect(banner, findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('it looks every time the app opens, and on coming back at '
      'most every 15 minutes', (tester) async {
    answer = const UpToDate();
    await home(tester);
    await look(tester, UpdateNudge.start);
    await look(tester, UpdateNudge.start);
    expect(looks, 2);
    clock = clock.add(const Duration(minutes: 14));
    await look(tester, UpdateNudge.maybeCheck);
    expect(looks, 2);
    clock = clock.add(const Duration(minutes: 1));
    await look(tester, UpdateNudge.maybeCheck);
    expect(looks, 3);
  });

  testWidgets('a release out after a look that found nothing shows 15 '
      'minutes on, not six hours', (tester) async {
    answer = const UpToDate();
    await home(tester);
    await look(tester, UpdateNudge.start);
    expect(banner, findsNothing);
    answer = UpdateAvailable(release(53));
    clock = clock.add(UpdateNudge.every);
    await look(tester, UpdateNudge.maybeCheck);
    expect(banner, findsOneWidget);
  });

  testWidgets('no answer: the banner stays, and the next look tries again', (
    tester,
  ) async {
    await home(tester);
    await look(tester, UpdateNudge.start);
    answer = const UpdateCheckFailed('NETWORK_FAILURE');
    clock = clock.add(UpdateNudge.every);
    await look(tester, UpdateNudge.maybeCheck);
    await look(tester, UpdateNudge.maybeCheck);
    expect(looks, 3);
    expect(banner, findsOneWidget);
  });

  testWidgets('installed: the next look finds nothing, and it goes', (
    tester,
  ) async {
    await home(tester);
    await look(tester, UpdateNudge.start);
    answer = const UpToDate();
    await look(tester, UpdateNudge.start);
    expect(banner, findsNothing);
  });

  testWidgets('× keeps it away until a newer release', (tester) async {
    await home(tester);
    await look(tester, UpdateNudge.start);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(banner, findsNothing);

    await look(tester, UpdateNudge.start);
    expect(looks, 2);
    expect(banner, findsNothing);

    answer = UpdateAvailable(release(54));
    await look(tester, UpdateNudge.start);
    expect(find.text('RepLiT 1.12.32 is ready to install.'), findsOneWidget);
  });

  testWidgets(
    'an iPhone is told to install it with Sideloadly, and has only ×',
    (tester) async {
      AppUpdates.supportedOverride = false;
      await home(tester);
      await look(tester, UpdateNudge.start);
      expect(
        find.text(
          'RepLiT 1.12.31 is out. Install it with Sideloadly, as before.',
        ),
        findsOneWidget,
      );
      expect(find.text('UPDATE'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await look(tester, UpdateNudge.start);
      expect(banner, findsNothing, reason: 'closed for 1.12.31');

      answer = UpdateAvailable(release(54));
      await look(tester, UpdateNudge.start);
      expect(find.textContaining('RepLiT 1.12.32 is out.'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('what is not a phone never looks', (tester) async {
    AppUpdates.supportedOverride = false;
    await home(tester);
    await look(tester, UpdateNudge.start);
    expect(looks, 0);
    expect(banner, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
