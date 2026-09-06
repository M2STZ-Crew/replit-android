/// Backend API base URL.
///
/// Override at run time with: flutter run --dart-define=REPLIT_API_BASE=http://`ip`:8000
/// Notes:
///  - Web / Windows / iOS simulator: http://127.0.0.1:8000 (default)
///  - Android emulator: use http://10.0.2.2:8000 (the host's localhost)
///  - Physical device: use your PC's LAN IP, e.g. http://192.168.1.20:8000
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'REPLIT_API_BASE',
    defaultValue: 'http://192.168.254.168:8000',
  );
}