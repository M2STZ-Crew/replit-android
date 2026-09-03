import '../../../../core/constants/app_constants.dart';

/// An incident as a Response Team member sees it (IncidentSummary/IncidentDetail).
class ResponderIncident {
  const ResponderIncident({
    required this.id,
    required this.designation,
    required this.status,
    required this.centroidLat,
    required this.centroidLng,
    required this.reportCount,
    required this.confidenceScore,
    this.confidenceBand,
    this.alarmLevel,
    this.activeDispatchCount = 0,
    this.reportedAt,
    this.verifiedAt,
  });

  final String id;
  final String designation;
  final String status;

  /// Responders navigate to the area centroid, not to any single reporter's
  /// position (Section 2.5 stage 5).
  final double centroidLat;
  final double centroidLng;

  final int reportCount;
  final double confidenceScore;
  final String? confidenceBand;
  final String? alarmLevel;

  /// How many units are already committed — the signal for whether this incident
  /// still needs another team.
  final int activeDispatchCount;

  final DateTime? reportedAt;
  final DateTime? verifiedAt;

  String get statusLabel => IncidentStatus.label(status);

  /// Verified but nobody committed yet: available to self-select onto.
  bool get isAvailable => status == IncidentStatus.verified;

  /// Already being responded to, so the next action is en route / arrived.
  bool get isUnderway =>
      status == IncidentStatus.dispatched ||
      status == IncidentStatus.enRoute ||
      status == IncidentStatus.arrived;

  /// The single next lifecycle action, or null when there is nothing to do.
  /// Encodes the same forward-only chain the server enforces.
  String? get nextAction => switch (status) {
        IncidentStatus.verified => 'accept',
        IncidentStatus.dispatched => 'en_route',
        IncidentStatus.enRoute => 'arrived',
        _ => null,
      };

  factory ResponderIncident.fromMap(Map<String, dynamic> map) {
    return ResponderIncident(
      id: map['id'] as String,
      designation: map['designation'] as String? ?? 'Area',
      status: map['status'] as String? ?? IncidentStatus.pending,
      centroidLat: (map['centroid_lat'] as num?)?.toDouble() ?? 0,
      centroidLng: (map['centroid_lng'] as num?)?.toDouble() ?? 0,
      reportCount: (map['report_count'] as num?)?.toInt() ?? 0,
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 0,
      confidenceBand: map['confidence_band'] as String?,
      alarmLevel: map['alarm_level'] as String?,
      activeDispatchCount: (map['active_dispatch_count'] as num?)?.toInt() ?? 0,
      reportedAt: switch (map['reported_at']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
      verifiedAt: switch (map['verified_at']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}

/// One entry in the fire-code catalog (FireCodeResponse).
class FireCode {
  const FireCode({
    required this.id,
    required this.codeNumber,
    required this.name,
    required this.targetRole,
    this.description,
    this.targetAgency,
    this.isActive = true,
    this.displayOrder = 0,
  });

  final String id;
  final String codeNumber;
  final String name;
  final String? description;

  /// Who may press it. The server allows admin and sub_admin to broadcast any
  /// code, but a response_team member only their own.
  final String targetRole;
  final String? targetAgency;

  final bool isActive;
  final int displayOrder;

  bool pressableBy(String? role, String? agencyType) {
    if (!isActive) return false;
    if (role == UserRole.admin || role == UserRole.subAdmin) return true;
    return role == targetRole &&
        (targetAgency == null || agencyType == targetAgency);
  }

  factory FireCode.fromMap(Map<String, dynamic> map) {
    return FireCode(
      id: map['id'] as String,
      codeNumber: map['code_number'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      targetRole: map['target_role'] as String? ?? UserRole.responseTeam,
      targetAgency: map['target_agency'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}
