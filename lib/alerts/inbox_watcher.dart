import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_cache.dart';
import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../sound/sound_cues.dart';
import '../widgets/staff_shell.dart' show StaffAccount;
import 'buzz.dart';

/// Sounds and vibration for news while the app is open, where push does not
/// reach (12 November 2026: "notification sound triggers inside the app when
/// it's open (to make sound work on iOS when the app is open)").
///
/// The iPhone build has no Apple push, so a Firebase message never arrives
/// there. Everything RepLiT pushes is also written to the account's inbox
/// (GET /notifications), so while the app is open this reads the inbox every
/// [every] and, for anything new, plays the sound the push would have —
/// the report's stage, the agency's alarm, the fire near you — vibrates, and
/// shows the banner. On Android, Firebase delivers to the open app and
/// PushService does the same, so this stays off there.
class InboxWatcher with WidgetsBindingObserver {
  InboxWatcher._();

  static final InboxWatcher instance = InboxWatcher._();

  static const Duration every = Duration(seconds: 15);

  /// News older than this when the app comes back is not rung: it is in the
  /// Alerts list.
  static const Duration freshFor = Duration(minutes: 5);

  /// Where push does not reach the open app.
  static bool get needed =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  ApiClient _api = ApiClient();
  Timer? _timer;
  bool _started = false;

  /// The newest inbox item already rung (or already there when watching
  /// began); null until the first read.
  String? _newestId;
  DateTime? _newestAt;

  @visibleForTesting
  void useApi(ApiClient api) => _api = api;

  /// Start watching (main.dart, once). Does nothing where push reaches.
  void start({bool force = false}) {
    if (_started || !(needed || force)) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  @visibleForTesting
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _newestId = null;
    _newestAt = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => unawaited(poll()));
    unawaited(poll());
  }

  /// Read the inbox once and ring for what is new. Public for tests.
  @visibleForTesting
  Future<void> poll() async {
    if (!Session.instance.isAuthenticated) {
      _newestId = null;
      _newestAt = null;
      return;
    }
    List<Map<String, dynamic>> items;
    try {
      items = (await _api.getNotifications())
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return; // No signal: the next read tries again.
    }
    if (items.isEmpty) return;
    final newest = items.first;
    final first = _newestId == null && _newestAt == null;
    final fresh = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item['id'] == _newestId) break;
      final at = DateTime.tryParse('${item['created_at'] ?? ''}');
      if (_newestAt != null && at != null && !at.isAfter(_newestAt!)) break;
      fresh.add(item);
    }
    _newestId = newest['id'] as String?;
    _newestAt = DateTime.tryParse('${newest['created_at'] ?? ''}');
    if (fresh.isEmpty) return;
    if (first) {
      // What was there before watching began rings only if it just came.
      final at = DateTime.tryParse('${newest['created_at'] ?? ''}');
      if (at == null ||
          DateTime.now().toUtc().difference(at.toUtc()) > freshFor) {
        return;
      }
      await announce(newest);
      return;
    }
    // Oldest first, one sound for the newest: several at once ring once.
    await announce(fresh.first);
  }

  /// Ring for one inbox item: its sound, a vibration, the banner.
  @visibleForTesting
  Future<void> announce(Map<String, dynamic> item) async {
    // The account's own news: Profile, showing it, asks again (v1.12.42).
    if (item['type'] == 'national_id_reviewed') {
      ApiCache.instance.accountChangedNow();
    }
    unawaited(Buzz.alert());
    unawaited(SoundCues.instance.playAlert(soundFor(item)));
    final title = (item['title'] as String?) ?? 'RepLiT';
    final body = (item['body'] as String?) ?? '';
    if (body.isEmpty) return;
    PushService.messengerKey.currentState?.showSnackBar(
      PushService.inAppBanner(
        title: title,
        body: body,
        fire: item['type'] == 'fire_alert' || item['type'] == 'incident_new',
      ),
    );
  }

  /// The sound a push of this kind plays (app/integrations/fcm.py,
  /// incident_notify.py): a report's stage, a staff member's agency alarm,
  /// the fire near you; the general one otherwise.
  ///
  /// v1.12.42, as the server's pushes (backend v1.12.33): a fire near a
  /// resident plays "01 NEARBY INCIDENT", the citizen recording, not the
  /// staff fire alarm; a staff member's other news plays their agency's
  /// recording; an alarm request and its answer the fire one; the National
  /// ID's result its own, which the inbox row names.
  static String soundFor(Map<String, dynamic> item) {
    final data = item['data'];
    final event = data is Map ? data['event'] as String? : null;
    final category = data is Map ? data['sound_category'] as String? : null;
    if (category != null && SoundCues.categories.contains(category)) {
      return category;
    }
    final staff = StaffAccount.current;
    final agencySound = SoundCues.categoryForAgency(
      staff?['agency_type'] as String?,
    );
    return switch (item['type']) {
      'fire_alert' => 'citizen',
      'incident_new' ||
      'responder_dispatch' ||
      'incident_routed' ||
      'incident_reminder' => agencySound,
      'alarm_request' || 'alarm_request_answered' => 'fire',
      'test' => staff == null ? 'citizen' : agencySound,
      'incident_update' => switch (event) {
        'incident_verified' => 'verified',
        'incident_en_route' => 'on_route',
        'incident_arrived' => 'on_scene',
        'incident_resolved' => 'fire_out',
        'incident_rejected' => 'rejected',
        _ => 'citizen',
      },
      // "New Update!": its own recording, in the app's language.
      'app_update' => SoundCues.update,
      _ => 'citizen',
    };
  }
}
