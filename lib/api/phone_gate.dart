/// The citizen phone gate, as the app sees it.
///
/// The backend refuses a citizen account that has not verified a mobile number
/// on every route but sign-in, /auth/me and the verification routes themselves
/// (403, `error: phone_not_verified`). RoleGate asks /auth/me at start-up and
/// shows the gate before anything else; this covers the other way in — a
/// request refused mid-session, say because the gate was switched on while the
/// app was open. Whatever screen hit it, the answer is the same screen.
///
/// Kept free of widgets so the API layer can trip it without importing
/// screens: main.dart supplies [onTrip].
class PhoneGate {
  PhoneGate._();

  /// The backend's error code for "verify your phone first".
  static const String errorCode = 'phone_not_verified';

  /// Shows the gate. Set once in main.dart.
  static void Function()? onTrip;

  static bool _showing = false;

  /// Whether the gate screen is on screen now, so a burst of refused requests
  /// opens it once rather than once per request.
  static bool get isShowing => _showing;

  static void opened() => _showing = true;
  static void closed() => _showing = false;

  /// A request was refused for want of a verified phone.
  static void trip() {
    if (_showing) return;
    onTrip?.call();
  }
}
