import 'package:latlong2/latlong.dart';

/// One responding unit as a resident sees it: a truck, or a responder
/// travelling without one. Never a person — the server sends a label ("Apollo",
/// "Unit 2") and a brigade, not who is holding the phone.
class TrackedUnit {
  const TrackedUnit({
    required this.key,
    required this.label,
    required this.stale,
    this.organization,
    this.agency,
    this.position,
    this.headingDeg,
    this.updatedAt,
    this.ageAtSnapshot,
  });

  factory TrackedUnit.fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    return TrackedUnit(
      key: '${j['key']}',
      label: (j['label'] as String?) ?? 'Responder',
      organization: j['organization'] as String?,
      agency: j['agency'] as String?,
      position: lat == null || lng == null ? null : LatLng(lat, lng),
      headingDeg: (j['heading_deg'] as num?)?.toDouble(),
      updatedAt: DateTime.tryParse('${j['updated_at']}'),
      stale: j['stale'] == true,
    );
  }

  final String key;
  final String label;
  final String? organization;
  final String? agency;

  /// Last known position; null until the unit's phone has sent one.
  final LatLng? position;
  final double? headingDeg;

  /// When the server received the unit's last fix (server clock).
  final DateTime? updatedAt;

  /// How old that fix was when the snapshot was made, by the server's own
  /// clock — so the age shown never depends on this phone's clock being right.
  final Duration? ageAtSnapshot;

  /// The server's verdict at snapshot time. See [TrackingSnapshot.isStale] for
  /// the one that keeps counting after the snapshot arrived.
  final bool stale;

  TrackedUnit _aged(DateTime generatedAt) => TrackedUnit(
    key: key,
    label: label,
    organization: organization,
    agency: agency,
    position: position,
    headingDeg: headingDeg,
    updatedAt: updatedAt,
    stale: stale,
    ageAtSnapshot: updatedAt == null
        ? null
        : generatedAt.difference(updatedAt!),
  );
}

/// Everything Track It Live draws, as GET /areas/{id}/tracking and the
/// `track:<id>` socket channel send it. Each snapshot replaces the last.
class TrackingSnapshot {
  const TrackingSnapshot({
    required this.areaId,
    required this.designation,
    required this.status,
    required this.centre,
    required this.arrivalRadiusMetres,
    required this.staleAfter,
    required this.units,
    required this.receivedAt,
  });

  /// Null for anything that is not a snapshot, rather than a crash: an older
  /// server, or a proxy's error page, must not take the screen down.
  static TrackingSnapshot? tryParse(Object? json, {DateTime? receivedAt}) {
    if (json is! Map<String, dynamic>) return null;
    final lat = (json['centroid_lat'] as num?)?.toDouble();
    final lng = (json['centroid_lng'] as num?)?.toDouble();
    final status = json['status'];
    final units = json['responders'];
    if (lat == null || lng == null || status is! String || units is! List) {
      return null;
    }
    final generated =
        DateTime.tryParse('${json['generated_at']}') ?? DateTime.now().toUtc();
    return TrackingSnapshot(
      areaId: '${json['area_id']}',
      designation: (json['designation'] as String?) ?? '',
      status: status,
      centre: LatLng(lat, lng),
      arrivalRadiusMetres:
          (json['arrival_radius_m'] as num?)?.toDouble() ?? 100,
      staleAfter: Duration(
        seconds: (json['stale_after_seconds'] as num?)?.toInt() ?? 60,
      ),
      units: [
        for (final u in units)
          if (u is Map<String, dynamic>)
            TrackedUnit.fromJson(u)._aged(generated),
      ],
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  final String areaId;
  final String designation;
  final String status;

  /// The incident: the centre of its reports.
  final LatLng centre;

  /// How close a unit must be to count as on scene.
  final double arrivalRadiusMetres;
  final Duration staleAfter;
  final List<TrackedUnit> units;

  /// When this phone received the snapshot (this phone's clock).
  final DateTime receivedAt;

  /// How old [unit]'s position is now: its age when the snapshot was made,
  /// plus the time since the snapshot arrived.
  Duration? ageOf(TrackedUnit unit, {DateTime? now}) {
    final atSnapshot = unit.ageAtSnapshot;
    if (atSnapshot == null) return null;
    final since = (now ?? DateTime.now()).difference(receivedAt);
    return atSnapshot + (since.isNegative ? Duration.zero : since);
  }

  /// No recent position from [unit] — its phone lost signal, or has sent none.
  ///
  /// Counts on after the snapshot arrived: when a phone goes quiet no new
  /// snapshot comes to say so, so the last one must age on its own.
  bool isStale(TrackedUnit unit, {DateTime? now}) {
    if (unit.stale || unit.position == null) return true;
    final age = ageOf(unit, now: now);
    return age == null || age > staleAfter;
  }
}
