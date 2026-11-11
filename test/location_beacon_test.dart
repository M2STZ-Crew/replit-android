import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/session.dart';
import 'package:replit/location/location_beacon.dart';

/// The 100 m alert only counts a location reported in the last 30 minutes
/// (backend, same branch), so the phone keeps reporting: every 5 minutes
/// while open, and every ~15 while closed for a resident who allows location
/// "All the time" (the 5 November issue list, 2.2).
class _Geo extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.always;

  @override
  Future<LocationPermission> checkPermission() async => permission;
}

class _Scheduler extends BeaconScheduler {
  final List<String> calls = [];

  @override
  Future<void> initialize() async => calls.add('init');

  @override
  Future<void> schedule(String name, Duration every) async =>
      calls.add('schedule $name ${every.inMinutes}m');

  @override
  Future<void> cancel(String name) async => calls.add('cancel $name');
}

Position _at(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _Geo geo;
  late _Scheduler scheduler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'a1',
      'refresh_token': 'r1',
    });
    Session.instance.setTokens(accessToken: 'a1', refreshToken: 'r1');
    geo = _Geo();
    GeolocatorPlatform.instance = geo;
    scheduler = _Scheduler();
    LocationBeacon.schedulerOverride = scheduler;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() async {
    LocationBeacon.schedulerOverride = null;
    LocationBeacon.stopOpen();
    debugDefaultTargetPlatformOverride = null;
    await Session.instance.clear();
  });

  group('while closed', () {
    test('a stale phone reports where it is, and notes when', () async {
      final sent = <(double, double)>[];
      final ok = await LocationBeacon.reportWhileClosed(
        locate: () async => _at(14.5378, 121.0014),
        send: (lat, lng) async => sent.add((lat, lng)),
      );
      expect(ok, isTrue);
      expect(sent, [(14.5378, 121.0014)]);
      expect(
        await LocationBeacon.sentWithin(const Duration(minutes: 1)),
        isTrue,
      );
    });

    test('the open app reported a moment ago: nothing to add', () async {
      await LocationBeacon.markSent(
        DateTime.now().subtract(const Duration(minutes: 3)),
      );
      var located = false;
      await LocationBeacon.reportWhileClosed(
        locate: () async {
          located = true;
          return _at(1, 1);
        },
        send: (_, _) async {},
      );
      expect(located, isFalse);
    });

    test('signed out: nothing is sent', () async {
      await Session.instance.clear();
      var sent = false;
      final ok = await LocationBeacon.reportWhileClosed(
        locate: () async => _at(1, 1),
        send: (_, _) async => sent = true,
      );
      expect(ok, isTrue, reason: 'a run with nothing to do is not a failure');
      expect(sent, isFalse);
    });

    test('no fix: nothing is sent, and the run still ends well', () async {
      var sent = false;
      final ok = await LocationBeacon.reportWhileClosed(
        locate: () async => null,
        send: (_, _) async => sent = true,
      );
      expect(ok, isTrue);
      expect(sent, isFalse);
    });
  });

  group('scheduling the closed-app reports', () {
    test(
      'signed in, alerts on and allowed all the time: every 15 min',
      () async {
        await LocationBeacon.syncClosed(alertsOn: true);
        expect(scheduler.calls, ['schedule replit-location-beacon 15m']);
      },
    );

    test(
      'allowed only while in use: none, Android gives no location',
      () async {
        geo.permission = LocationPermission.whileInUse;
        await LocationBeacon.syncClosed(alertsOn: true);
        expect(scheduler.calls, ['cancel replit-location-beacon']);
      },
    );

    test('alerts off: none', () async {
      await LocationBeacon.syncClosed(alertsOn: false);
      expect(scheduler.calls, ['cancel replit-location-beacon']);
    });

    test('an iPhone schedules nothing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await LocationBeacon.syncClosed(alertsOn: true);
      await LocationBeacon.cancelClosed();
      expect(scheduler.calls, isEmpty);
    });
  });

  testWidgets('while open, it reports every 5 minutes', (tester) async {
    var sent = 0;
    LocationBeacon.startOpen(() async => sent++);
    await tester.pump(const Duration(minutes: 4));
    expect(sent, 0);
    await tester.pump(const Duration(minutes: 1));
    expect(sent, 1);
    await tester.pump(const Duration(minutes: 10));
    expect(sent, 3);
    LocationBeacon.stopOpen();
    await tester.pump(const Duration(minutes: 10));
    expect(sent, 3);
    // A widget test checks the platform override is gone before tearDown.
    debugDefaultTargetPlatformOverride = null;
  });
}
