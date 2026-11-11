import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../api/session.dart';

/// Keeps the server's idea of where this phone is fresh, for the 100 m
/// neighbour alert.
///
/// The server alerts a resident only if the location their phone last
/// reported is under 30 minutes old (backend: users.location_updated_at and
/// NEIGHBORHOOD_LOCATION_MAX_AGE_MINUTES). Until 5 November it trusted a
/// location of any age, and the phone sent one only when the app opened, so a
/// resident who had long left home was still alerted for a fire next to it
/// (the 5 November issue list, 2.2). So this reports:
///
/// - while the app is open, every [openInterval] ([startOpen], from the app
///   root), as well as on resume (PushService.refreshLocation);
/// - while it is closed, about every [closedInterval] through Android's
///   WorkManager ([syncClosed]), for a resident who allows location "All the
///   time". Without that permission Android gives a closed app no location at
///   all, so the task is not scheduled, and alerts reach them while their
///   last report from an open app is fresh.
abstract final class LocationBeacon {
  static const Duration openInterval = Duration(minutes: 5);
  static const Duration closedInterval = Duration(minutes: 15);

  /// A closed-app report is skipped when the open app reported this recently.
  static const Duration skipIfSentWithin = Duration(minutes: 10);

  static const String _task = 'replit-location-beacon';

  /// When this phone last reported its location, in ms since the epoch.
  static const String sentKey = 'location_sent_at_ms';

  static Timer? _open;

  /// Only Android schedules work while closed; iPhones are sideloaded test
  /// builds and get the open-app reports.
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// For tests: stands in for WorkManager.
  @visibleForTesting
  static BeaconScheduler? schedulerOverride;

  static BeaconScheduler get _scheduler =>
      schedulerOverride ?? const _WorkManagerScheduler();

  /// Called once in main(), before anything is scheduled.
  static Future<void> init() async {
    if (!_android) return;
    try {
      await _scheduler.initialize();
    } catch (_) {
      // No WorkManager: the open-app reports still run.
    }
  }

  /// Report every [openInterval] while the app is in front. [send] is the
  /// report itself (PushService.refreshLocation, which asks no questions).
  static void startOpen(Future<void> Function() send) {
    _open?.cancel();
    _open = Timer.periodic(openInterval, (_) => unawaited(send()));
  }

  static void stopOpen() {
    _open?.cancel();
    _open = null;
  }

  /// Note that the phone just reported, so the closed-app task can skip.
  static Future<void> markSent([DateTime? at]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        sentKey,
        (at ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (_) {
      // Not knowing only costs one extra report.
    }
  }

  /// Whether the phone reported within [within], as another isolate may have
  /// written it: the stored value is re-read, not this isolate's cache.
  static Future<bool> sentWithin(Duration within, {DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final at = prefs.getInt(sentKey);
      if (at == null) return false;
      final age = (now ?? DateTime.now()).difference(
        DateTime.fromMillisecondsSinceEpoch(at),
      );
      return age < within;
    } catch (_) {
      return false;
    }
  }

  /// Schedule the closed-app reports when they can work — signed in, alerts
  /// on, location allowed "All the time" — and cancel them when they cannot.
  static Future<void> syncClosed({required bool alertsOn}) async {
    if (!_android) return;
    try {
      final allowed =
          await Geolocator.checkPermission() == LocationPermission.always;
      if (Session.instance.isAuthenticated && alertsOn && allowed) {
        await _scheduler.schedule(_task, closedInterval);
      } else {
        await _scheduler.cancel(_task);
      }
    } catch (_) {
      // Leave whatever is scheduled; the task checks all of this again.
    }
  }

  /// Stop the closed-app reports (signing out, alerts off).
  static Future<void> cancelClosed() async {
    if (!_android) return;
    try {
      await _scheduler.cancel(_task);
    } catch (_) {
      // Nothing was scheduled.
    }
  }

  /// One closed-app report, from WorkManager's isolate. True tells WorkManager
  /// the run is done; a run with nothing to do is not a failure.
  static Future<bool> reportWhileClosed({
    Future<Position?> Function()? locate,
    Future<void> Function(double lat, double lng)? send,
  }) async {
    // The open app reports on its own, every 5 minutes.
    if (await sentWithin(skipIfSentWithin)) return true;
    await Session.instance.restore();
    if (!Session.instance.isAuthenticated) return true;
    final position = await (locate ?? _locate)();
    if (position == null) return true;
    await (send ?? ApiClient().updateMyLocation)(
      position.latitude,
      position.longitude,
    );
    await markSent();
    return true;
  }

  static Future<Position?> _locate() async {
    try {
      if (await Geolocator.checkPermission() != LocationPermission.always) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } catch (_) {
        // No fresh fix in time (indoors, say): the phone's own last one.
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }
}

/// What schedules the closed-app reports: WorkManager on a phone.
abstract class BeaconScheduler {
  const BeaconScheduler();
  Future<void> initialize();
  Future<void> schedule(String name, Duration every);
  Future<void> cancel(String name);
}

class _WorkManagerScheduler extends BeaconScheduler {
  const _WorkManagerScheduler();

  @override
  Future<void> initialize() =>
      Workmanager().initialize(locationBeaconDispatcher);

  @override
  Future<void> schedule(String name, Duration every) =>
      Workmanager().registerPeriodicTask(
        name,
        name,
        frequency: every,
        constraints: Constraints(networkType: NetworkType.connected),
        // Keep the one already counting down rather than restarting it on
        // every resume.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );

  @override
  Future<void> cancel(String name) => Workmanager().cancelByUniqueName(name);
}

/// WorkManager's way into Dart for the closed-app report.
@pragma('vm:entry-point')
void locationBeaconDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      return await LocationBeacon.reportWhileClosed();
    } catch (_) {
      return true;
    }
  });
}
