import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/alerts/buzz.dart';
import 'package:replit/alerts/inbox_watcher.dart';
import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/screens/signed_in_elsewhere_screen.dart';
import 'package:replit/security/developer_mode.dart';
import 'package:replit/theme.dart';

/// App v1.12.35 (12 November 2026): every alert vibrates, an iPhone rings
/// for news while open, and one phone per account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const device = MethodChannel('replit/device');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    Buzz.buzzes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, null);
  });

  group('every alert vibrates', () {
    test(
      'Android: the phone vibrates in the alert channels\' rhythm',
      () async {
        await Buzz.alert();
        expect(calls.single.method, 'vibrate');
        expect(calls.single.arguments, {
          'pattern': [0, 600, 250, 600, 250, 600],
        });
        expect(Buzz.buzzes, 1);
      },
    );
  });

  group('the open app rings for news where push does not reach', () {
    Map<String, dynamic> item(
      String id,
      DateTime at, {
      String type = 'incident_update',
      String? event,
    }) => {
      'id': id,
      'type': type,
      'title': 'Help is on the way',
      'body': 'Responders are on their way.',
      'created_at': at.toUtc().toIso8601String(),
      'data': {'event': ?event},
    };

    test('each kind of news plays the sound its push would', () {
      final now = DateTime.now();
      expect(
        InboxWatcher.soundFor(item('1', now, event: 'incident_en_route')),
        'on_route',
      );
      expect(
        InboxWatcher.soundFor(item('1', now, event: 'incident_arrived')),
        'on_scene',
      );
      expect(
        InboxWatcher.soundFor(item('1', now, event: 'incident_resolved')),
        'fire_out',
      );
      expect(
        InboxWatcher.soundFor(item('1', now, event: 'incident_rejected')),
        'rejected',
      );
      expect(
        InboxWatcher.soundFor(item('1', now, event: 'incident_verified')),
        'verified',
      );
      expect(InboxWatcher.soundFor(item('1', now, type: 'fire_alert')), 'fire');
      expect(
        InboxWatcher.soundFor(item('1', now, type: 'national_id_reviewed')),
        'citizen',
      );
    });

    testWidgets('news already there when watching starts does not ring; '
        'what comes after does', (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': 't'});
      await Session.instance.restore();
      final old = DateTime.now().subtract(const Duration(hours: 2));
      var inbox = [item('a', old, event: 'incident_verified')];
      final watcher = InboxWatcher.instance
        ..useApi(
          ApiClient(
            client: MockClient(
              (_) async => http.Response(jsonEncode(inbox), 200),
            ),
          ),
        );
      addTearDown(watcher.stop);

      await watcher.poll();
      expect(Buzz.buzzes, 0, reason: 'two hours old: it is in the Alerts list');

      inbox = [item('b', DateTime.now(), event: 'incident_en_route'), ...inbox];
      await watcher.poll();
      expect(Buzz.buzzes, 1);

      await watcher.poll();
      expect(Buzz.buzzes, 1, reason: 'rung once');
      await Session.instance.clear();
    });
  });

  group('one phone per account', () {
    test('a refusal for a newer sign-in tells the app once', () async {
      var told = 0;
      ApiClient.onSignedInElsewhere = () => told++;
      ApiClient.signedInHere();
      addTearDown(() => ApiClient.onSignedInElsewhere = null);
      SharedPreferences.setMockInitialValues({'access_token': 't'});
      await Session.instance.restore();
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'signed_in_elsewhere',
              'message': 'Your account was opened on another phone.',
            }),
            403,
          ),
        ),
      );
      await expectLater(api.getNotifications(), throwsA(isA<ApiException>()));
      await expectLater(api.getNotifications(), throwsA(isA<ApiException>()));
      expect(told, 1);

      // Signing in again here makes the next one news again.
      ApiClient.signedInHere();
      await expectLater(api.getNotifications(), throwsA(isA<ApiException>()));
      expect(told, 2);
      await Session.instance.clear();
    });

    testWidgets('the warning says why, and Exit forgets the session', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'access_token': 't'});
      await Session.instance.restore();
      var exited = 0;
      DeveloperMode.exitOverride = () async => exited++;
      addTearDown(() => DeveloperMode.exitOverride = null);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const SignedInElsewhereScreen(),
        ),
      );
      expect(find.text('OPENED ON ANOTHER PHONE'), findsOneWidget);
      expect(find.text('EXIT'), findsOneWidget);

      await tester.tap(find.text('EXIT'));
      await tester.pumpAndSettle();
      expect(Session.instance.isAuthenticated, isFalse);
      expect(exited, 1);
    });
  });
}
