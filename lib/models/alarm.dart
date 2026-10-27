import 'area_view.dart';

/// The BFP alarm ladder, lowest first: the server's `alarm_level` enum
/// (app/schemas/alarm.py). Fire Volunteers ask for a level; only BFP sets it
/// (PRD v14 §3.4, §4.7).
const List<String> kAlarmLadder = [
  'positive_fire_alarm',
  'first_alarm',
  'second_alarm',
  'third_alarm',
  'fourth_alarm',
  'fifth_alarm',
  'general_alarm',
];

/// "1st alarm" — the alarm level in the words the BFP uses.
String alarmWord(String? level) => switch (level) {
  'positive_fire_alarm' => 'Positive fire alarm',
  'first_alarm' => '1st alarm',
  'second_alarm' => '2nd alarm',
  'third_alarm' => '3rd alarm',
  'fourth_alarm' => '4th alarm',
  'fifth_alarm' => '5th alarm',
  'general_alarm' => 'General alarm',
  _ => 'None yet',
};

/// Where [level] sits on the ladder; no level yet is below every one.
int alarmRank(String? level) =>
    level == null ? -1 : kAlarmLadder.indexOf(level);

/// The levels that would raise an Area now at [current]: the only ones the
/// server accepts a request for.
List<String> levelsAbove(String? current) =>
    kAlarmLadder.sublist(alarmRank(current) + 1);

/// One alarm escalation request, as GET /alarm-requests returns it.
class AlarmRequest {
  AlarmRequest(this.raw);

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  String get areaId => raw['area_id'] as String;

  /// "Area 1.2".
  String get areaName {
    final d = ((raw['area_designation'] as String?) ?? '').trim();
    if (d.isEmpty) return 'The Area';
    return d.toLowerCase().startsWith('area') ? d : 'Area $d';
  }

  String? get areaStatus => raw['area_status'] as String?;
  String? get areaLevel => raw['area_alarm_level'] as String?;

  /// The Area as the request carries it (where, how far along, its level
  /// now), for the widgets that show an Area.
  AreaView get area => AreaView({
    'id': areaId,
    'designation': raw['area_designation'],
    'status': areaStatus,
    'alarm_level': areaLevel,
    'centroid_lat': raw['area_centroid_lat'],
    'centroid_lng': raw['area_centroid_lng'],
  });

  String get level => raw['requested_alarm_level'] as String;
  String? get justification {
    final j = (raw['justification'] as String?)?.trim();
    return j == null || j.isEmpty ? null : j;
  }

  /// pending, approved, rejected or cancelled.
  String get status => (raw['status'] as String?) ?? 'pending';
  bool get waiting => status == 'pending';

  String get askedBy =>
      (raw['requested_by_name'] as String?) ?? 'A coordinator';
  String? get organisation => raw['requested_by_organization_name'] as String?;
  String? get answeredBy => raw['reviewed_by_name'] as String?;
  String? get notes {
    final n = (raw['review_notes'] as String?)?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  DateTime? get askedAt => parseTime(raw['created_at']);
  DateTime? get answeredAt => parseTime(raw['reviewed_at']);

  /// The request still raises the Area: its level is above the Area's now.
  bool get stillRaises => alarmRank(level) > alarmRank(areaLevel);
}

/// A request's status in a word: Waiting, Set, Declined, Cancelled.
String alarmRequestWord(String status) => switch (status) {
  'approved' => 'Set',
  'rejected' => 'Declined',
  'cancelled' => 'Cancelled',
  _ => 'Waiting',
};
