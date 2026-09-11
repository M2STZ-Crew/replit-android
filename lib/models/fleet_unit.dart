/// A fire-fighting unit (truck) in an organization's fleet, built from a
/// GET /equipment row with category 'fire_truck'.
///
/// Dispatch is responder-based (dispatch_logs keys on responder_id), so a unit
/// is a label on a dispatch and on the Post-Incident Report rather than a thing
/// dispatched in its own right. Status maps in_use/maintenance → onCall.
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
