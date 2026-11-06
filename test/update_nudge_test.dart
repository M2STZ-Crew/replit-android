import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/push_service.dart';
import 'package:replit/updates/app_updates.dart';
import 'package:replit/updates/update_nudge.dart';

/// "There's a new update!" (WHAT'S NEXT, 1.1): Android looks by itself, at
/// most every six hours, and says so in a banner like an alert's. UPDATE opens
/// Check for updates; closing it keeps it away until a newer release.
void main() {
  late int looks;
  late UpdateCheck answer;
  var clock = DateTime(2026, 11, 6, 9);

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
    clock = DateTime(2026, 11, 6, 9);
    UpdateNudge.now = () => clock;
    looks = 0;
    answer = UpdateAvailable(release(50));
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

  Future<void> app(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: PushService.messengerKey,
        navigatorKey: PushService.navigatorKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
  }

  Future<void> look(WidgetTester tester) async {
    await UpdateNudge.maybeCheck();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a newer release: the banner, with UPDATE', (tester) async {
    await app(tester);
    await look(tester);
    expect(find.text("There's a new update!"), findsOneWidget);
    expect(find.text('RepLiT 1.12.28 is ready to install.'), findsOneWidget);
    expect(find.text('UPDATE'), findsOneWidget);
    await tester.pump(UpdateNudge.showFor);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('UPDATE opens Check for updates', (tester) async {
    await app(tester);
    await look(tester);
    await tester.tap(find.text('UPDATE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(UpdateSheet), findsOneWidget);
  });

  testWidgets('up to date: no banner', (tester) async {
    answer = const UpToDate();
    await app(tester);
    await look(tester);
    expect(find.text("There's a new update!"), findsNothing);
  });

  testWidgets('at most one look every six hours', (tester) async {
    answer = const UpToDate();
    await app(tester);
    await look(tester);
    clock = clock.add(const Duration(hours: 5, minutes: 59));
    await look(tester);
    expect(looks, 1);
    clock = clock.add(const Duration(minutes: 1));
    await look(tester);
    expect(looks, 2);
  });

  testWidgets('a look that got no answer is tried again next time', (
    tester,
  ) async {
    answer = const UpdateCheckFailed('NETWORK_FAILURE');
    await app(tester);
    await look(tester);
    await look(tester);
    expect(looks, 2);
  });

  testWidgets('closed by hand: not again until a newer release', (
    tester,
  ) async {
    await app(tester);
    await look(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("There's a new update!"), findsNothing);

    clock = clock.add(UpdateNudge.every);
    await look(tester);
    expect(looks, 2);
    expect(find.text("There's a new update!"), findsNothing);

    answer = UpdateAvailable(release(51));
    clock = clock.add(UpdateNudge.every);
    await look(tester);
    expect(find.text('RepLiT 1.12.29 is ready to install.'), findsOneWidget);
    await tester.pump(UpdateNudge.showFor);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('left to time out, it comes back at the next look', (
    tester,
  ) async {
    await app(tester);
    await look(tester);
    await tester.pump(UpdateNudge.showFor);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("There's a new update!"), findsNothing);
    clock = clock.add(UpdateNudge.every);
    await look(tester);
    expect(find.text("There's a new update!"), findsOneWidget);
    await tester.pump(UpdateNudge.showFor);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('not while the splash is up, and never on an iPhone', (
    tester,
  ) async {
    await app(tester);
    UpdateNudge.hold = true;
    await look(tester);
    expect(looks, 0);
    UpdateNudge.hold = false;
    AppUpdates.supportedOverride = false;
    await look(tester);
    expect(looks, 0);
  });
}
