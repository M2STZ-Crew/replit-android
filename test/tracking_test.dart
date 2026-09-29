import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/api/tracking_socket.dart';
import 'package:replit/location/live_position.dart';
import 'package:replit/models/tracking.dart';

/// The pieces under Track It Live and the live distance: how a distance reads,
/// how a snapshot is read, and when a truck's position counts as lost.
void main() {
  group('distance', () {
    test('metres under a kilometre, kilometres from there', () {
      expect(formatDistance(450), '450 m');
      expect(formatDistance(999.4), '999 m');
      expect(formatDistance(999.6), '1.0 km', reason: 'never "1000 m"');
      expect(formatDistance(1349), '1.3 km');
      expect(distanceAway(1300), '1.3 km away');
      expect(distanceAway(80), '80 m away');
    });

    test('is measured between two points, not hardcoded', () {
      const fire = LatLng(14.5380, 121.0016);
      const here = LatLng(14.5580, 121.0016); // ~2.2 km north
      expect(metresBetween(fire, here), closeTo(2212, 15));
      expect(distanceAway(metresBetween(fire, here)), '2.2 km away');
    });
  });

  group('snapshot', () {
    Map<String, dynamic> json({List<Map<String, dynamic>>? units}) => {
      'area_id': 'a1',
      'designation': 'Area 1.2',
      'status': 'en_route',
      'centroid_lat': 14.538,
      'centroid_lng': 121.0016,
      'arrival_radius_m': 100,
      'stale_after_seconds': 60,
      'generated_at': '2026-09-29T08:00:00Z',
      'responders':
          units ??
          [
            {
              'key': 'unit-1',
              'label': 'Apollo',
              'organization': 'Hercules Fire Brigade',
              'agency': 'fire_volunteer',
              'lat': 14.54,
              'lng': 121.0,
              'heading_deg': 180,
              'updated_at': '2026-09-29T07:59:50Z',
              'stale': false,
            },
            {'key': 'unit-2', 'label': 'Unit 2', 'stale': true},
          ],
    };

    test('reads the units the server sends', () {
      final s = TrackingSnapshot.tryParse(json())!;
      expect(s.status, 'en_route');
      expect(s.centre, const LatLng(14.538, 121.0016));
      expect(s.arrivalRadiusMetres, 100);
      expect([for (final u in s.units) u.label], ['Apollo', 'Unit 2']);
      expect(s.units.first.organization, 'Hercules Fire Brigade');
      expect(s.units.first.position, const LatLng(14.54, 121.0));
      expect(s.units.last.position, isNull, reason: 'no fix yet');
    });

    test('anything that is not a snapshot is ignored, not a crash', () {
      expect(
        TrackingSnapshot.tryParse({'id': 'a1', 'status': 'en_route'}),
        isNull,
      );
      expect(TrackingSnapshot.tryParse('<html>'), isNull);
      expect(TrackingSnapshot.tryParse(null), isNull);
    });

    test('a position ages on after the snapshot arrived', () {
      final received = DateTime(2026, 9, 29, 16);
      final s = TrackingSnapshot.tryParse(json(), receivedAt: received)!;
      final apollo = s.units.first;
      // 10 s old when the server made the snapshot.
      expect(
        s.isStale(apollo, now: received.add(const Duration(seconds: 40))),
        isFalse,
      );
      expect(
        s.isStale(apollo, now: received.add(const Duration(seconds: 51))),
        isTrue,
        reason: 'no new snapshot comes when a phone goes quiet',
      );
    });

    test("age does not depend on this phone's clock being right", () {
      // The phone thinks it is 2020; the server's own times still say 10 s.
      final wrongClock = DateTime(2020);
      final s = TrackingSnapshot.tryParse(json(), receivedAt: wrongClock)!;
      expect(
        s.ageOf(s.units.first, now: wrongClock.add(const Duration(seconds: 5))),
        const Duration(seconds: 15),
      );
    });

    test('the server saying stale, or no position, is stale', () {
      final s = TrackingSnapshot.tryParse(json())!;
      expect(s.isStale(s.units.last), isTrue);
    });
  });

  test('the socket is the API host with ws://, at /ws', () {
    expect(TrackingSocket.socketUri().scheme, anyOf('ws', 'wss'));
    expect(TrackingSocket.socketUri().path, endsWith('/ws'));
  });
}
