import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/session.dart';
import 'resident_status.dart';

/// The report a resident sent and is still following.
///
/// Once someone has reported an emergency, that report is the thing the app is
/// for until the fire is out: reopening the app, or pressing SOS again, leads
/// back to it rather than to a blank dial. This is the record that makes that
/// possible — kept on the phone, because it has to survive the app being
/// closed, and scoped to the account that sent it, so a second person signing
/// in on the same phone is never shown someone else's emergency.
@immutable
class ActiveReport {
  const ActiveReport({
    required this.owner,
    required this.lat,
    required this.lng,
    required this.submittedAt,
    this.reportId,
    this.areaId,
    this.designation = '—',
    this.agencies = const [],
    this.message,
  });

  /// The signed-in email when it was sent.
  final String owner;
  final String? reportId;

  /// The incident it was grouped into. Can change: a merge folds one area
  /// into another, and the report follows it.
  final String? areaId;
  final String designation;
  final double lat;
  final double lng;
  final DateTime submittedAt;
  final List<String> agencies;
  final String? message;

  /// A report this old is not a live emergency any more. Without a limit, one
  /// that a coordinator never picked up would hold the app forever.
  static const Duration staleAfter = Duration(hours: 12);

  bool get isStale => DateTime.now().difference(submittedAt) > staleAfter;

  ActiveReport movedTo({required String areaId, String? designation}) =>
      _copy(areaId: areaId, designation: designation);

  /// The same report with more kinds of help asked for ("Add more help").
  ActiveReport withAgencies(Iterable<String> more) =>
      _copy(agencies: {...agencies, ...more}.toList());

  ActiveReport _copy({
    String? areaId,
    String? designation,
    List<String>? agencies,
  }) => ActiveReport(
    owner: owner,
    reportId: reportId,
    areaId: areaId ?? this.areaId,
    designation: designation ?? this.designation,
    lat: lat,
    lng: lng,
    submittedAt: submittedAt,
    agencies: agencies ?? this.agencies,
    message: message,
  );

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'report_id': reportId,
    'area_id': areaId,
    'designation': designation,
    'lat': lat,
    'lng': lng,
    'submitted_at': submittedAt.toUtc().toIso8601String(),
    'agencies': agencies,
    'message': message,
  };

  static ActiveReport? fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse('${json['submitted_at']}');
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (at == null || lat == null || lng == null) return null;
    return ActiveReport(
      owner: '${json['owner'] ?? ''}',
      reportId: json['report_id'] as String?,
      areaId: json['area_id'] as String?,
      designation: (json['designation'] as String?) ?? '—',
      lat: lat,
      lng: lng,
      submittedAt: at.toLocal(),
      agencies: [for (final a in (json['agencies'] as List? ?? const [])) '$a'],
      message: json['message'] as String?,
    );
  }
}

/// Where the report in progress is kept.
abstract final class ActiveReportStore {
  static const String _key = 'active_report_v1';

  /// Whatever is saved, whoever it belongs to. Read [mine] instead.
  static final ValueNotifier<ActiveReport?> current = ValueNotifier(null);

  /// The report in progress for whoever is signed in now, or null.
  static ActiveReport? get mine {
    final report = current.value;
    if (report == null || report.isStale) return null;
    if (report.owner != (Session.instance.email ?? '')) return null;
    return report;
  }

  /// Read the saved report. Called once, before the first frame.
  static Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      current.value = raw == null
          ? null
          : ActiveReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      current.value = null;
    }
  }

  /// A report just went out: it is now the one to follow.
  static Future<void> start(ActiveReport report) async {
    current.value = report;
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(report.toJson()),
      );
    } catch (_) {
      // Still followed for this session.
    }
  }

  /// The resident said they are done with it.
  static Future<void> finish() async {
    current.value = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      // Gone from this session either way.
    }
  }

  /// A report that waited offline has just gone through: follow it too.
  ///
  /// The queue only knows where and when it was sent, so this finds the
  /// server's copy the way the queue's own duplicate check does — the exact
  /// coordinates, among this person's reports.
  static Future<void> adoptDelivered({
    required double lat,
    required double lng,
    required List<String> agencies,
    ApiClient? api,
  }) async {
    try {
      final reports = await (api ?? ApiClient()).getMyReports();
      for (final raw in reports) {
        final r = raw as Map<String, dynamic>;
        final rLat = (r['device_lat'] as num?)?.toDouble();
        final rLng = (r['device_lng'] as num?)?.toDouble();
        if (rLat != lat || rLng != lng) continue;
        await start(
          ActiveReport(
            owner: Session.instance.email ?? '',
            reportId: r['id'] as String?,
            areaId: r['area_id'] as String?,
            designation: (r['area_designation'] as String?) ?? '—',
            lat: lat,
            lng: lng,
            submittedAt:
                DateTime.tryParse('${r['created_at']}')?.toLocal() ??
                DateTime.now(),
            agencies: agencies,
          ),
        );
        return;
      }
    } catch (_) {
      // It is in Your reports regardless; only the shortcut is lost.
    }
  }

  /// Agencies were added to the report in progress: remember them, so the
  /// next "Track it live" does not offer them again.
  static Future<void> addAgencies(String areaId, Iterable<String> more) async {
    final report = mine;
    if (report == null || report.areaId != areaId) return;
    await start(report.withAgencies(more));
  }

  /// The report in progress, asking the server when the phone has none.
  ///
  /// The phone's record goes with a reinstall, cleared app data or a second
  /// phone, but the server still refuses a second report while one is live —
  /// so without this the app would offer a dial that can only fail. Picks the
  /// newest report from the last [ActiveReport.staleAfter] whose incident is
  /// still going on, the same rule the server applies.
  static Future<ActiveReport?> recover({ApiClient? api}) async {
    final local = mine;
    if (local != null) return local;
    if (!Session.instance.isAuthenticated) return null;
    try {
      final reports = await (api ?? ApiClient()).getMyReports();
      // Newest first, as the server lists them.
      for (final raw in reports) {
        final r = raw as Map<String, dynamic>;
        final at = DateTime.tryParse('${r['created_at']}')?.toLocal();
        if (at == null) continue;
        if (DateTime.now().difference(at) > ActiveReport.staleAfter) break;
        final status = r['area_status'] as String?;
        if (status == null || residentOver(residentStatus(status))) continue;
        final lat = (r['device_lat'] as num?)?.toDouble();
        final lng = (r['device_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final report = ActiveReport(
          owner: Session.instance.email ?? '',
          reportId: r['id'] as String?,
          areaId: r['area_id'] as String?,
          designation: (r['area_designation'] as String?) ?? '—',
          lat: lat,
          lng: lng,
          submittedAt: at,
          agencies: [
            for (final a in (r['selected_agencies'] as List? ?? const [])) '$a',
          ],
        );
        await start(report);
        return report;
      }
    } catch (_) {
      // No answer: the server still turns a second report down, and says why.
    }
    return null;
  }

  @visibleForTesting
  static void reset() => current.value = null;
}

/// Set while a resident is part-way through a new report — on the camera or
/// the form — so reopening the app does not snatch them away from it.
abstract final class ReportComposer {
  static int _open = 0;

  static bool get active => _open > 0;

  static void enter() => _open++;

  static void leave() {
    if (_open > 0) _open--;
  }
}
