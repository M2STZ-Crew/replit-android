/// Mobile numbers wait for an SMS provider (Master Context v10 §10.3). Until
/// one is live, RepLiT is email first (WHAT'S NEXT, 2.2): signing in and
/// signing up take an email, and each place a mobile number would go — signing
/// in with one, giving one at sign-up, verifying one — shows greyed out,
/// "Coming soon", rather than a form that cannot send a code.
///
/// The one switch for all of it. Turn it on here (or build with
/// `--dart-define=PHONE_NUMBERS=true`) together with the server's
/// REQUIRE_CITIZEN_PHONE_VERIFICATION, which has residents verify a number.
abstract final class PhoneNumbers {
  static const bool live = bool.fromEnvironment(
    'PHONE_NUMBERS',
    defaultValue: false,
  );

  /// [live], unless a test says otherwise.
  static bool open = live;
}
