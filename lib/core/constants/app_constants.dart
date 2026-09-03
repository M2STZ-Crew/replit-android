/// Domain constants mirrored from the RepLiT backend.
///
/// These MUST match the Postgres enums in supabase/migrations and the limits in
/// app/core/config.py. Values that drift here fail silently at runtime — the API
/// rejects the request and the app can only report a generic error.
library;

abstract final class AppConstants {
  static const String appName = 'RepLiT';
  static const String appTagline = 'Report Location and Incident in Time';

  static const Duration httpTimeout = Duration(seconds: 30);
  static const Duration locationUpdateInterval = Duration(seconds: 15);

  /// Responders broadcast GPS every 5 s while dispatched (Section 2.4).
  static const Duration responderGpsInterval = Duration(seconds: 5);

  /// Hold duration for the SOS button before capture begins (Section 3.3).
  static const Duration sosHoldDuration = Duration(seconds: 3);

  // Upload limits — enforced server-side by REPORT_MAX_PHOTO_BYTES /
  // REPORT_MAX_VIDEO_BYTES. A photo is mandatory; video is optional.
  static const int maxPhotoSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxVideoSizeBytes = 1536 * 1024; //    1.5 MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedVideoTypes = ['mp4'];

  /// reports.notes is varchar(2000) on the server.
  static const int maxNotesLength = 2000;

  // Pasay City — the operational area (Section 1.2).
  static const double defaultMapLat = 14.5378;
  static const double defaultMapLng = 121.0014;
  static const double defaultMapZoom = 13.0;
  static const double incidentDetailZoom = 16.0;

  /// Clustering and neighbourhood-alert radius (Sections 2.2, 2.3).
  static const int areaRadiusMeters = 300;
}

abstract final class HiveBoxes {
  static const String incidents = 'incidents_box';
  static const String userSession = 'user_session_box';
  static const String settings = 'settings_box';
}

/// Tables reachable directly via the Supabase client. Everything else goes
/// through the FastAPI backend, which owns clustering, EXIF cross-referencing,
/// storage uploads and neighbourhood alerts.
abstract final class SupabaseTables {
  static const String users = 'users';
}

/// public.user_role — the four-tier hierarchy (Section 2.6).
abstract final class UserRole {
  static const String admin = 'admin';
  static const String subAdmin = 'sub_admin';
  static const String responseTeam = 'response_team';
  static const String generalUser = 'general_user';

  static const List<String> all = [admin, subAdmin, responseTeam, generalUser];

  static bool isStaff(String role) => role == admin || role == subAdmin;
}

/// public.area_status — the incident lifecycle (Section 2.5).
abstract final class IncidentStatus {
  static const String pending = 'pending';
  static const String verified = 'verified';
  static const String dispatched = 'dispatched';
  static const String enRoute = 'en_route';
  static const String arrived = 'arrived';
  static const String resolved = 'resolved';
  static const String rejected = 'rejected';
  static const String merged = 'merged';

  static const List<String> all = [
    pending, verified, dispatched, enRoute, arrived, resolved, rejected, merged,
  ];

  /// Terminal states leave the live feed — mirrors TERMINAL_STATUSES in
  /// app/services/incident.py.
  static const List<String> terminal = [resolved, rejected, merged];

  static bool isActive(String status) => !terminal.contains(status);

  static String label(String status) => switch (status) {
        pending => 'Awaiting verification',
        verified => 'Verified',
        dispatched => 'Responders dispatched',
        enRoute => 'Responders en route',
        arrived => 'Responders on scene',
        resolved => 'Resolved',
        rejected => 'Rejected',
        merged => 'Merged into another area',
        _ => status,
      };
}

/// public.agency_type — the responder types a reporter may select.
abstract final class AgencyType {
  static const String fireVolunteer = 'fire_volunteer';
  static const String bfp = 'bfp';
  static const String barangay = 'barangay';
  static const String medical = 'medical';
  static const String police = 'police';

  static const List<String> all = [fireVolunteer, bfp, barangay, medical, police];

  static String label(String agency) => switch (agency) {
        fireVolunteer => 'Fire Volunteers',
        bfp => 'Bureau of Fire Protection',
        barangay => 'Barangay',
        medical => 'Medical',
        police => 'Police',
        _ => agency,
      };
}

/// public.verification_badge — derived server-side from verified_percent.
/// Phone 40% + National ID 50% + email 10% (Section 2.1).
abstract final class VerificationBadge {
  static const String yellow = 'yellow'; //       < 50%
  static const String lightGreen = 'light_green'; // 50-89%
  static const String green = 'green'; //          90-99%
  static const String greenCheck = 'green_check'; //  100%

  static const int phonePercent = 40;
  static const int nationalIdPercent = 50;
  static const int emailPercent = 10;

  static String label(String badge) => switch (badge) {
        yellow => 'Low credibility',
        lightGreen => 'Partly verified',
        green => 'High credibility',
        greenCheck => 'Fully verified',
        _ => badge,
      };
}

/// Neighbourhood crowdsourced validation (Section 2.2).
abstract final class NeighborhoodResponse {
  static const String report = 'report';
  static const String ignore = 'ignore';
}
