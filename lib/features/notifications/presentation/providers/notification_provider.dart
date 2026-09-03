import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notification_api.dart';
import '../../domain/entities/app_notification.dart';

/// The inbox, newest first.
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final result = await ref.watch(notificationApiProvider).list();
  return result.when(
    success: (items) => items,
    failure: (error) => throw error,
  );
});

/// Unread count for the bell badge. Kept separate from the list so the badge can
/// refresh without rebuilding the whole inbox.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final result = await ref.watch(notificationApiProvider).unreadCount();
  return result.when(success: (n) => n, failure: (_) => 0);
});

/// Tracks which alerts have been answered during this session.
///
/// The answer is recorded server-side, but the inbox row itself does not change
/// shape, so without this the buttons would still look actionable after a tap.
class AlertResponses extends StateNotifier<Map<String, String>> {
  AlertResponses(this._ref) : super(const {});

  final Ref _ref;

  /// Returns the failure message, or null on success.
  Future<String?> respond({
    required String notificationId,
    required String areaId,
    required String response,
  }) async {
    final api = _ref.read(notificationApiProvider);
    final result = await api.respond(areaId: areaId, response: response);

    return result.when(
      success: (_) {
        state = {...state, areaId: response};
        // Answering is an implicit read.
        api.markRead(notificationId);
        _ref.invalidate(unreadCountProvider);
        return null;
      },
      failure: (error) => error.message,
    );
  }

  String? responseFor(String? areaId) => areaId == null ? null : state[areaId];
}

final alertResponsesProvider =
    StateNotifierProvider<AlertResponses, Map<String, String>>(
  AlertResponses.new,
);
