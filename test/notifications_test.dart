import 'package:flutter_test/flutter_test.dart';

import 'package:replit_mobile/core/constants/app_constants.dart';
import 'package:replit_mobile/features/notifications/domain/entities/app_notification.dart';

void main() {
  group('AppNotification.isNeighborhoodAlert', () {
    test('a fire_alert carrying an area_id is answerable', () {
      final n = AppNotification.fromMap({
        'id': 'n1',
        'type': 'fire_alert',
        'title': 'Alerto sa Sunog',
        'body': 'May sunog ba sa lugar na ito?',
        'is_read': false,
        'data': {'area_id': 'a1'},
      });

      expect(n.isNeighborhoodAlert, isTrue);
      expect(n.areaId, 'a1');
    });

    test('a fire_alert without an area_id is NOT answerable', () {
      // Showing Report/Ignore here would build a request with a null area_id,
      // which the server rejects — so the buttons must stay hidden.
      final n = AppNotification.fromMap({
        'id': 'n2',
        'type': 'fire_alert',
        'title': 'Alert',
        'body': 'No area attached',
        'is_read': false,
        'data': <String, dynamic>{},
      });

      expect(n.isNeighborhoodAlert, isFalse);
      expect(n.areaId, isNull);
    });

    test('other notification types are not answerable', () {
      for (final type in ['incident_verified', 'dispatch', 'general']) {
        final n = AppNotification.fromMap({
          'id': 'n3',
          'type': type,
          'title': 'Update',
          'body': 'Your report was verified',
          'is_read': true,
          'data': {'area_id': 'a1'},
        });
        expect(n.isNeighborhoodAlert, isFalse, reason: type);
      }
    });

    test('a missing data payload does not throw', () {
      final n = AppNotification.fromMap({
        'id': 'n4',
        'type': 'fire_alert',
        'title': 'Alert',
        'body': 'body',
        'is_read': false,
      });

      expect(n.data, isEmpty);
      expect(n.isNeighborhoodAlert, isFalse);
    });

    test('parses a timestamp when present and tolerates its absence', () {
      final withTime = AppNotification.fromMap({
        'id': 'n5',
        'type': 'fire_alert',
        'title': 't',
        'body': 'b',
        'is_read': false,
        'created_at': '2026-09-04T10:30:00Z',
      });
      expect(withTime.createdAt, isNotNull);

      final without = AppNotification.fromMap({
        'id': 'n6',
        'type': 'general',
        'title': 't',
        'body': 'b',
        'is_read': false,
      });
      expect(without.createdAt, isNull);
    });
  });

  group('neighbourhood response values', () {
    test('match the server enum exactly', () {
      // public.neighborhood_response is ('report', 'ignore'); anything else is
      // rejected by the Literal on NotificationRespondRequest.
      expect(NeighborhoodResponse.report, 'report');
      expect(NeighborhoodResponse.ignore, 'ignore');
    });
  });
}
