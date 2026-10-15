import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/api_client.dart';
import '../../api/live_refresh.dart';
import '../../location/responder_tracker.dart';
import '../../models/area_view.dart';
import 'responder_status.dart';

/// What the responder's tabs share (REPLIT (MAIN) 07): the live Areas their
/// agency sees, the counters behind them, and the run this responder is on.
///
/// Read once for every tab, re-read the moment the server says an incident
/// changed ([LiveRefresh]) and every 10 s as the fallback.
///
/// It also picks up a run made while the responder was elsewhere — the app
/// closed mid-response, say — and resumes sharing their location for it
/// ([ResponderTracker], "5 s while dispatched", §6), as the old dashboard
/// did.
class ResponderFeed extends ChangeNotifier {
  ResponderFeed({required this.me, ApiClient? api, ResponderTracker? tracker})
    : api = api ?? ApiClient(),
      tracker = tracker ?? ResponderTracker.instance;

  final Map<String, dynamic> me;
  final ApiClient api;
  final ResponderTracker tracker;

  String get myId => me['id'] as String? ?? '';
  String? get agency => me['agency_type'] as String?;
  String? get orgId => me['primary_org_id'] as String?;

  /// The unit this responder answers for: their team ("Tanker 1"), else the
  /// agency. No endpoint assigns a truck to a responder, so the team stands
  /// in for it (§2.7.1).
  String get unit {
    final team = (me['organization_name'] as String?)?.trim();
    return team == null || team.isEmpty ? agencyLabel(agency) : team;
  }

  /// Live Areas (reported through arrived), newest first.
  List<AreaView> areas = const [];

  /// GET /incidents/stats, or null until it answers.
  Map<String, dynamic>? stats;

  bool loaded = false;
  String? error;

  /// The run RUN shows when nothing is being shared: the last one this
  /// session, kept after fire out so "Stood down" can be read.
  String? _lastRun;

  late final LiveRefresh _live = LiveRefresh(agencyChannels(agency), load);
  Timer? _poll;
  bool _disposed = false;
  bool _checking = false;

  /// The Area this responder's run is for: the one their location is shared
  /// for, else the last one this session. Null when they have had none.
  String? get runId => tracker.sharingFor.value ?? _lastRun;

  /// Live Areas that are not this responder's run: what Duty offers.
  List<AreaView> get needsUnit => [
    for (final a in areas)
      if (a.id != runId && (a.toDecide || a.active)) a,
  ];

  AreaView? byId(String id) {
    for (final a in areas) {
      if (a.id == id) return a;
    }
    return null;
  }

  void start() {
    tracker.sharingFor.addListener(_onSharing);
    load();
    _live.start();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  void _onSharing() {
    final id = tracker.sharingFor.value;
    if (id != null) _lastRun = id;
    if (!_disposed) notifyListeners();
  }

  /// "Back to duty" after a run has ended. A run still shared stays.
  void clearRun() {
    if (tracker.isSharing) return;
    _lastRun = null;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        api.getIncidents(),
        api.getIncidentStats().then<Object?>((s) => s).catchError((_) => null),
      ]);
      if (_disposed) return;
      areas = [
        for (final r in (results[0] as List).cast<Map<String, dynamic>>())
          AreaView(r),
      ];
      final s = results[1];
      if (s is Map<String, dynamic>) stats = s;
      loaded = true;
      error = null;
      notifyListeners();
      unawaited(_pickUpRun());
    } catch (_) {
      if (_disposed) return;
      // Keep the last good list; say so only when there is none.
      if (!loaded) {
        error = 'Could not reach command. Check your signal.';
        notifyListeners();
      }
    }
  }

  /// A run made while the responder was on another screen, or before the
  /// app was closed: sharing starts without waiting for them to open it.
  /// Only Areas on the ground are checked — usually none, rarely two.
  Future<void> _pickUpRun() async {
    if (tracker.isSharing || _checking) return;
    _checking = true;
    try {
      for (final a in areas) {
        if (!a.live) continue;
        final dispatches = (await api.getDispatches(
          a.id,
        )).cast<Map<String, dynamic>>();
        final mine = dispatches.where(
          (d) => d['responder_id'] == myId && d['status'] == 'active',
        );
        if (mine.isNotEmpty) {
          await tracker.start(
            incidentId: a.id,
            dispatchId: mine.first['id'] as String,
          );
          break;
        }
      }
    } catch (_) {
      // Tried again on the next read.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    tracker.sharingFor.removeListener(_onSharing);
    _poll?.cancel();
    unawaited(_live.dispose());
    super.dispose();
  }
}
