import 'alarm.dart';

/// Where a fire stands besides its alarm level.
enum FireSituation { burning, underControl, fireOut }

/// A fire's alarm status as every screen shows it (v1.12.60, backend
/// v1.12.49; 22 Nov 2026: "fire alarm status can be seen in any details
/// info. because it is essential to be seen by anyone"; answered "Level +
/// situation"): BFP's level, and Under control or Fire out once there is one.
///
/// Read from any payload that carries it: an incident (staff), an area
/// (anyone), a Track it live snapshot or one of /reports/mine's rows
/// (`area_*`). An older server sends only the level.
class AlarmStatus {
  const AlarmStatus({
    required this.status,
    this.level,
    this.setAt,
    this.setByOrg,
    this.setByName,
    this.underControlAt,
    this.underControlByOrg,
    this.underControlByName,
    this.fireOutAt,
  });

  factory AlarmStatus.of(Map<String, dynamic>? raw) {
    final r = raw ?? const <String, dynamic>{};
    String? text(String key) {
      final value = r[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    DateTime? time(String key) {
      final value = text(key);
      return value == null ? null : DateTime.tryParse(value)?.toLocal();
    }

    // A report's row names the incident's fields area_*; its own `status`
    // would not be the fire's.
    return AlarmStatus(
      status: text('area_status') ?? text('status') ?? 'reported',
      level: text('area_alarm_level') ?? text('alarm_level'),
      setAt: time('alarm_level_set_at'),
      setByOrg: text('alarm_level_set_by_org'),
      setByName: text('alarm_level_set_by_name'),
      underControlAt: time('area_under_control_at') ?? time('under_control_at'),
      underControlByOrg: text('under_control_by_org'),
      underControlByName: text('under_control_by_name'),
      fireOutAt: time('resolved_at'),
    );
  }

  final String status;
  final String? level;
  final DateTime? setAt;
  final String? setByOrg;

  /// Staff only: the server never sends residents a name.
  final String? setByName;

  /// When it was declared under control; null once a raise cleared it.
  final DateTime? underControlAt;
  final String? underControlByOrg;
  final String? underControlByName;
  final DateTime? fireOutAt;

  static const Set<String> _out = {
    'fire_out',
    'post_incident_report',
    'closed',
  };
  static const Set<String> _notAFire = {'rejected', 'declined', 'merged'};

  FireSituation get situation {
    if (_out.contains(status)) return FireSituation.fireOut;
    if (underControlAt != null) return FireSituation.underControl;
    return FireSituation.burning;
  }

  /// Rejected and merged incidents have no alarm status to show.
  bool get applies => !_notAFire.contains(status);

  /// There is a level or a situation: lists and maps draw a badge for it.
  bool get known =>
      applies && (level != null || situation != FireSituation.burning);

  /// BFP has raised it past Positive fire alarm: the solid red one.
  bool get raised =>
      situation == FireSituation.burning &&
      alarmRank(level) > alarmRank(kInitialAlarmLevel);

  /// General alarm, the top of the ladder.
  bool get highest => level == kAlarmLadder.last;

  AlarmStatus withLive({
    required String status,
    String? level,
    DateTime? setAt,
    DateTime? underControlAt,
  }) {
    final same = level == this.level;
    return AlarmStatus(
      status: status,
      level: level,
      setAt: setAt,
      // Who, from the slower read, while it is still about this level.
      setByOrg: same ? setByOrg : null,
      setByName: same ? setByName : null,
      underControlAt: underControlAt,
      underControlByOrg: underControlAt == null ? null : underControlByOrg,
      underControlByName: underControlAt == null ? null : underControlByName,
      fireOutAt: fireOutAt,
    );
  }
}
