import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sound/sound_cues.dart';
import 'api_client.dart';

/// A report that could not reach the server, saved on the phone to send later.
@immutable
class QueuedReport {
  const QueuedReport({
    required this.id,
    required this.lat,
    required this.lng,
    required this.agencies,
    required this.notes,
    required this.queuedAt,
    required this.photoPath,
    this.accuracyM,
  });

  final String id;
  final double lat;
  final double lng;
  final double? accuracyM;
  final List<String> agencies;
  final String notes;
  final DateTime queuedAt;
  final String photoPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': lat,
    'lng': lng,
    'accuracy_m': accuracyM,
    'agencies': agencies,
    'notes': notes,
    'queued_at': queuedAt.toUtc().toIso8601String(),
    'photo_path': photoPath,
  };

  static QueuedReport fromJson(Map<String, dynamic> j) => QueuedReport(
    id: j['id'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
    agencies: (j['agencies'] as List).cast<String>(),
    notes: (j['notes'] as String?) ?? '',
    queuedAt: DateTime.parse(j['queued_at'] as String).toLocal(),
    photoPath: j['photo_path'] as String,
  );
}

/// The offline report queue — "05 Map — offline queue" in the REPLIT-OVERHAUL
/// Figma: "Your report and photo are saved on this phone. They send themselves
/// the second you get signal."
///
/// A report goes in only when the server could not be reached at all; one the
/// server *refused* is not queued, because sending it again would be refused
/// again. The photo is written to the app's documents directory and the rest
/// to SharedPreferences, so a queued report survives the app being closed.
///
/// `/reports/submit` has no idempotency key, and a retry after a response was
/// lost in transit would file the same report twice — counting one resident as
/// two corroborating reporters. So before each resend the queue asks
/// `/reports/mine` whether a report at exactly these coordinates already
/// landed, and if it did, drops the copy instead of sending it.
class ReportQueue {
  ReportQueue._();

  static final ReportQueue instance = ReportQueue._();

  static const Duration retryEvery = Duration(seconds: 15);
  static const String _prefsKey = 'report_queue_v1';

  /// Reports waiting to send, oldest first.
  final ValueNotifier<List<QueuedReport>> pending = ValueNotifier(const []);

  /// True when the last attempt could not reach the server.
  final ValueNotifier<bool> offline = ValueNotifier(false);

  /// Set when the server turned a queued report down (a 4xx other than 401),
  /// so the UI can say so instead of the report vanishing without a word.
  final ValueNotifier<String?> lastRejection = ValueNotifier(null);

  /// Fires once per queued report that reaches the server.
  final StreamController<QueuedReport> _delivered =
      StreamController.broadcast();
  Stream<QueuedReport> get delivered => _delivered.stream;

  // Lazy: nothing is opened until a report is actually queued or retried.
  late ApiClient _api = ApiClient();
  Directory? _dirOverride;
  Timer? _timer;
  Future<void>? _loading;
  bool _flushing = false;

  /// Point the queue at a fake server and a temp directory (tests only).
  @visibleForTesting
  void configureForTest({required ApiClient api, required Directory dir}) {
    _api = api;
    _dirOverride = dir;
  }

  @visibleForTesting
  void reset() {
    _timer?.cancel();
    _timer = null;
    _loading = null;
    _flushing = false;
    pending.value = const [];
    offline.value = false;
    lastRejection.value = null;
  }

  Future<Directory> _dir() async {
    final base = _dirOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}report_queue');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Restore anything queued in an earlier session and start retrying it.
  /// Safe to call more than once.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final items = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(QueuedReport.fromJson)
          // A report whose photo is gone cannot be sent — the server
          // requires one — so it is not kept pretending to wait.
          .where((r) => File(r.photoPath).existsSync())
          .toList();
      pending.value = List.unmodifiable(items);
      _schedule();
    } catch (_) {
      // A corrupt entry must not stop the app starting.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(pending.value.map((r) => r.toJson()).toList()),
    );
  }

  /// Save a report that could not be sent, and start retrying it.
  Future<QueuedReport> enqueue({
    required double lat,
    required double lng,
    double? accuracyM,
    required List<String> agencies,
    required String notes,
    required List<int> photoBytes,
  }) async {
    await load();
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final dir = await _dir();
    final photo = File('${dir.path}${Platform.pathSeparator}$id.jpg');
    await photo.writeAsBytes(photoBytes, flush: true);
    final report = QueuedReport(
      id: id,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      agencies: agencies,
      notes: notes,
      queuedAt: now,
      photoPath: photo.path,
    );
    pending.value = List.unmodifiable([...pending.value, report]);
    offline.value = true;
    await _save();
    _schedule();
    return report;
  }

  void _schedule() {
    if (pending.value.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(retryEvery, (_) => flush());
  }

  Future<void> _remove(QueuedReport report) async {
    pending.value = List.unmodifiable(
      pending.value.where((r) => r.id != report.id),
    );
    await _save();
    try {
      final f = File(report.photoPath);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // A stray file in the app's own directory is harmless.
    }
    _schedule();
  }

  /// Try to send everything queued. Returns how many reports got through.
  Future<int> flush() async {
    await load();
    if (_flushing || pending.value.isEmpty) return 0;
    _flushing = true;
    var sent = 0;
    try {
      for (final report in List.of(pending.value)) {
        final outcome = await _deliver(report);
        if (outcome == _Outcome.unreachable) {
          offline.value = true;
          break;
        }
        offline.value = false;
        if (outcome == _Outcome.sent) {
          sent++;
          await _remove(report);
          _delivered.add(report);
          SoundCues.instance.playReportSent();
        } else if (outcome == _Outcome.refused) {
          await _remove(report);
        }
        // _Outcome.later: signed out or a server error — keep it and move on.
      }
    } finally {
      _flushing = false;
    }
    return sent;
  }

  Future<_Outcome> _deliver(QueuedReport report) async {
    try {
      if (await _alreadyLanded(report)) return _Outcome.sent;
      final bytes = await File(report.photoPath).readAsBytes();
      await _api.submitReport(
        lat: report.lat,
        lng: report.lng,
        accuracyM: report.accuracyM,
        agencies: report.agencies,
        notes: report.notes,
        photoBytes: bytes,
      );
      return _Outcome.sent;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode >= 500) return _Outcome.later;
      lastRejection.value = e.message;
      return _Outcome.refused;
    } on FileSystemException {
      // The photo is gone; the server will not take a report without one.
      lastRejection.value = 'A queued report lost its photo and was dropped.';
      return _Outcome.refused;
    } catch (_) {
      return _Outcome.unreachable;
    }
  }

  /// Whether an earlier attempt reached the server even though its reply
  /// never came back. Coordinates are compared exactly: they travel as the
  /// same double both times, so a match is this report and not a neighbour's.
  Future<bool> _alreadyLanded(QueuedReport report) async {
    final mine = await _api.getMyReports();
    final since = report.queuedAt.subtract(const Duration(minutes: 2));
    for (final raw in mine.cast<Map<String, dynamic>>()) {
      final lat = (raw['device_lat'] as num?)?.toDouble();
      final lng = (raw['device_lng'] as num?)?.toDouble();
      final created = DateTime.tryParse('${raw['created_at']}');
      if (lat == null || lng == null || created == null) continue;
      if (lat == report.lat && lng == report.lng && created.isAfter(since)) {
        return true;
      }
    }
    return false;
  }
}

enum _Outcome { sent, refused, later, unreachable }
