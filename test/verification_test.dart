import 'package:flutter_test/flutter_test.dart';

import 'package:replit_mobile/core/constants/app_constants.dart';
import 'package:replit_mobile/features/verification/data/verification_api.dart';
import 'package:replit_mobile/features/verification/presentation/providers/verification_provider.dart';

void main() {
  group('phone normalisation to E.164', () {
    // The server enforces ^\+[1-9]\d{6,14}$. People type PH numbers at least
    // four different ways and all of them must reach the same value.
    test('accepts the four common ways a PH mobile is written', () {
      const expected = '+639171234567';
      for (final input in [
        '09171234567',
        '+639171234567',
        '639171234567',
        '0917 123 4567',
      ]) {
        expect(VerificationApi.toE164(input), expected, reason: input);
      }
    });

    test('tolerates punctuation people paste in', () {
      expect(VerificationApi.toE164('0917-123-4567'), '+639171234567');
      expect(VerificationApi.toE164('(0917) 123 4567'), '+639171234567');
    });

    test('rejects numbers that are not PH mobiles', () {
      expect(VerificationApi.toE164('12345'), isNull, reason: 'too short');
      expect(VerificationApi.toE164('0281234567'), isNull, reason: 'landline');
      expect(VerificationApi.toE164('091712345678'), isNull, reason: 'too long');
      expect(VerificationApi.toE164(''), isNull);
      expect(VerificationApi.toE164('not a number'), isNull);
    });

    test('passes through a valid international number unchanged', () {
      expect(VerificationApi.toE164('+14155552671'), '+14155552671');
    });

    test('never returns something the server regex would reject', () {
      final pattern = RegExp(r'^\+[1-9]\d{6,14}$');
      for (final input in ['09171234567', '+639171234567', '0917 123 4567']) {
        final out = VerificationApi.toE164(input)!;
        expect(pattern.hasMatch(out), isTrue, reason: '$input -> $out');
      }
    });
  });

  group('verification weights', () {
    test('phone is the largest single non-ID step', () {
      expect(VerificationBadge.phonePercent, 40);
      expect(VerificationBadge.emailPercent, 10);
      expect(VerificationBadge.nationalIdPercent, 50);
    });

    test('phone plus email lands in the light_green band, not green', () {
      const total =
          VerificationBadge.phonePercent + VerificationBadge.emailPercent;
      expect(total, 50);
      // 50-89 is light_green per the users.badge generated column; reaching
      // green needs the National ID step.
      expect(total < 90, isTrue);
    });
  });

  group('VerificationState', () {
    test('starts on the number step so the code field is unreachable', () {
      expect(const VerificationState().phoneStep, PhoneStep.enterNumber);
    });

    test('clearMessages wipes both banners', () {
      const s = VerificationState(
        errorMessage: 'Trial account cannot text that number.',
        infoMessage: 'Code sent.',
      );
      final cleared = s.copyWith(clearMessages: true);
      expect(cleared.errorMessage, isNull);
      expect(cleared.infoMessage, isNull);
    });

    test('an unrelated update preserves the current message', () {
      const s = VerificationState(infoMessage: 'Code sent.');
      expect(s.copyWith(busy: true).infoMessage, 'Code sent.');
    });
  });
}
