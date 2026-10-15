import 'package:latlong2/latlong.dart';

/// One incident Area as the coordinator screens read it, from a GET
/// /incidents row (IncidentSummary) or GET /incidents/{id} (IncidentDetail).
class AreaView {
  AreaView(this.raw);

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;

  /// "1.2" — the server's designation, which is the Area and its version.
  String get designation => (raw['designation'] as String?) ?? '';

  /// "Area 1.2". Older rows already carry the word.
  String get name => designation.toLowerCase().startsWith('area')
      ? designation
      : 'Area $designation';

  String get status => (raw['status'] as String?) ?? 'reported';

  LatLng? get centre {
    final lat = (raw['centroid_lat'] as num?)?.toDouble();
    final lng = (raw['centroid_lng'] as num?)?.toDouble();
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  int get reports => (raw['report_count'] as num?)?.toInt() ?? 0;

  double get score => (raw['confidence_score'] as num?)?.toDouble() ?? 0;

  /// low / medium / high, or null.
  String? get band => raw['confidence_band'] as String?;

  /// "Medium" — the band in words.
  String get bandWord {
    final b = band;
    if (b == null || b.isEmpty) return 'Unscored';
    return '${b[0].toUpperCase()}${b.substring(1)}';
  }

  /// "Medium 0.46".
  String get confidence => '$bandWord ${score.toStringAsFixed(2)}';

  int get respondingCount =>
      (raw['active_dispatch_count'] as num?)?.toInt() ?? 0;

  String? get alarmLevel => raw['alarm_level'] as String?;

  DateTime? at(String key) => parseTime(raw[key]);

  DateTime? get reportedAt => at('reported_at');

  List<String> _agencies(String key) =>
      ((raw[key] as List?) ?? const []).whereType<String>().toList();

  /// Agencies the reporters asked for.
  List<String> get requested => _agencies('requested_agencies');

  /// Agencies that have accepted (verified) it.
  List<String> get accepted => _agencies('accepted_agencies');

  /// Waiting on a decision: nobody has accepted it yet.
  bool get toDecide => status == 'reported';

  /// Under way: accepted, or crews on the way or on scene.
  bool get active => const {'verified', 'en_route', 'arrived'}.contains(status);

  /// The fire is out and the Post-Incident Report is owed.
  bool get toFile =>
      const {'fire_out', 'post_incident_report'}.contains(status);

  /// On the ground: someone is on the way or there.
  bool get live => const {'en_route', 'arrived'}.contains(status);
}

DateTime? parseTime(Object? iso) =>
    iso is String ? DateTime.tryParse(iso)?.toLocal() : null;

/// "Fire Volunteer", "BFP", "Medical"…
String agencyWord(String agency) => switch (agency) {
  'fire_volunteer' => 'Fire Volunteer',
  'bfp' => 'BFP',
  'medical' => 'Medical',
  'police' => 'Police',
  'barangay' => 'Barangay',
  _ => agency,
};

/// "Fire, Medical" — what a reporter asked for, with the two fire agencies
/// said once as "Fire".
String askedFor(Iterable<String> agencies) {
  final words = <String>{
    for (final a in agencies)
      a == 'fire_volunteer' || a == 'bfp' ? 'Fire' : agencyWord(a),
  };
  return words.join(', ');
}

/// "Fire Volunteer and Medical".
String andList(List<String> words) => switch (words.length) {
  0 => '',
  1 => words.single,
  _ => '${words.sublist(0, words.length - 1).join(', ')} and ${words.last}',
};

/// "just now", "2 min ago", "3 h ago", "yesterday", "14 Sep".
String agoText(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inHours < 48) return 'yesterday';
  return dayText(t);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "14 Sep".
String dayText(DateTime t) => '${t.day} ${_months[t.month - 1]}';

/// "9:41 PM".
String clockText(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "today 9:41 PM", "yesterday 5:40 PM", "14 Sep".
String whenText(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'today ${clockText(t)}';
  if (days == 1) return 'yesterday ${clockText(t)}';
  return dayText(t);
}
