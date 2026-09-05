import 'dart:math' as math;

/// What the citizen map draws. Three kinds of thing, one shape each.

/// A live incident cluster — public.areas, via GET /areas.
///
/// Every signed-in user may read this list; the staff-only GET /incidents adds
/// dispatch counts and agency scoping, which a citizen has no business seeing.
class MapIncident {
  const MapIncident({
    required this.id,
    required this.designation,
    required this.status,
    required this.lat,
    required this.lng,
    required this.reportCount,
    required this.confidenceScore,
    required this.confidenceBand,
    required this.reportedAt,
    this.alarmLevel,
  });

  final String id;
  final String designation;
  final String status;
  final double lat;
  final double lng;
  final int reportCount;
  final double confidenceScore;
  final String confidenceBand;
  final DateTime reportedAt;
  final String? alarmLevel;

  factory MapIncident.fromMap(Map<String, dynamic> m) => MapIncident(
    id: m['id'] as String,
    designation: m['designation'] as String? ?? 'Incident',
    status: m['status'] as String? ?? 'pending',
    lat: (m['centroid_lat'] as num).toDouble(),
    lng: (m['centroid_lng'] as num).toDouble(),
    reportCount: (m['report_count'] as num?)?.toInt() ?? 0,
    confidenceScore: (m['confidence_score'] as num?)?.toDouble() ?? 0,
    confidenceBand: m['confidence_band'] as String? ?? 'low',
    reportedAt:
        DateTime.tryParse(m['reported_at'] as String? ?? '') ?? DateTime.now(),
    alarmLevel: m['alarm_level'] as String?,
  );
}

/// A place on one of the operational layers — shelter, hydrant, hospital.
class MapPlace {
  const MapPlace({
    required this.id,
    required this.kind,
    required this.name,
    required this.lat,
    required this.lng,
    this.detail,
    this.ok = true,
  });

  final String id;
  final MapLayer kind;
  final String name;
  final double lat;
  final double lng;

  /// Second line — capacity, address, hydrant condition.
  final String? detail;

  /// False for a hydrant that is out of service, which is worth showing
  /// differently: a broken hydrant is worse than no hydrant on the map.
  final bool ok;
}

enum MapLayer {
  incidents('Incidents'),
  shelters('Shelters'),
  hydrants('Hydrants'),
  risks('Risk areas');

  const MapLayer(this.label);
  final String label;
}

/// Great-circle distance in metres. Used for "400 m away" and for ordering the
/// nearby sheet — both are computed on the phone, because no endpoint takes a
/// radius.
double metresBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}
