import 'package:latlong2/latlong.dart';

import '../i18n/i18n.dart';
import '../widgets/map_marker.dart';

/// Water sources on a staff map (v1.12.55, backend v1.12.43): a hydrant, a
/// body of water or an underground cistern, as GET /map/... sends it.
///
/// 19 Nov 2026: Fire Volunteer and BFP coordinators and responders set a
/// hydrant's status after checking it, and it is on every map at once;
/// coordinators add, change and switch off sources for an Admin to approve;
/// every staff member gets directions to any of them. Residents see where
/// water is, never its status: the server sends them none.
enum WaterKind {
  hydrant('hydrants', 'hydrant', MapMarkerKind.hydrant),
  water('water', 'bodies_of_water', MapMarkerKind.water),
  cistern('cisterns', 'underground_cistern', MapMarkerKind.cistern);

  const WaterKind(this.layerKey, this.layerType, this.marker);

  /// The staff map's layer key (widgets/ops_layers.dart).
  final String layerKey;

  /// The server's map_layer_type, for a proposed change.
  final String layerType;

  final MapMarkerKind marker;

  /// The kind a staff map layer holds; null for a layer that is not water.
  static WaterKind? ofLayer(String key) {
    for (final kind in values) {
      if (kind.layerKey == key) return kind;
    }
    return null;
  }

  String get noun => switch (this) {
    hydrant => t('Fire hydrant'),
    water => t('Body of water'),
    cistern => t('Underground cistern'),
  };
}

/// A hydrant's or cistern's status, in the words of 19 Nov 2026: working,
/// low pressure, broken, no access.
enum WaterStatus {
  operational('operational'),
  lowPressure('low_pressure'),
  nonOperational('non_operational'),
  noAccess('no_access'),
  underMaintenance('under_maintenance'),
  unknown('unknown');

  const WaterStatus(this.wire);

  /// The server's hydrant_status.
  final String wire;

  /// What someone can say after checking one: every status but Not checked.
  static const reportable = [
    operational,
    lowPressure,
    nonOperational,
    noAccess,
    underMaintenance,
  ];

  static WaterStatus parse(Object? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return unknown;
  }

  String get word => switch (this) {
    operational => t('Working'),
    lowPressure => t('Low pressure'),
    nonOperational => t('Broken'),
    noAccess => t('No access'),
    underMaintenance => t('Under maintenance'),
    unknown => t('Not checked'),
  };

  /// Whether a crew can count on it: only Working.
  bool get usable => this == operational;
}

/// One water source, with its record as the server sent it.
class WaterSource {
  const WaterSource({
    required this.kind,
    required this.id,
    required this.point,
    required this.row,
  });

  /// Null when the row has no id or no place.
  static WaterSource? from(WaterKind kind, Map<String, dynamic> row) {
    final id = row['id'];
    final lat = row['latitude'];
    final lng = row['longitude'];
    if (id is! String || lat is! num || lng is! num) return null;
    return WaterSource(
      kind: kind,
      id: id,
      point: LatLng(lat.toDouble(), lng.toDouble()),
      row: row,
    );
  }

  final WaterKind kind;
  final String id;
  final LatLng point;
  final Map<String, dynamic> row;

  String? get code => _text(row['code']);
  String? get name => _text(row['name']);
  String? get address => _text(row['address']);
  String? get description => _text(row['description']);
  String? get waterType => _text(row['water_type']);
  bool get accessible => row['is_accessible'] != false;
  int? get capacityLitres => (row['capacity_liters'] as num?)?.toInt();

  /// A hydrant's status (the field's, else BFP's), a cistern's own; a body
  /// of water has none.
  WaterStatus? get status => switch (kind) {
    WaterKind.hydrant => WaterStatus.parse(row['effective_status']),
    WaterKind.cistern => WaterStatus.parse(row['status']),
    WaterKind.water => null,
  };

  /// When someone last checked a hydrant on the ground, and who: their
  /// organisation, else their name.
  DateTime? get checkedAt {
    final at = row['ground_truth_at'];
    return at is String ? DateTime.tryParse(at)?.toLocal() : null;
  }

  String? get checkedBy =>
      _text(row['checked_by_org']) ?? _text(row['checked_by_name']);

  /// What the sheet and a screen reader call it: "H-17", "Tripa de
  /// Gallina", else what it is.
  String get title => switch (kind) {
    WaterKind.hydrant => code ?? kind.noun,
    _ => name ?? code ?? kind.noun,
  };

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// What this account may do with water (backend v1.12.43). Every staff
/// member gets directions; Fire Volunteer and BFP coordinators and
/// responders set a hydrant's status; their coordinators propose new
/// sources, changes and switch-offs, which an Admin approves.
class WaterPowers {
  const WaterPowers({this.setStatus = false, this.propose = false});

  factory WaterPowers.of(Map<String, dynamic>? me) {
    final role = me?['role'];
    final fire = const {'fire_volunteer', 'bfp'}.contains(me?['agency_type']);
    return WaterPowers(
      setStatus: fire && (role == 'sub_admin' || role == 'response_team'),
      propose: fire && role == 'sub_admin',
    );
  }

  final bool setStatus;
  final bool propose;
}
