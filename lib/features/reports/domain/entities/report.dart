import '../../../../core/constants/app_constants.dart';

/// The server's answer to a submitted report (ReportSubmitResponse).
///
/// Carries the clustering outcome, so the citizen can be told which Area their
/// report joined rather than just "submitted".
class ReportSubmission {
  const ReportSubmission({
    required this.id,
    required this.areaId,
    required this.areaDesignation,
    required this.hasExif,
    required this.gpsDiscrepancyFlag,
    required this.message,
    this.gpsDiscrepancyM,
    this.createdAt,
  });

  final String id;
  final String areaId;

  /// Human label from clustering: "Area 1", "Area 1.2" (Section 2.3).
  final String areaDesignation;

  /// Whether the photo carried embedded GPS.
  final bool hasExif;

  /// True when photo GPS and device GPS disagree by more than 100 m — the
  /// report is still accepted, but flagged for Sub-Admin review (Section 3.1).
  final bool gpsDiscrepancyFlag;

  final double? gpsDiscrepancyM;
  final String message;
  final DateTime? createdAt;

  factory ReportSubmission.fromMap(Map<String, dynamic> map) {
    return ReportSubmission(
      id: map['id'] as String,
      areaId: map['area_id'] as String,
      areaDesignation: map['area_designation'] as String? ?? 'Area',
      hasExif: map['has_exif'] as bool? ?? false,
      gpsDiscrepancyFlag: map['gps_discrepancy_flag'] as bool? ?? false,
      gpsDiscrepancyM: (map['gps_discrepancy_m'] as num?)?.toDouble(),
      message: map['message'] as String? ?? 'Report submitted.',
      createdAt: switch (map['created_at']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}

/// One of the caller's own reports (ReportResponse from GET /reports/mine).
class MyReport {
  const MyReport({
    required this.id,
    required this.lat,
    required this.lng,
    required this.hasExif,
    required this.gpsDiscrepancyFlag,
    required this.userVerifiedPercent,
    this.selectedAgencies = const [],
    this.photoUrl,
    this.videoUrl,
    this.compassBearing,
    this.createdAt,
    this.areaId,
    this.areaDesignation,
    this.areaStatus,
    this.areaConfidenceBand,
  });

  final String id;
  final double lat;
  final double lng;
  final bool hasExif;
  final bool gpsDiscrepancyFlag;

  /// The reporter's verification level captured at submission time — a snapshot,
  /// so later verification does not rewrite the credibility of past reports.
  final int userVerifiedPercent;

  final List<String> selectedAgencies;
  final String? photoUrl;
  final String? videoUrl;
  final double? compassBearing;
  final DateTime? createdAt;

  /// The clustered incident this report belongs to. Null only in the window
  /// between insert and clustering, or if clustering failed.
  final String? areaId;
  final String? areaDesignation;
  final String? areaStatus;
  final String? areaConfidenceBand;

  String get agenciesLabel => selectedAgencies.isEmpty
      ? 'No agency selected'
      : selectedAgencies.map(AgencyType.label).join(', ');

  /// What the reporter is told about progress. Deliberately phrased from their
  /// side of the screen: they care whether help is coming, not which enum value
  /// the area row holds.
  String get statusLabel => areaStatus == null
      ? 'Received'
      : IncidentStatus.label(areaStatus!);

  bool get isActive =>
      areaStatus == null || IncidentStatus.isActive(areaStatus!);

  factory MyReport.fromMap(Map<String, dynamic> map) {
    return MyReport(
      id: map['id'] as String,
      lat: (map['device_lat'] as num).toDouble(),
      lng: (map['device_lng'] as num).toDouble(),
      hasExif: map['has_exif'] as bool? ?? false,
      gpsDiscrepancyFlag: map['gps_discrepancy_flag'] as bool? ?? false,
      userVerifiedPercent: (map['user_verified_percent'] as num?)?.toInt() ?? 0,
      selectedAgencies: [
        for (final a in (map['selected_agencies'] as List<dynamic>? ?? []))
          a as String,
      ],
      photoUrl: map['photo_url'] as String?,
      videoUrl: map['video_url'] as String?,
      compassBearing: (map['compass_bearing'] as num?)?.toDouble(),
      createdAt: switch (map['created_at']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
      areaId: map['area_id'] as String?,
      areaDesignation: map['area_designation'] as String?,
      areaStatus: map['area_status'] as String?,
      areaConfidenceBand: map['area_confidence_band'] as String?,
    );
  }
}
