import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/alerts/inbox_watcher.dart';
import 'package:replit/api/api_cache.dart';
import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/api/web_only.dart';
import 'package:replit/location/location_beacon.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/notifications_screen.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/screens/role_gate.dart';
import 'package:replit/sound/sound_cues.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/staff_shell.dart' show StaffAccount;

/// App v1.12.42 (13 November 2026), with backend v1.12.33.
///
/// - "it is verified but after I've pressing the home and going back to
///   profile it is still fetching ... do caching ... do it to all screens as
///   possible": screens start from the last answers (ApiCache).
/// - "all admin accounts should be logged in web only, not on mobile": an
///   Admin is refused (WebOnly).
/// - "check all of the sounds and apply it to the new. because we found some
///   errors in sound", "add those two new sounds": every sound channel anew,
///   by name, and the National ID's two recordings.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A token whose subject is [sub], as Supabase signs them (unsigned here).
  String jwt(String sub) {
    String part(Map<String, Object> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'none'})}.${part({'sub': sub})}.signature';
  }

  Future<void> frames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // ------------------------------------------------------------------------
  group('the cache of answers', () {
    test('each account its own: another account starts empty', () async {
      final cache = ApiCache.instance;
      await cache.open('a');
      cache.put(ApiCache.me, {'full_name': 'Maria'});
      expect(
        cache.peek<Map<String, dynamic>>(ApiCache.me)?['full_name'],
        'Maria',
      );
      await cache.open('b');
      expect(cache.peek<Object>(ApiCache.me), isNull);
    });

    test('the account\'s own answers wait on the phone for the next start, '
        'and signing out forgets them', () async {
      final cache = ApiCache.instance;
      await cache.open('a');
      cache.put(ApiCache.me, {'full_name': 'Maria'}, onPhone: true);
      cache.put(ApiCache.areas, [1, 2]); // this session's only
      await pumpEventQueue();

      cache.reset(); // the app closes and starts again
      await cache.open('a');
      expect(
        cache.peek<Map<String, dynamic>>(ApiCache.me)?['full_name'],
        'Maria',
      );
      expect(cache.peek<Object>(ApiCache.areas), isNull);

      await cache.clear();
      cache.reset();
      await cache.open('a');
      expect(cache.peek<Object>(ApiCache.me), isNull);
    });

    test(
      'the session opens its account\'s cache, by the token\'s subject',
      () async {
        Session.instance.setTokens(accessToken: jwt('user-1'), email: 'm@x.ph');
        expect(Session.instance.owner, 'user-1');
        await pumpEventQueue();
        expect(ApiCache.instance.owner, 'user-1');
        await Session.instance.clear();
        expect(ApiCache.instance.owner, isNull);
      },
    );

    test(
      'the client keeps each answer the screens use as it arrives',
      () async {
        await ApiCache.instance.open('user-1');
        final api = ApiClient(
          client: MockClient((req) async {
            final path = req.url.path;
            if (path.endsWith('/notifications')) {
              return http.Response('[{"id":"n1"}]', 200);
            }
            if (path.endsWith('/areas')) {
              return http.Response('[{"id":"a1"}]', 200);
            }
            if (path.endsWith('/verification/status')) {
              return http.Response(
                '{"verified_percent":60,"channels":[]}',
                200,
              );
            }
            return http.Response('{"id":"user-1","role":"general_user"}', 200);
          }),
        );
        await api.getMe();
        await api.getVerificationStatus();
        await api.getNotifications();
        await api.getAreas();
        final cache = ApiCache.instance;
        expect(cache.peek<Map<String, dynamic>>(ApiCache.me)?['id'], 'user-1');
        expect(
          cache.peek<Map<String, dynamic>>(
            ApiCache.verification,
          )?['verified_percent'],
          60,
        );
        expect(cache.peek<List<dynamic>>(ApiCache.notifications), hasLength(1));
        expect(cache.peek<List<dynamic>>(ApiCache.areas), hasLength(1));
      },
    );
  });

  // ------------------------------------------------------------------------
  group('Profile opens with the last answers', () {
    // A server that never answers: what shows is the cache alone.
    ApiClient silent() =>
        ApiClient(client: MockClient((_) => Completer<http.Response>().future));

    Future<void> pump(WidgetTester tester, ApiClient api) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ProfileScreen(api: api),
        ),
      );
      await frames(tester);
    }

    const me = {
      'id': 'u1',
      'email': 'sanchezjustine593@gmail.com',
      'full_name': 'Violet Marcella',
      'role': 'general_user',
      'verified_percent': 60,
      'badge': 'light_green',
    };

    testWidgets('verified, by name, at once: not the email and 0%', (
      tester,
    ) async {
      ApiCache.instance.put(ApiCache.me, me);
      ApiCache.instance.put(ApiCache.verification, {
        'verified_percent': 60,
        'badge': 'light_green',
        'channels': [
          {'type': 'email', 'status': 'verified'},
          {'type': 'national_id', 'status': 'verified'},
        ],
      });
      await pump(tester, silent());
      expect(find.text('VIOLET MARCELLA'), findsOneWidget);
      expect(find.text('60% verified'), findsOneWidget);
      // What the screenshot showed while it fetched.
      expect(find.text('SANCHEZJUSTINE593'), findsNothing);
      expect(find.text('0% verified'), findsNothing);
      expect(find.text('Add your National ID for +50%'), findsNothing);
    });

    testWidgets('before the verification answers: its own percentage, and no '
        'next step', (tester) async {
      ApiCache.instance.put(ApiCache.me, {
        ...me,
        'verified_percent': 10,
        'badge': 'yellow',
      });
      await pump(tester, silent());
      expect(find.text('10% verified'), findsOneWidget);
      expect(find.text('0% verified'), findsNothing);
      expect(find.text('Add your National ID for +50%'), findsNothing);
      expect(find.text('Your National ID is being checked'), findsNothing);
    });

    testWidgets('"National ID verified" arriving makes it ask again', (
      tester,
    ) async {
      var asked = 0;
      var verified = false;
      final api = ApiClient(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/verification/status')) {
            asked++;
            return http.Response(
              jsonEncode({
                'verified_percent': verified ? 60 : 10,
                'badge': verified ? 'light_green' : 'yellow',
                'channels': [
                  {'type': 'email', 'status': 'verified'},
                  {
                    'type': 'national_id',
                    'status': verified ? 'verified' : 'manual_review',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode(me), 200);
        }),
      );
      await pump(tester, api);
      expect(asked, 1);
      expect(find.text('10% verified'), findsOneWidget);

      verified = true;
      ApiCache.instance.accountChangedNow(); // PushService, on the push
      await frames(tester);
      expect(asked, 2);
      expect(find.text('60% verified'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------------
  testWidgets('Alerts open with the last list, without a spinner', (
    tester,
  ) async {
    ApiCache.instance.put(ApiCache.notifications, [
      {
        'id': 'n1',
        'type': 'national_id_reviewed',
        'title': 'National ID verified',
        'body': 'Your verification went up.',
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'data': <String, dynamic>{},
      },
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: NotificationsScreen(
          api: ApiClient(
            client: MockClient((_) => Completer<http.Response>().future),
          ),
        ),
      ),
    );
    await frames(tester, 2);
    // Titles are drawn in capitals.
    expect(find.text('NATIONAL ID VERIFIED'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ------------------------------------------------------------------------
  group('admin accounts are web only', () {
    // WorkManager stands aside: on a Linux machine (the release workflow's)
    // its plugin runs systemctl, which never finishes under the test clock,
    // and signing out stops the closed-app reports through it.
    setUp(() => LocationBeacon.schedulerOverride = const _Scheduler());
    tearDown(() => LocationBeacon.schedulerOverride = null);

    testWidgets('signing out goes ahead when nothing answers', (tester) async {
      LocationBeacon.schedulerOverride = const _Scheduler(answers: false);
      Session.instance.setTokens(accessToken: jwt('u-admin'), email: 'a@x.ph');
      var done = false;
      unawaited(
        WebOnly.signOut(
          ApiClient(
            client: MockClient((_) => Completer<http.Response>().future),
          ),
        ).then((_) => done = true),
      );
      // The push registration, then the session: each waits its bound.
      await tester.pump(WebOnly.cleanupFor);
      await tester.pump(WebOnly.cleanupFor);
      await tester.pump();
      expect(done, isTrue);
      expect(Session.instance.isAuthenticated, isFalse);
    });

    test('an Admin, and only an Admin', () {
      expect(WebOnly.account({'role': 'admin'}), isTrue);
      for (final role in ['general_user', 'sub_admin', 'response_team']) {
        expect(WebOnly.account({'role': role}), isFalse, reason: role);
      }
      expect(WebOnly.account(null), isFalse);
      expect(WebOnly.message, contains('reportwhatslit.vercel.app'));
    });

    testWidgets('signing in as an Admin is refused, and nothing is kept', (
      tester,
    ) async {
      final seen = <String>[];
      final api = ApiClient(
        client: MockClient((req) async {
          seen.add('${req.method} ${req.url.path}');
          final path = req.url.path;
          if (path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'access_token': jwt('u-admin'),
                'refresh_token': 'r',
                'email': 'barangay76.admin@replit.com',
              }),
              200,
            );
          }
          if (path.endsWith('/auth/me')) {
            return http.Response(
              jsonEncode({'id': 'u-admin', 'role': 'admin', 'language': 'en'}),
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
      await frames(tester, 2);
      await tester.enterText(
        find.byType(TextField).at(0),
        'barangay76.admin@replit.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'a-password');
      await tester.ensureVisible(find.text('SIGN IN'));
      await tester.tap(find.text('SIGN IN'));
      // Signing out is bounded (WebOnly.cleanupFor a step), so the message
      // comes within that on any machine, however slow a step is.
      for (
        var waited = Duration.zero;
        waited < WebOnly.cleanupFor * 3 &&
            find.text(WebOnly.message).evaluate().isEmpty;
        waited += const Duration(milliseconds: 250)
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(find.text(WebOnly.message), findsOneWidget);
      expect(find.byType(RoleGate), findsNothing);
      expect(Session.instance.isAuthenticated, isFalse);
      expect(seen, contains('POST /auth/logout'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });

    testWidgets('a resident signs in as before', (tester) async {
      final api = ApiClient(
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'access_token': jwt('u-1'),
                'refresh_token': 'r',
                'email': 'm@x.ph',
              }),
              200,
            );
          }
          if (path.endsWith('/auth/me')) {
            return http.Response(
              jsonEncode({
                'id': 'u-1',
                'role': 'general_user',
                'language': 'en',
              }),
              200,
            );
          }
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
      await frames(tester, 2);
      await tester.enterText(find.byType(TextField).at(0), 'm@x.ph');
      await tester.enterText(find.byType(TextField).at(1), 'a-password');
      await tester.ensureVisible(find.text('SIGN IN'));
      await tester.tap(find.text('SIGN IN'));
      await frames(tester, 4);
      expect(find.text(WebOnly.message), findsNothing);
      expect(Session.instance.isAuthenticated, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNotEmpty);
      await Session.instance.clear();
    });
  });

  // ------------------------------------------------------------------------
  group('every sound anew', () {
    const activityPath =
        'android/app/src/main/kotlin/com/m2stz/replit/MainActivity.kt';
    const raw = 'android/app/src/main/res/raw';
    late final activity = File(activityPath).readAsStringSync();
    late final made = activity.substring(
      activity.indexOf('manager.createNotificationChannels('),
      activity.indexOf('companion object'),
    );
    late final retired = activity.substring(
      activity.indexOf('val RETIRED_CHANNELS'),
    );

    /// Each sound channel this app makes, and the file it plays.
    Map<String, String> channels() => {
      for (final m in RegExp(
        r'channel\(\s*"([a-z0-9_]+)"(.*?)R\.raw\.(\w+)',
        dotAll: true,
      ).allMatches(made))
        m.group(1)!: m.group(3)!,
    };

    test('the channels made are the ones the server names, each by the '
        'file it plays', () {
      // backend v1.12.33 SOUND_CHANNELS_V2: each category's channel, playing
      // res/raw/sound_<category>; and "New Update!" by language.
      expect(channels(), {
        'alert_fire_v2': 'sound_fire',
        'alert_police_v2': 'sound_police',
        'alert_medical_v2': 'sound_medical',
        'alert_barangay_v2': 'sound_barangay',
        'citizen_nearby_v1': 'sound_citizen',
        'citizen_verified_v4': 'sound_verified',
        'citizen_on_route_v3': 'sound_on_route',
        'citizen_on_scene_v3': 'sound_on_scene',
        'citizen_fire_out_v3': 'sound_fire_out',
        'citizen_rejected_v3': 'sound_rejected',
        'id_verified_v1': 'sound_id_verified',
        'id_rejected_v1': 'sound_id_rejected',
        'app_update_en_v1': 'update_en',
        'app_update_tl_v1': 'update_tl',
        'general_v1': 'sound_citizen',
      });
      for (final file in channels().values) {
        expect(File('$raw/$file.mp3').existsSync(), isTrue, reason: file);
      }
      // Each names its file, so no renumbering in res/raw can move it.
      expect(activity, contains('raw/\${resources.getResourceEntryName(raw)}'));
      // The one without a sound: vibration only.
      expect(made, contains('silent'));
    });

    test('every channel an older app made is deleted, none of them made '
        'again', () {
      for (final id in [
        'alert_fire',
        'alert_police',
        'alert_medical',
        'alert_barangay',
        'citizen_updates',
        'citizen_updates_v2',
        'citizen_verified_v3',
        'citizen_on_route_v2',
        'citizen_on_scene_v2',
        'citizen_fire_out_v2',
        'citizen_rejected_v2',
        'updates',
        'updates_v2',
        'app_updates_v1',
      ]) {
        expect(retired, contains('"$id"'), reason: id);
        expect(made, isNot(contains('"$id"')), reason: id);
      }
    });

    test('a push for a channel this phone lacks plays the residents\' '
        'recording, never the phone\'s tone', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:value="general_v1"'));
      expect(channels()['general_v1'], 'sound_citizen');
    });

    test('the National ID has two recordings of its own', () {
      expect(SoundCues.categories, containsAll(['id_verified', 'id_rejected']));
      List<int> bytes(String name) =>
          File('assets/sounds/$name.mp3').readAsBytesSync();
      final verified = bytes('sound_id_verified');
      final rejected = bytes('sound_id_rejected');
      expect(listEquals(verified, rejected), isFalse);
      for (final other in SoundCues.categories.difference({
        'id_verified',
        'id_rejected',
      })) {
        expect(
          listEquals(verified, bytes('sound_$other')),
          isFalse,
          reason: other,
        );
        expect(
          listEquals(rejected, bytes('sound_$other')),
          isFalse,
          reason: other,
        );
      }
    });

    test('the open app plays what the push would', () {
      Map<String, dynamic> item(String type, [Map<String, dynamic>? data]) => {
        'id': '1',
        'type': type,
        'data': data ?? <String, dynamic>{},
      };
      StaffAccount.current = null;
      // A fire near a resident: 01 NEARBY INCIDENT, not the staff alarm.
      expect(InboxWatcher.soundFor(item('fire_alert')), 'citizen');
      expect(
        InboxWatcher.soundFor(
          item('national_id_reviewed', {'sound_category': 'id_verified'}),
        ),
        'id_verified',
      );
      expect(
        InboxWatcher.soundFor(
          item('national_id_reviewed', {'sound_category': 'id_rejected'}),
        ),
        'id_rejected',
      );
      expect(InboxWatcher.soundFor(item('test')), 'citizen');
      expect(InboxWatcher.soundFor(item('alarm_request_answered')), 'fire');

      StaffAccount.current = {'agency_type': 'medical'};
      addTearDown(() => StaffAccount.current = null);
      expect(InboxWatcher.soundFor(item('responder_dispatch')), 'medical');
      expect(InboxWatcher.soundFor(item('incident_routed')), 'medical');
      expect(InboxWatcher.soundFor(item('test')), 'medical');
    });
  });
}

/// Stands in for WorkManager. [answers] false: a call never comes back.
class _Scheduler extends BeaconScheduler {
  const _Scheduler({this.answers = true});

  final bool answers;

  Future<void> _call() =>
      answers ? Future<void>.value() : Completer<void>().future;

  @override
  Future<void> initialize() => _call();

  @override
  Future<void> schedule(String name, Duration every) => _call();

  @override
  Future<void> cancel(String name) => _call();
}
