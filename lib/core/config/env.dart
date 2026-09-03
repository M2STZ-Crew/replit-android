import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to the values in `.env`, validated once at startup.
///
/// Reading `dotenv.env['KEY']` at each call site fails silently with a null when
/// a key is missing or misspelled, which surfaces much later as a confusing
/// network error. [assertConfigured] fails loudly at boot instead.
abstract final class Env {
  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  /// Base URL of the FastAPI backend.
  ///
  /// Auth goes straight to Supabase, but every domain operation goes through the
  /// backend, which owns EXIF cross-referencing, area clustering, storage uploads
  /// and the 300 m neighbourhood alerts. Talking to Postgres directly would skip
  /// all of it.
  ///
  /// Note for Android emulators: `localhost` inside the emulator is the emulator
  /// itself, not your machine. Use 10.0.2.2 for the host loopback, or your LAN IP
  /// when running on a physical handset.
  static String get apiBaseUrl => _read('API_BASE_URL');

  static String _read(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing $key in .env. Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }

  /// Returns the names of any required keys that are missing or blank.
  static List<String> missingKeys() {
    const required = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'API_BASE_URL'];
    return [
      for (final key in required)
        if ((dotenv.env[key] ?? '').isEmpty) key,
    ];
  }
}
