import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/alerts/inbox_watcher.dart';
import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/i18n/i18n.dart';
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

  test('the open app plays its own recording, in the app\'s language', () {
    final item = {'type': 'app_update', 'data': <String, dynamic>{}};
    expect(InboxWatcher.soundFor(item), SoundCues.update);
    expect(SoundCues.updateSounds[AppLanguage.en], 'update_en');
    expect(SoundCues.updateSounds[AppLanguage.tl], 'update_tl');
  });

  test('Android has a channel for each language, with its recording', () {
    final activity = File(
      'android/app/src/main/kotlin/com/m2stz/replit/MainActivity.kt',
    ).readAsStringSync();
    // The ids backend v1.12.30 names (app/integrations/fcm.py), made by
    // the one helper every sound channel uses since v1.12.42.
    expect(
      activity,
      contains(
        'channel("app_update_en_v1", "App updates (English)", update, '
        'R.raw.update_en)',
      ),
    );
    expect(
      activity,
      contains(
        'channel("app_update_tl_v1", "App updates (Tagalog)", update, '
        'R.raw.update_tl)',
      ),
    );
    final channel = activity.substring(activity.indexOf('fun channel('));
    final body = channel.substring(0, channel.indexOf('}'));
    expect(body, contains('setSound(sound(raw), attributes)'));
    expect(body, contains('enableVibration(true)'));
    final keep = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();
    expect(keep, contains('@raw/update_en'));
    expect(keep, contains('@raw/update_tl'));
  });

  test('the phone\'s-tone update channel is retired (v1.12.42)', () {
    // app_updates_v1 played the phone's own tone, for an app before v1.12.38;
    // this app is told on its language's channel, and nothing plays the
    // phone's tone ("No phone tone anywhere"), so it is deleted, not made.
    final activity = File(
      'android/app/src/main/kotlin/com/m2stz/replit/MainActivity.kt',
    ).readAsStringSync();
    final retired = activity.substring(
      activity.indexOf('val RETIRED_CHANNELS'),
    );
    expect(retired, contains('"app_updates_v1"'));
    final made = activity.substring(
      activity.indexOf('manager.createNotificationChannels('),
      activity.indexOf('companion object'),
    );
    expect(made, isNot(contains('"app_updates_v1"')));
  });
}
