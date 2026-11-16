import 'dart:math' as math;

import '../i18n/i18n.dart';
import 'api_client.dart';

/// The server's two "slow down" answers to a password (backend v1.12.36), in
/// the person's language, or null for any other refusal:
///
/// * `too_many_attempts`: five wrong passwords for this account within 15
///   minutes, so it waits `details.retry_after_seconds`. Signing in, the
///   password change and Delete my account share that one count.
/// * `too_many_requests`: Supabase is busy with everyone signing in at once.
String? slowDownMessage(ApiException e) {
  switch (e.code) {
    case 'too_many_attempts':
      final wait = (e.details?['retry_after_seconds'] as num?)?.toInt() ?? 900;
      return t(
        'Too many wrong passwords for this account. Wait {n} min, then try '
        'again, or tap Forgot password?.',
        {'n': math.max(1, (wait / 60).ceil())},
      );
    case 'too_many_requests':
      return t(
        'Too many people are signing in right now. Wait a few minutes, then '
        'try again.',
      );
  }
  return null;
}
