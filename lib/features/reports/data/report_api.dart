import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/report.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final reportApiProvider = Provider<ReportApi>(
  (ref) => ReportApi(ref.watch(apiClientProvider)),
);

/// Talks to the backend's report endpoints.
///
/// Submission goes through FastAPI rather than straight to Supabase, because the
/// server does the work that makes a report useful: EXIF GPS cross-referencing,
/// area clustering, the storage upload, and the 300 m neighbourhood alert.
class ReportApi {
  ReportApi(this._client);

  final ApiClient _client;

  /// POST /reports/submit — multipart.
  ///
  /// Size and type are checked here as well as on the server so a doomed upload
  /// fails instantly instead of after pushing megabytes over mobile data.
  Future<Result<ReportSubmission>> submit({
    required double lat,
    required double lng,
    required File photo,
    List<String> agencies = const [],
    double? gpsAccuracyM,
    double? compassBearing,
    String? notes,
    File? video,
    ProgressCallback? onProgress,
  }) async {
    final photoBytes = await photo.length();
    if (photoBytes > AppConstants.maxPhotoSizeBytes) {
      return const Failure(
        ValidationException('Photo is over the 5 MB limit. Take a new one.'),
      );
    }
    final photoType = _imageMediaType(photo.path);
    if (photoType == null) {
      return const Failure(
        ValidationException('Photo must be a JPG or PNG.'),
      );
    }
    if (video != null && await video.length() > AppConstants.maxVideoSizeBytes) {
      return const Failure(
        ValidationException('Video is over the 1.5 MB limit.'),
      );
    }

    try {
      final form = FormData.fromMap({
        'device_lat': lat,
        'device_lng': lng,
        // The server parses this as a comma-separated list and validates each
        // value against the agency_type enum.
        'selected_agencies': agencies.join(','),
        'device_gps_accuracy_m': ?gpsAccuracyM,
        'compass_bearing': ?compassBearing,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: photo.uri.pathSegments.last,
          contentType: photoType,
        ),
        if (video != null)
          'video': await MultipartFile.fromFile(
            video.path,
            filename: video.uri.pathSegments.last,
            contentType: MediaType('video', 'mp4'),
          ),
      });

      final response = await _client.postForm<Map<String, dynamic>>(
        '/reports/submit',
        form,
        onSendProgress: onProgress,
      );

      if (response.statusCode == 201 && response.data != null) {
        return Success(ReportSubmission.fromMap(response.data!));
      }
      return Failure(ApiClient.toException(
        StateError('submit failed'),
        response,
      ));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// GET /reports/mine — the caller's own reports, newest first.
  Future<Result<List<MyReport>>> myReports() async {
    try {
      final response = await _client.get<List<dynamic>>('/reports/mine');
      if (response.statusCode == 200 && response.data != null) {
        return Success([
          for (final item in response.data!)
            MyReport.fromMap(item as Map<String, dynamic>),
        ]);
      }
      return Failure(ApiClient.toException(
        StateError('fetch failed'),
        response,
      ));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  MediaType? _imageMediaType(String path) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      _ => null,
    };
  }
}
