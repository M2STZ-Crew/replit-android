/// A fire-fighting unit (truck) in an organization's fleet.
///
/// STATIC demo data for now ([kDemoFleet]): the backend `equipment` table has no
/// capacity/liters column and dispatch is responder-user-based (dispatch_logs
/// keyed on responder_id, not trucks), so the fleet is hardcoded for the
/// dispatch UI. Swap [kDemoFleet] for GET /equipment once an equipment↔incident
/// dispatch link exists (map status in_use → onCall, available → available).
enum FleetStatus { available, onCall }

class FleetUnit {
  const FleetUnit({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.capacityLiters,
  });

  final String id;
  final String name; // 'Apollo'
  final String type; // 'Fire Truck'
  final int? capacityLiters; // 4000
  final FleetStatus status;

  /// Build from a GET /equipment row. status 'available' → available, anything
  /// else (in_use/maintenance/out_of_service) → onCall (not dispatchable).
  factory FleetUnit.fromEquipment(Map<String, dynamic> e) {
    final category = e['category'] as String?;
    final description = (e['description'] as String?)?.trim();
    final type = category == 'fire_truck'
        ? 'Fire Truck'
        : (description != null && description.isNotEmpty ? description : (category ?? 'Unit'));
    return FleetUnit(
      id: e['id'] as String,
      name: (e['name'] as String?) ?? 'Unit',
      type: type,
      capacityLiters: (e['capacity_liters'] as num?)?.toInt(),
      status: (e['status'] as String?) == 'available'
          ? FleetStatus.available
          : FleetStatus.onCall,
    );
  }

  bool get isAvailable => status == FleetStatus.available;

  /// e.g. 'Fire Truck · 4,000 L'
  String get subtitle =>
      capacityLiters == null ? type : '$type · ${_grouped(capacityLiters!)} L';

  static String _grouped(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Demo fleet matching the Figma (Apollo/Achilles available, Hermes on call).
const List<FleetUnit> kDemoFleet = [
  FleetUnit(
    id: 'apollo',
    name: 'Apollo',
    type: 'Fire Truck',
    capacityLiters: 4000,
    status: FleetStatus.available,
  ),
  FleetUnit(
    id: 'achilles',
    name: 'Achilles',
    type: 'Fire Truck',
    capacityLiters: 3500,
    status: FleetStatus.available,
  ),
  FleetUnit(
    id: 'hermes',
    name: 'Hermes',
    type: 'Fire Truck',
    capacityLiters: 4000,
    status: FleetStatus.onCall,
  ),
];
