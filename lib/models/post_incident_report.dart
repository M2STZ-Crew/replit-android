/// Post-Incident Report (Master Context v10 §2.5).
///
/// Filed once, after fire out, by the responding team captain for everyone who
/// went: when it happened and when the fire was out, the units, the driver,
/// the roster and what came off the trucks.
///
/// Every answer is picked, none typed. The form offers the organisation's own
/// units, members and equipment, and starts from what the system already
/// knows — the times it recorded and the responders who joined — so the
/// captain confirms and corrects rather than writes.
library;

import 'fleet_unit.dart';

/// Someone in the captain's organisation, offered as driver and for the
/// roster. From GET /organizations/mine/members.
class OrgMember {
  const OrgMember({required this.id, required this.name, this.role});

  final String id;
  final String name;

  /// 'sub_admin' (a captain) or 'response_team'.
  final String? role;

  factory OrgMember.fromJson(Map<String, dynamic> json) => OrgMember(
    id: json['id'] as String,
    name: ((json['full_name'] as String?) ?? '').trim().isEmpty
        ? 'Member'
        : (json['full_name'] as String).trim(),
    role: json['role'] as String?,
  );
}

/// One unit that went. [equipmentId] links the registered unit when it is one.
class ReportUnit {
  const ReportUnit({required this.name, this.type, this.equipmentId});

  factory ReportUnit.fromFleet(FleetUnit unit) =>
      ReportUnit(name: unit.name, type: unit.type, equipmentId: unit.id);

  final String name;
  final String? type;
  final String? equipmentId;

  /// What tells two choices apart: the registered unit, or else its name.
  String get key => equipmentId ?? name.toLowerCase();

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': ?type,
    'equipment_id': ?equipmentId,
  };
}

/// Offered when an organisation has no units in its register, so its captain
/// can still say what kind of unit went without typing one.
const List<ReportUnit> kGenericUnits = [
  ReportUnit(name: 'Fire truck', type: 'Fire Truck'),
  ReportUnit(name: 'Water tanker', type: 'Water Tanker'),
  ReportUnit(name: 'Rescue vehicle', type: 'Rescue Vehicle'),
  ReportUnit(name: 'Ambulance', type: 'Ambulance'),
  ReportUnit(name: 'Command vehicle', type: 'Command Vehicle'),
];

/// Things commonly taken off a unit. Shown alongside whatever equipment the
/// organisation has registered.
const List<String> kCommonEquipment = [
  'Hose line',
  'Nozzle',
  'SCBA',
  'Fire extinguisher',
  'Ladder',
  'Axe / Halligan',
  'First aid kit',
  'Hydrant key',
];

/// v11 §2.5.3: a false alarm must say what the team found. These are the
/// cases the spec names, to pick from; the one chosen is sent as the note.
const List<String> kFalseAlarmReasons = [
  'Prank call',
  'Fire was already out',
  'Wrong address',
  'Nothing found at the scene',
];

class RosterMember {
  const RosterMember({required this.name, this.role, this.userId});

  final String name;

  /// No longer asked for; kept so a report filed with one still reads back.
  final String? role;
  final String? userId;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (role != null && role!.trim().isNotEmpty) 'role': role!.trim(),
    'user_id': ?userId,
  };
}

/// What the dispatch log can tell the form before the captain picks anything.
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
  factory PostIncidentPrefill.fromDispatches(
    List<Map<String, dynamic>> dispatches,
  ) {
    final went = dispatches.where((d) => d['status'] != 'withdrawn').toList()
      ..sort(
        (a, b) => ((a['dispatched_at'] as String?) ?? '').compareTo(
          (b['dispatched_at'] as String?) ?? '',
        ),
      );

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
      if (((d['crew_role'] as String?) ?? '').toLowerCase().contains(
        'driver',
      )) {
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
      roster.add(
        RosterMember(name: name, role: d['crew_role'] as String?, userId: id),
      );
    }

    return PostIncidentPrefill(
      truckLabel: truck,
      driverName: (driver?['responder_name'] as String?)?.trim(),
      driverUserId: driver?['responder_id'] as String?,
      roster: roster,
    );
  }
}

/// What is still unpicked, in the order the form asks for it. The server
/// refuses a report with any of it missing (there is no draft state), so the
/// form will not submit until this is empty.
List<String> missingPostIncidentFields({
  required int units,
  required bool hasDriver,
  required int roster,
  required int equipment,
  DateTime? incidentAt,
  DateTime? fireOutAt,
  bool falseAlarm = false,
  String? falseAlarmReason,
}) => [
  if (incidentAt != null && fireOutAt != null && fireOutAt.isBefore(incidentAt))
    'a fire-out time after the incident',
  if (units == 0) 'unit',
  if (!hasDriver) 'driver',
  if (roster == 0) 'roster',
  if (equipment == 0) 'equipment taken',
  // v11 §2.5.3: mirrors the server's check, so the captain is told here rather
  // than after a refused submit.
  if (falseAlarm && (falseAlarmReason ?? '').trim().isEmpty)
    'what the team found',
];
