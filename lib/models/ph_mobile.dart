import 'package:flutter/services.dart';

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

/// What an empty mobile-number field shows: the shape to type into.
const String kPhMobileHint = '09XX XXX XXXX';

/// Shapes a PH mobile number as it is typed: 0917 123 4567.
///
/// Only digits go in, at most eleven, in 4-3-4 groups. A number started
/// without its 0 (917…) gets one, and one pasted or autofilled as +63 917…
/// becomes 0917…, so every field shows a number the same way. The cursor stays
/// where the person was typing, and backspacing over a space removes the digit
/// before it — otherwise the key would seem to do nothing.
class PhMobileFormatter extends TextInputFormatter {
  const PhMobileFormatter();

  static const int _maxDigits = 11;

  static String _digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');

  /// Eleven (or fewer) digits in 4-3-4 groups.
  static String group(String digits) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 4 || i == 7) out.write(' ');
      out.write(digits[i]);
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var cursor = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, text.length)
        : text.length;

    // Backspace over a space: take the digit before it as well.
    if (text.length == oldValue.text.length - 1 &&
        _digitsOf(text) == _digitsOf(oldValue.text) &&
        cursor > 0) {
      text = text.substring(0, cursor - 1) + text.substring(cursor);
      cursor -= 1;
    }

    var digits = _digitsOf(text);
    var before = _digitsOf(text.substring(0, cursor)).length;
    if (digits.startsWith('63')) {
      digits = '0${digits.substring(2)}';
      if (before >= 2) before -= 1;
    } else if (digits.startsWith('9')) {
      digits = '0$digits';
      before += 1;
    }
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    before = before.clamp(0, digits.length);

    final shaped = group(digits);
    var offset = 0;
    for (var seen = 0; offset < shaped.length && seen < before; offset++) {
      if (shaped.codeUnitAt(offset) != 0x20) seen++;
    }
    return TextEditingValue(
      text: shaped,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
