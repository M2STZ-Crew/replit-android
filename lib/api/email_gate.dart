/// The resident email gate, as the app sees it (v1.12.49).
///
/// 18 Nov 2026: "an illegitimate email can still sign up (the account was
/// created because of the Later button)". The backend now refuses a resident
/// whose email is not confirmed on every route but sign-in, /auth/me and the
/// email link itself (403, `error: email_not_verified`). RoleGate asks
/// /auth/me at start-up and shows Confirm your email first; this covers a
/// request refused mid-session. As [PhoneGate], kept free of widgets: main.dart
/// supplies [onTrip].
class EmailGate {
  EmailGate._();

  /// The backend's error code for "confirm your email first".
  static const String errorCode = 'email_not_verified';

  /// Shows the gate. Set once in main.dart.
  static void Function()? onTrip;

  static bool _showing = false;

  /// Whether Confirm your email is on screen now, so a burst of refused
  /// requests opens it once.
  static bool get isShowing => _showing;

  static void opened() => _showing = true;
  static void closed() => _showing = false;

  /// A request was refused for want of a confirmed email.
  static void trip() {
    if (_showing) return;
    onTrip?.call();
  }
}
