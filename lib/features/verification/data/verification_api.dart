import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
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

/// State of one verification channel, from GET /verification/status.
class ChannelStatus {
  const ChannelStatus({
    required this.type,
    required this.status,
    this.percentAwarded = 0,
    this.reviewNotes,
  });

  final String type;
  final String status;
  final int percentAwarded;

  /// The reviewer's reason, present when an Admin rejected a submission.
  final String? reviewNotes;

  factory ChannelStatus.fromMap(Map<String, dynamic> map) => ChannelStatus(
        type: map['type'] as String,
        status: map['status'] as String,
        percentAwarded: (map['percent_awarded'] as num?)?.toInt() ?? 0,
        reviewNotes: map['review_notes'] as String?,
      );
}

/// Progressive verification: phone +40%, National ID +50%, email +10%
/// (Master Context Section 2.1).
class VerificationApi {
  VerificationApi(this._client);

  final ApiClient _client;

  /// GET /verification/status — per-channel state.
  ///
  /// Needed to tell "never submitted" from "submitted, awaiting Admin review":
  /// both award 0%, but only one of them should show an upload form.
  Future<Result<Map<String, ChannelStatus>>> status() async {
    try {
      final response =
          await _client.get<Map<String, dynamic>>('/verification/status');
      if (response.statusCode == 200 && response.data != null) {
        final channels = response.data!['channels'] as List<dynamic>? ?? [];
        return Success({
          for (final c in channels)
            (c as Map<String, dynamic>)['type'] as String:
                ChannelStatus.fromMap(c),
        });
      }
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// POST /verification/national-id/manual — ID photo + matching selfie.
  ///
  /// Awards nothing immediately: the submission enters the Admin review queue
  /// and becomes +50% only on approval, which is why the caller must show a
  /// pending state rather than a success.
  Future<Result<VerificationResult>> submitNationalId({
    required File idImage,
    required File selfieImage,
  }) async {
    for (final (label, file) in [('ID photo', idImage), ('selfie', selfieImage)]) {
      if (await file.length() > AppConstants.maxIdImageSizeBytes) {
        return Failure(
          ValidationException('Your $label is over the 10 MB limit.'),
        );
      }
      if (_mediaType(file.path) == null) {
        return Failure(ValidationException('Your $label must be a JPG or PNG.'));
      }
    }

    try {
      final form = FormData.fromMap({
        'id_image': await MultipartFile.fromFile(
          idImage.path,
          filename: idImage.uri.pathSegments.last,
          contentType: _mediaType(idImage.path),
        ),
        'selfie_image': await MultipartFile.fromFile(
          selfieImage.path,
          filename: selfieImage.uri.pathSegments.last,
          contentType: _mediaType(selfieImage.path),
        ),
      });
      final response = await _client.postForm<Map<String, dynamic>>(
        '/verification/national-id/manual',
        form,
      );
      if (response.statusCode == 200 && response.data != null) {
        return Success(VerificationResult.fromMap(response.data!));
      }
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  MediaType? _mediaType(String path) => switch (path.toLowerCase().split('.').last) {
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        'png' => MediaType('image', 'png'),
        _ => null,
      };

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
