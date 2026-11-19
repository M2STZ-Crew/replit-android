import '../i18n/i18n.dart';
import '../models/area_view.dart';
import 'api_client.dart';

/// Whether this resident may send reports, after prank reports (v1.12.52,
/// backend v1.12.41: GET /report-strikes/me).
///
/// 19 Nov 2026: "a false alarm or prank report can be temporarily cannot
/// report and has a progressive penalty". Staff mark a report "Prank or
/// malicious" — never an honest mistake — and each strike pauses reporting for
/// longer, counted over 12 months: 24 hours, 7 days, 30 days, then no reporting
/// until an appeal is granted. Calling 911 and fire alerts are never blocked.
///
/// The last answer is kept ([cached]) so the report button stays instant:
/// the camera opens at once unless the phone already knows reporting is
/// paused, and the server refuses a paused report anyway ([errorCode]).
class ReportingStanding {
  ReportingStanding({
    required this.canReport,
    required this.removed,
    required this.step,
    this.pausedUntil,
    this.verifyFirstUntil,
    this.lessonDue,
    this.strikes = const [],
  });

  factory ReportingStanding.fromJson(Map<String, dynamic> json) =>
      ReportingStanding(
        canReport: json['can_report'] != false,
        removed: json['removed'] == true,
        step: (json['step'] as num?)?.toInt() ?? 0,
        pausedUntil: parseTime(json['paused_until']),
        verifyFirstUntil: parseTime(json['verify_first_until']),
        lessonDue: json['lesson_due'] as String?,
        strikes: [
          for (final s in (json['strikes'] as List?) ?? const [])
            if (s is Map<String, dynamic>) StrikeView.fromJson(s),
        ],
      );

  /// The server's refusal of a report while paused or removed.
  static const String errorCode = 'reporting_paused';

  final bool canReport;

  /// The 4th step: no reports until an appeal is granted.
  final bool removed;

  /// The highest step in effect; 0 for none.
  final int step;
  final DateTime? pausedUntil;

  /// Until then, their report waits for staff before neighbours are alerted.
  final DateTime? verifyFirstUntil;

  /// A strike whose lesson the app shows once.
  final String? lessonDue;
  final List<StrikeView> strikes;

  /// Whether reporting is blocked right now, by what is known on the phone.
  bool get blocksNow {
    if (canReport) return false;
    if (removed) return true;
    final until = pausedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  /// The newest strike, the one the screen talks about.
  StrikeView? get latest => strikes.isEmpty ? null : strikes.first;

  static ReportingStanding? _cached;

  /// The last answer this phone had, if any.
  static ReportingStanding? get cached => _cached;

  /// Ask the server again. On no answer, what was known stays.
  static Future<ReportingStanding?> refresh(ApiClient api) async {
    try {
      _cached = ReportingStanding.fromJson(await api.getReportingStanding());
    } catch (_) {
      // Offline, or an older server: keep what is known. The server still
      // refuses a paused report when it arrives.
    }
    return _cached;
  }

  /// Forget the answer (signing out).
  static void clear() => _cached = null;

  /// Set from a refusal the server just sent, so the next tap knows.
  static void noteRefusal(Map<String, dynamic>? details) {
    _cached = ReportingStanding(
      canReport: false,
      removed: details?['removed'] == true,
      step: (details?['step'] as num?)?.toInt() ?? 0,
      pausedUntil: parseTime(details?['paused_until']),
      strikes: _cached?.strikes ?? const [],
    );
  }

  /// The refusal in the app's own words, for wherever it surfaces.
  static String refusal(Map<String, dynamic>? details) {
    if (details?['removed'] == true) {
      return t(
        'You can no longer send reports after repeated prank reports. In an '
        'emergency, call 911.',
      );
    }
    final until = parseTime(details?['paused_until']);
    if (until == null) {
      return t('Your reporting is paused. In an emergency, call 911.');
    }
    return t('You can send reports again on {when}. In an emergency, call 911.', {
      'when': untilText(until),
    });
  }
}

/// "20 Nov, 2:00 PM".
String untilText(DateTime at) => '${dayText(at)}, ${clockText(at)}';

/// One strike, as its resident sees it: never who gave it.
class StrikeView {
  StrikeView({
    required this.id,
    required this.step,
    required this.status,
    required this.reason,
    required this.givenAt,
    required this.canAppeal,
    required this.appealState,
    required this.lessonSeen,
    this.pauseEndsAt,
    this.expiresAt,
    this.appealText,
    this.appealNote,
  });

  factory StrikeView.fromJson(Map<String, dynamic> json) => StrikeView(
    id: json['id'] as String? ?? '',
    step: (json['step'] as num?)?.toInt() ?? 1,
    status: json['status'] as String? ?? 'active',
    reason: json['reason'] as String? ?? '',
    givenAt: parseTime(json['given_at']) ?? DateTime.now(),
    canAppeal: json['can_appeal'] == true,
    appealState: json['appeal_state'] as String? ?? 'none',
    lessonSeen: json['lesson_seen'] == true,
    pauseEndsAt: parseTime(json['pause_ends_at']),
    expiresAt: parseTime(json['expires_at']),
    appealText: json['appeal_text'] as String?,
    appealNote: json['appeal_note'] as String?,
  );

  final String id;
  final int step;

  /// awaiting_confirmation | active | overturned.
  final String status;
  final String reason;
  final DateTime givenAt;
  final bool canAppeal;

  /// none | pending | upheld | overturned.
  final String appealState;
  final bool lessonSeen;
  final DateTime? pauseEndsAt;
  final DateTime? expiresAt;
  final String? appealText;
  final String? appealNote;

  bool get removed => status == 'overturned';
  bool get awaitingCheck => status == 'awaiting_confirmation';
}

/// What each step does, in the app's words.
String strikeStepText(int step) => switch (step) {
  1 => t('1st strike: reporting paused for 24 hours'),
  2 => t('2nd strike: paused for 7 days, then 30 days of staff checks'),
  3 => t('3rd strike: paused for 30 days, then 90 days of staff checks'),
  _ => t('4th strike: no reporting until an appeal is granted'),
};
