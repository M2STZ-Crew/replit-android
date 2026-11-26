import '../i18n/i18n.dart';
import '../store_build.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'push_service.dart';
import 'session.dart';

/// Accounts this copy of the app does not open.
///
/// Admin accounts work in the Admin console on the web, never in the app
/// (13 November 2026: "barangay76.admin@replit.com, bfp.admin@replit.com,
/// pnp.admin@replit.com. their account can be logged in mobile with a
/// citizen (supposedly not, so fix this). in short all admin accounts should
/// be logged in web only, not on mobile").
///
/// Google Play's copy is for residents (v1.12.65, answered "go with the
/// safest" on 27 November 2026): a coordinator or responder is refused there
/// too, so the reviewers' resident account opens all of it and nobody from
/// Google can act on a real fire. They use the copy from their welcome email.
///
/// The app opened coordinators and responders in their own apps and took any
/// other role for a resident, so an Admin landed in the residents' app. Now
/// an account it does not open is refused at sign in, before its session is
/// kept or its phone registered for pushes (LoginScreen); a kept session is
/// signed out when the app starts (SplashScreen), and wherever else the
/// account loads (RoleGate).
abstract final class WebOnly {
  /// Whether [me] (GET /auth/me) is an account the app does not open.
  static bool account(Map<String, dynamic>? me) =>
      me?['role'] == 'admin' || playStaff(me);

  /// A coordinator's or responder's account in Google Play's copy.
  static bool playStaff(Map<String, dynamic>? me) {
    final role = me?['role'];
    return StoreBuild.play && (role == 'sub_admin' || role == 'response_team');
  }

  /// What an Admin is told, in the app's language.
  static String get message => t(
    'Admin accounts sign in on the web console, not in the app: {url}',
    {'url': Uri.parse(ApiConfig.adminConsoleUrl).host},
  );

  /// What a coordinator or responder is told in Google Play's copy. No link:
  /// a Play app does not send people to install apps from elsewhere, and
  /// their welcome email already has it.
  static String get playStaffMessage => t(
    'This Google Play version of RepLiT is for residents. Coordinators and '
    'responders: use the RepLiT app from the link in your welcome email.',
  );

  /// What [me] is told when the app does not open it.
  static String messageFor(Map<String, dynamic>? me) =>
      playStaff(me) ? playStaffMessage : message;

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
