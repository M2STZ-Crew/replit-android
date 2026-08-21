abstract final class AppConstants {
  static const String appName = 'RepLiT';
  static const String appTagline = 'Report Location and Incident in Time';

  static const Duration httpTimeout = Duration(seconds: 30);
  static const Duration locationUpdateInterval = Duration(seconds: 15);
  static const Duration weatherCacheDuration = Duration(minutes: 30);

  static const int maxPhotoSizeBytes = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
  static const int maxDescriptionLength = 1000;
  static const int minDescriptionLength = 10;

  static const double defaultMapZoom = 13.0;
  static const double incidentDetailZoom = 16.0;
}

abstract final class HiveBoxes {
  static const String incidents = 'incidents_box';
  static const String userSession = 'user_session_box';
  static const String weather = 'weather_box';
  static const String settings = 'settings_box';
}

abstract final class SupabaseTables {
  static const String users = 'users';
  static const String incidents = 'incidents';
  static const String responderLocations = 'responder_locations';
}

abstract final class IncidentStatus {
  static const String pending = 'pending';
  static const String dispatched = 'dispatched';
  static const String ongoing = 'ongoing';
  static const String resolved = 'resolved';

  static const List<String> all = [pending, dispatched, ongoing, resolved];
}

abstract final class UserRole {
  static const String citizen = 'citizen';
  static const String responder = 'responder';
  static const String admin = 'admin';

  static const List<String> all = [citizen, responder, admin];
}
