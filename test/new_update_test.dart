import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/alerts/inbox_watcher.dart';
import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/sound/sound_cues.dart';
import 'package:replit/theme.dart';
import 'package:replit/updates/app_updates.dart';

/// 12 November 2026: "create an "New Update!" notification, the sound to be
/// follow. still vibrates" (answered: a push when a release comes out, the
/// phone's own tone for now). Backend v1.12.29 sends it, type `app_update`;
/// tapping it opens Check for updates.
void main() {
  tearDown(() => AppUpdates.checkOverride = null);

  test('"New Update!" leads to Check for updates, for anyone', () {
    expect(targetFor('app_update', null), NotificationTarget.appUpdate);
    expect(
      targetFor('app_update', {'role': 'citizen'}),
      NotificationTarget.appUpdate,
    );
    expect(
      targetFor('app_update', {'role': 'sub_admin'}),
      NotificationTarget.appUpdate,
    );
    expect(canOpen('app_update', const {}), isTrue);
  });

  testWidgets('tapping it opens the update sheet, signed in or not', (
    tester,
  ) async {
    AppUpdates.checkOverride = () async => const UpToDate();
    var asked = 0;
    // No account is needed: the router does not ask who is signed in.
    final api = ApiClient(
      client: MockClient((request) async {
        asked++;
        return http.Response('{}', 401);
      }),
    );
    final key = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        theme: buildAppTheme(),
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final opened = await NotificationRouter(api: api).open(
      key.currentState!,
      type: 'app_update',
      data: const {'type': 'app_update', 'version': '1.12.37'},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(opened, isTrue);
    expect(asked, 0);
    expect(find.text('CHECK FOR UPDATES'), findsOneWidget);
    expect(find.text('You have the latest version.'), findsOneWidget);
  });

  test('the open app only vibrates for it: no recording of its own yet', () {
    final item = {'type': 'app_update', 'data': <String, dynamic>{}};
    final sound = InboxWatcher.soundFor(item);
    expect(SoundCues.categories.contains(sound), isFalse);
  });

  test('Android has its channel: the phone\'s tone, vibrating', () {
    final activity = File(
      'android/app/src/main/kotlin/com/m2stz/replit/MainActivity.kt',
    ).readAsStringSync();
    // The id backend v1.12.29 names (app/integrations/fcm.py).
    expect(activity, contains('"app_updates_v1"'));
    final channel = activity.substring(activity.indexOf('"app_updates_v1"'));
    final body = channel.substring(0, channel.indexOf('}'));
    expect(body, contains('enableVibration(true)'));
    expect(body, isNot(contains('setSound(')), reason: "the phone's own tone");
    expect(activity, contains('appUpdates\n'));
  });
}
