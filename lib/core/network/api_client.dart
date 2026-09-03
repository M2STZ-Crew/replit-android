import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../config/env.dart';
import '../constants/app_constants.dart';
import '../errors/app_exception.dart';

/// HTTP client for the RepLiT FastAPI backend.
///
/// Every request carries the caller's Supabase access token as a bearer token —
/// the backend validates it against the project JWKS and derives the user's role
/// from it, so an unauthenticated request is a 401 rather than a silent empty
/// result. The token is read per-request, never cached, so it stays correct
/// across a refresh or a sign-out.
class ApiClient {
  ApiClient({String? baseUrl, String? Function()? accessToken})
      : _accessToken = accessToken ?? _supabaseAccessToken {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? Env.apiBaseUrl,
        connectTimeout: AppConstants.httpTimeout,
        receiveTimeout: AppConstants.httpTimeout,
        sendTimeout: AppConstants.httpTimeout,
        headers: {'Accept': 'application/json'},
        // The backend returns structured JSON for 4xx; let the error mapper read
        // it instead of Dio throwing on the status code alone.
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(_authInterceptor());
  }

  late final Dio _dio;
  final String? Function() _accessToken;

  Dio get dio => _dio;

  static String? _supabaseAccessToken() =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _accessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: _sanitize(error.message ?? ''),
          ),
        );
      },
    );
  }

  String _sanitize(String message) => message
      .replaceAll(RegExp(r'key=[^&\s]+'), 'key=***')
      .replaceAll(RegExp(r'token=[^&\s]+'), 'token=***')
      .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._-]+'), 'Bearer ***');

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);

  /// Multipart POST, for report submission with photo and optional video.
  Future<Response<T>> postForm<T>(
    String path,
    FormData form, {
    ProgressCallback? onSendProgress,
  }) =>
      _dio.post<T>(
        path,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onSendProgress,
      );

  /// Turns a response or transport failure into a typed [AppException].
  ///
  /// The backend's envelope is flat, with keys `error` (a stable snake_case
  /// code), `message` (human text), `details` and `request_id` — see
  /// app/core/exceptions.py. We surface `message`, so users see
  /// "Photo exceeds the 5 MB limit" rather than "Http status 400".
  static AppException toException(Object error, [Response<dynamic>? response]) {
    final res = response ?? (error is DioException ? error.response : null);
    final status = res?.statusCode;
    final serverMessage = _messageFrom(res?.data);

    if (status == 401) {
      return AuthException(serverMessage ?? 'Your session expired. Sign in again.');
    }
    if (status == 403) {
      return AuthException(serverMessage ?? 'You do not have access to this.');
    }
    if (status != null && status >= 400 && status < 500) {
      return ValidationException(serverMessage ?? 'The request was rejected.');
    }
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          const NetworkException('The server took too long to respond.'),
        DioExceptionType.connectionError => const NetworkException(
            'Cannot reach the server. Check your connection and that the '
            'backend is running.',
          ),
        _ => ServerException(serverMessage ?? 'Something went wrong on the server.'),
      };
    }
    return ServerException(serverMessage ?? 'Something went wrong.', error);
  }

  static String? _messageFrom(dynamic data) {
    if (data is! Map) return null;
    // The backend's own envelope.
    if (data['message'] is String) return data['message'] as String;
    // FastAPI's default, in case a handler is ever bypassed.
    if (data['detail'] is String) return data['detail'] as String;
    return null;
  }

  /// The stable machine-readable code from the envelope, for callers that need
  /// to branch on a specific failure rather than show text.
  static String? errorCodeOf(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return null;
  }
}
