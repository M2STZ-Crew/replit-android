import '../i18n/i18n.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'push_service.dart';
import 'session.dart';

/// Admin accounts work in the Admin console on the web, never in the app
/// (13 November 2026: "barangay76.admin@replit.com, bfp.admin@replit.com,
/// pnp.admin@replit.com. their account can be logged in mobile with a
/// citizen (supposedly not, so fix this). in short all admin accounts should
/// be logged in web only, not on mobile").
///
/// The app opened coordinators and responders in their own apps and took any
/// other role for a resident, so an Admin landed in the residents' app. Now
/// an Admin is refused at sign in, before its session is kept or its phone
/// registered for pushes (LoginScreen); a kept session is signed out when the
/// app starts (SplashScreen), and wherever else the account loads (RoleGate).
abstract final class WebOnly {
  /// Whether [me] (GET /auth/me) is an account the app does not open.
  static bool account(Map<String, dynamic>? me) => me?['role'] == 'admin';

  /// What the person is told, in the app's language.
  static String get message => t(
    'Admin accounts sign in on the web console, not in the app: {url}',
    {'url': Uri.parse(ApiConfig.adminConsoleUrl).host},
  );

  /// Signs this phone out of the account: it stops getting the account's
  /// pushes, and the session is revoked and forgotten. Never throws.
  ///
  /// The server's part is best-effort and bounded ([cleanupFor]): a slow
  /// server, or a background scheduler that never answers, must not keep
  /// the person from hearing where to go.
  static Future<void> signOut(ApiClient api) async {
    try {
      await PushService.instance.unregister().timeout(cleanupFor);
    } catch (_) {
      // Its phone may never have been registered, or nothing answered.
    }
    try {
      await api.logout().timeout(cleanupFor);
    } catch (_) {
      // The session is forgotten below either way.
    }
    await Session.instance.clear();
  }

  /// How long signing out waits on each step before going on anyway.
  static const Duration cleanupFor = Duration(seconds: 5);
}
