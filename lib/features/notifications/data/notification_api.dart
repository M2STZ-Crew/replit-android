import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/api_client.dart';
import '../../reports/data/report_api.dart' show apiClientProvider;
import '../domain/entities/app_notification.dart';

final notificationApiProvider = Provider<NotificationApi>(
  (ref) => NotificationApi(ref.watch(apiClientProvider)),
);

/// The in-app inbox and the crowdsourced neighbourhood response (Section 2.2).
///
/// The inbox is independent of push: the backend records every alert here as
/// well as sending it via FCM, so a user who denied notification permission —
/// or whose token expired — can still see and answer alerts.
class NotificationApi {
  NotificationApi(this._client);

  final ApiClient _client;

  Future<Result<List<AppNotification>>> list() async {
    try {
      final response = await _client.get<List<dynamic>>('/notifications');
      if (response.statusCode == 200 && response.data != null) {
        return Success([
          for (final item in response.data!)
            AppNotification.fromMap(item as Map<String, dynamic>),
        ]);
      }
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  Future<Result<int>> unreadCount() async {
    try {
      final response =
          await _client.get<Map<String, dynamic>>('/notifications/unread-count');
      if (response.statusCode == 200) {
        return Success((response.data?['count'] as num?)?.toInt() ?? 0);
      }
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  Future<Result<void>> markRead(String notificationId) async {
    try {
      final response =
          await _client.post<Map<String, dynamic>>('/notifications/$notificationId/read');
      if (response.statusCode == 200) return const Success(null);
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  Future<Result<void>> markAllRead() async {
    try {
      final response =
          await _client.post<Map<String, dynamic>>('/notifications/read-all');
      if (response.statusCode == 200) return const Success(null);
      return Failure(ApiClient.toException(StateError('failed'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// Answer a 300 m neighbourhood alert.
  ///
  /// Either answer stops further alerts for that area — the 60 s worker skips
  /// any recipient whose response is set. 'report' additionally tells the
  /// dispatcher a neighbour corroborated the fire.
  Future<Result<void>> respond({
    required String areaId,
    required String response,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/notifications/respond',
        data: {'area_id': areaId, 'response': response},
      );
      if (res.statusCode == 200) return const Success(null);
      return Failure(ApiClient.toException(StateError('failed'), res));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// POST /devices — register this handset's FCM token so pushes reach it.
  Future<Result<void>> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/devices',
        data: {
          'fcm_token': fcmToken,
          'platform': platform,
          'device_name': ?deviceName,
          'app_version': ?appVersion,
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return const Success(null);
      }
      return Failure(ApiClient.toException(StateError('failed'), res));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }
}
