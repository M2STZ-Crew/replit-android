/// Backend API base URL, supplied at build time.
///
/// Set it in env.json (copy env.example.json) and build with:
///
///   flutter run --dart-define-from-file=env.json
///
/// Which address to use:
///  - Android emulator:  http://10.0.2.2:8000   — the emulator's alias for the
///    host machine's localhost. This is the default, so a fresh clone running
///    on an emulator works with no configuration.
///  - Physical device:   `http://<your PC's LAN IP>:8000`, e.g.
///    http://192.168.1.20:8000. The phone and the PC must be on the same
///    network, and the address must be listed in
///    android/app/src/main/res/xml/network_security_config.xml — Android
///    blocks cleartext HTTP to anything not named there.
///  - Deployed backend:  https://... — no config entry needed, because HTTPS
///    is permitted by default.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'REPLIT_API_BASE',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Just the host, for showing a person which server their build talks to.
  ///
  /// Worth surfacing because the address is baked in at build time: a tester
  /// holding an older APK cannot tell, and neither can anyone helping them. A
  /// build once shipped pointing at `onrender.co` instead of `onrender.com` —
  /// someone else's domain, which answered with a redirect — and the app could
  /// only say that it could not reach the server.
  static String get host => Uri.parse(baseUrl).host;

  /// Where the Observer Console (observer-web) is served, shown to Police,
  /// Medical and Barangay team captains who sign in here — their surface is the
  /// web (Master Context v10 §2.6). Empty until it is deployed, in which case
  /// the app says to ask the Admin for the address rather than inventing one.
  static const String observerConsoleUrl = String.fromEnvironment(
    'OBSERVER_CONSOLE_URL',
  );
}
