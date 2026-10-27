import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/api_client.dart';
import '../../api/live_refresh.dart';
import '../../models/alarm.dart';
import '../../models/area_view.dart';

/// What the coordinator's tabs share: the live Areas their agency sees, the
/// reports their team still owes, the overlaps waiting on a decision and,
/// for BFP, the alarm requests waiting on it.
///
/// Read once for all five tabs rather than once per tab, re-read the moment
/// the server says an incident changed ([LiveRefresh]) and every 10 s as the
/// fallback — a dropped socket costs freshness, never correctness.
class CoordinatorFeed extends ChangeNotifier {
  CoordinatorFeed({required this.me, ApiClient? api})
    : api = api ?? ApiClient();

  final Map<String, dynamic> me;
  final ApiClient api;

  String get myId => me['id'] as String? ?? '';
  String? get agency => me['agency_type'] as String?;
  bool get isBfp => agency == 'bfp';

  /// Live Areas (reported through arrived), newest first.
  List<AreaView> areas = const [];

  /// Fire out, and this team has not filed its Post-Incident Report.
  List<AreaView> owed = const [];

  /// Pending overlap decisions (GET /areas/overlaps/pending).
  List<Map<String, dynamic>> overlaps = const [];

  /// BFP only: alarm requests no BFP Coordinator has answered, newest first.
  /// A new one reaches `agency:bfp` at once, which reloads the feed.
  List<AlarmRequest> alarmAsks = const [];

  bool loaded = false;
  String? error;

  late final LiveRefresh _live = LiveRefresh(agencyChannels(agency), load);
  Timer? _poll;
  bool _disposed = false;

  List<AreaView> get toDecide => [
    for (final a in areas)
      if (a.toDecide) a,
  ];

  List<AreaView> get active => [
    for (final a in areas)
      if (a.active) a,
  ];

  AreaView? byId(String id) {
    for (final a in [...areas, ...owed]) {
      if (a.id == id) return a;
    }
    return null;
  }

  void start() {
    load();
    _live.start();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        api.getIncidents(),
        api.getOwedPostIncidentReports().catchError((_) => <dynamic>[]),
        api.getPendingOverlaps().catchError((_) => <dynamic>[]),
        if (isBfp)
          api
              .getAlarmRequests(status: 'pending')
              .catchError((_) => <dynamic>[]),
      ]);
      if (_disposed) return;
      alarmAsks = [
        if (isBfp)
          for (final r in results[3].whereType<Map<String, dynamic>>())
            AlarmRequest(r),
      ];
      areas = [
        for (final r in results[0].cast<Map<String, dynamic>>()) AreaView(r),
      ];
      owed = [
        for (final r in results[1].cast<Map<String, dynamic>>()) AreaView(r),
      ];
      overlaps = results[2].cast<Map<String, dynamic>>();
      loaded = true;
      error = null;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      // Keep the last good lists; say so only when there are none.
      if (!loaded) {
        error = 'Could not load the queue. Check your signal.';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    unawaited(_live.dispose());
    super.dispose();
  }
}
