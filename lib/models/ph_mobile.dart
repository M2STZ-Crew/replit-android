import '../api/api_client.dart';

/// Philippine mobile numbers, the way residents type them.
///
/// Shared by sign-up, login and phone verification so all three accept the
/// same forms and say the same things. The server normalises and checks again;
/// these only catch what could never be a mobile number before a request is
/// spent on it.

/// 0917 123 4567, 09171234567, +63 917 123 4567, 639171234567 or 9171234567.
bool looksLikePhMobile(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  return (d.startsWith('09') && d.length == 11) ||
      (d.startsWith('639') && d.length == 12) ||
      (d.startsWith('9') && d.length == 10);
}

/// +639171234567 → "0917 123 4567", the way people write their own number.
/// Empty for anything that is not a PH mobile number.
String localPhMobile(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  final String national;
  if (digits.startsWith('63') && digits.length == 12) {
    national = '0${digits.substring(2)}';
  } else if (digits.startsWith('09') && digits.length == 11) {
    national = digits;
  } else if (digits.startsWith('9') && digits.length == 10) {
    national = '0$digits';
  } else {
    return '';
  }
  return '${national.substring(0, 4)} ${national.substring(4, 7)} '
      '${national.substring(7)}';
}

/// What to tell a resident when sending or checking a code fails: the
/// server's own words, except where they were written for us, not for them.
String phoneErrorText(ApiException e) => switch (e.code) {
  'semaphore_not_configured' =>
    'We cannot send texts right now. Please try again later.',
  'external_service_error' =>
    'We could not send the text. Please try again in a minute.',
  _ => e.message,
};
