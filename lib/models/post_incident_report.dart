/// Post-Incident Report (Master Context v10 §2.5).
///
/// Filed once, after fire out, by the responding team captain for everyone who
/// went: the unit, its driver, the roster and what came off the truck. During
/// the response the dispatch flow already recorded which truck each responder
/// crewed and in what role, so the form starts from that rather than from
/// nothing — the captain confirms and corrects instead of re-typing.
library;

class RosterMember {
  const RosterMember({required this.name, this.role, this.userId});

  final String name;
  final String? role;
  final String? userId;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (role != null && role!.trim().isNotEmpty) 'role': role!.trim(),
    'user_id': ?userId,
  };
}

/// What the dispatch log can tell the form before the captain types anything.
class PostIncidentPrefill {
  const PostIncidentPrefill({
    this.truckLabel,
    this.driverName,
    this.driverUserId,
    this.roster = const [],
  });

  final String? truckLabel;
  final String? driverName;
  final String? driverUserId;
  final List<RosterMember> roster;

  /// From GET /incidents/{id}/dispatches. Withdrawn dispatches are left out —
  /// those responders did not go. The truck is the one most responders crewed;
  /// the driver is whoever was dispatched in a driver role.
  factory PostIncidentPrefill.fromDispatches(List<Map<String, dynamic>> dispatches) {
    final went = dispatches.where((d) => d['status'] != 'withdrawn').toList()
      ..sort((a, b) => ((a['dispatched_at'] as String?) ?? '')
          .compareTo((b['dispatched_at'] as String?) ?? ''));

    final trucks = <String, int>{};
    for (final d in went) {
      final v = (d['vehicle_name'] as String?)?.trim();
      if (v != null && v.isNotEmpty) trucks[v] = (trucks[v] ?? 0) + 1;
    }
    String? truck;
    for (final e in trucks.entries) {
      if (truck == null || e.value > trucks[truck]!) truck = e.key;
    }

    Map<String, dynamic>? driver;
    for (final d in went) {
      if (((d['crew_role'] as String?) ?? '').toLowerCase().contains('driver')) {
        driver = d;
        break;
      }
    }

    final seen = <String>{};
    final roster = <RosterMember>[];
    for (final d in went) {
      final id = d['responder_id'] as String?;
      final name = ((d['responder_name'] as String?) ?? '').trim();
      if (name.isEmpty || (id != null && !seen.add(id))) continue;
      roster.add(RosterMember(name: name, role: d['crew_role'] as String?, userId: id));
    }

    return PostIncidentPrefill(
      truckLabel: truck,
      driverName: (driver?['responder_name'] as String?)?.trim(),
      driverUserId: driver?['responder_id'] as String?,
      roster: roster,
    );
  }
}

/// The fields still empty, in the order the form asks for them. The server
/// refuses a report with any of them missing (there is no draft state), so the
/// form will not submit until this is empty.
List<String> missingPostIncidentFields({
  required String truckLabel,
  required String truckType,
  required String driverName,
  required List<RosterMember> roster,
  required List<String> equipment,
}) => [
  if (truckLabel.trim().isEmpty) 'unit',
  if (truckType.trim().isEmpty) 'unit type',
  if (driverName.trim().isEmpty) 'driver',
  if (roster.isEmpty) 'roster',
  if (equipment.isEmpty) 'equipment taken',
];
