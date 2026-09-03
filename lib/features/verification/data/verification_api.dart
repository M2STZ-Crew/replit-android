import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/api_client.dart';
import '../../reports/data/report_api.dart' show apiClientProvider;

final verificationApiProvider = Provider<VerificationApi>(
  (ref) => VerificationApi(ref.watch(apiClientProvider)),
);

/// Result of a verification step, mirroring VerificationResultResponse.
class VerificationResult {
  const VerificationResult({
    required this.verified,
    required this.verifiedPercent,
    required this.badge,
    this.message,
  });

  final bool verified;
  final int verifiedPercent;
  final String badge;
  final String? message;

  factory VerificationResult.fromMap(Map<String, dynamic> map) {
    return VerificationResult(
      verified: map['verified'] as bool? ?? false,
      verifiedPercent: (map['verified_percent'] as num?)?.toInt() ?? 0,
      badge: map['badge'] as String? ?? 'yellow',
      message: map['message'] as String?,
    );
  }
}

/// Progressive verification: phone +40%, National ID +50%, email +10%
/// (Master Context Section 2.1).
class VerificationApi {
  VerificationApi(this._client);

  final ApiClient _client;

  /// Normalises a Philippine mobile number to E.164, which the server requires
  /// (`^\+[1-9]\d{6,14}$`). People type it four different ways; rejecting
  /// "09171234567" as malformed would be our bug, not theirs.
  static String? toE164(String input) {
    var digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) {
      return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(digits) ? digits : null;
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1); // 09171234567 -> 9171234567
    }
    if (digits.startsWith('63')) {
      digits = digits.substring(2); // 639171234567 -> 9171234567
    }
    // A PH mobile subscriber number is 10 digits and starts with 9.
    if (digits.length != 10 || !digits.startsWith('9')) return null;
    return '+63$digits';
  }

  /// POST /verification/phone/request — sends the SMS code.
  Future<Result<String>> requestPhoneCode(String phoneE164) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/verification/phone/request',
        data: {'phone': phoneE164},
      );
      if (response.statusCode == 200) {
        return Success(
          response.data?['message'] as String? ?? 'Code sent by SMS.',
        );
      }
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// POST /verification/phone/verify — checks the code, awarding +40% on success.
  Future<Result<VerificationResult>> verifyPhoneCode(String code) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/verification/phone/verify',
        data: {'code': code},
      );
      if (response.statusCode == 200 && response.data != null) {
        return Success(VerificationResult.fromMap(response.data!));
      }
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// POST /verification/email/request — emails a confirmation link (+10% once
  /// the link is opened; the app cannot complete this step itself).
  Future<Result<String>> requestEmailLink() async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/verification/email/request',
      );
      if (response.statusCode == 200) {
        return Success(
          response.data?['message'] as String? ?? 'Verification email sent.',
        );
      }
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }
}
