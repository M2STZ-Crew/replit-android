import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class ApiClient {
  ApiClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: AppConstants.httpTimeout,
        receiveTimeout: AppConstants.httpTimeout,
        sendTimeout: AppConstants.httpTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(_loggingInterceptor());
  }

  late final Dio _dio;

  Dio get dio => _dio;

  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        final sanitizedMessage = _sanitizeErrorMessage(error.message ?? '');
        handler.next(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: sanitizedMessage,
          ),
        );
      },
    );
  }

  String _sanitizeErrorMessage(String message) {
    return message
        .replaceAll(RegExp(r'key=[^&\s]+'), 'key=***')
        .replaceAll(RegExp(r'token=[^&\s]+'), 'token=***');
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }
}
