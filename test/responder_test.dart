import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/location/responder_tracker.dart';
import 'package:replit/screens/responder/responder_status.dart';

/// The Response Team side after v10: location shared "5 s while dispatched"
/// (§6) whichever screen is open, only the controls the server honours for
/// the responder's agency (§2.7.1), and Admin's routing shown (§2.6.2).

/// A location service that hands out streams the test can feed.
class StreamGeo extends GeolocatorPlatform {
  final List<LocationSettings?> settings = [];
  final List<StreamController<Position>> streams = [];

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings.add(locationSettings);
    final c = StreamController<Position>();
    streams.add(c);
    return c.stream;
  }
}

Position at(double lat) => Position(
  latitude: lat,
  longitude: 121.0,
  timestamp: DateTime.now(),
  accuracy: 6,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 90,
  headingAccuracy: 0,
  speed: 8,
  speedAccuracy: 0,
);

void main() {
  group('who is offered what', () {
    test('fire codes are for fire crews', () {
      expect(isFireCrew('fire_volunteer'), isTrue);
      expect(isFireCrew('bfp'), isTrue);
      for (final agency in ['police', 'medical', 'barangay', null]) {
        expect(isFireCrew(agency), isFalse, reason: '$agency');
      }
    });

    test('only a Fire Volunteer responder may ask BFP to raise the alarm', () {
      // Mirrors POST /alarm-requests — anyone else is refused by the server.
      expect(mayRequestAlarm('fire_volunteer'), isTrue);
      for (final agency in ['bfp', 'police', 'medical', 'barangay', null]) {
        expect(mayRequestAlarm(agency), isFalse, reason: '$agency');
      }
    });
  });

  group('routing, as the responder sees it', () {
    const detail = {
      'routes': [
        {'agency': 'medical', 'organization_id': 'org-ems', 'organization_name': 'Pasay EMS'},
        {'agency': 'police', 'organization_id': null, 'organization_name': null},
      ],
    };

    test('a route to my own team says so', () {
      expect(routingLabel(detail, agency: 'medical', orgId: 'org-ems'), 'ROUTED TO YOUR TEAM');
    });

    test('a route to the agency as a whole names the agency', () {
      expect(routingLabel(detail, agency: 'police', orgId: 'org-x'), 'ROUTED TO POLICE');
    });

    test('a route to another team in my agency names that team', () {
      expect(routingLabel(detail, agency: 'medical', orgId: 'org-other'), 'ROUTED TO PASAY EMS');
    });

    test('nothing routed to my agency, no label', () {
      expect(routingLabel(detail, agency: 'barangay'), isNull);
      expect(routingLabel(const {'routes': []}, agency: 'police'), isNull);
    });

    test('a feed summary only knows the agencies', () {
      const summary = {'routed_agencies': ['fire_volunteer']};
      expect(routingLabel(summary, agency: 'fire_volunteer'), 'ROUTED TO FIRE VOLUNTEER');
      expect(routingLabel(summary, agency: 'police'), isNull);
    });
  });

  group('location sharing while dispatched', () {
    final tracker = ResponderTracker.instance;
    late StreamGeo geo;
    late List<Map<String, dynamic>> posted;

    ApiClient server({int status = 200}) => ApiClient(
      client: MockClient((req) async {
        posted.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'message': status == 200 ? 'Location recorded.' : 'No active dispatch.'}),
          status,
        );
      }),
    );

    setUp(() {
      geo = StreamGeo();
      GeolocatorPlatform.instance = geo;
      posted = [];
    });

    // Each test also stops the tracker in its body: flutter_test checks for a
    // pending timer (the five-second beat) before tearDown runs.
    tearDown(() => tracker.stop());

    testWidgets('the first point goes at once, then the latest every five seconds', (tester) async {
      await tester.pumpWidget(const SizedBox());
      tracker.api = server();
      await tracker.start(incidentId: 'a1', dispatchId: 'd1');
      expect(tracker.sharingFor.value, 'a1');

      geo.streams.single.add(at(14.500));
      await tester.pump();
      expect(posted, hasLength(1));
      expect(posted.single['dispatch_id'], 'd1');

      // Three fixes inside one beat: only the newest is sent.
      geo.streams.single
        ..add(at(14.501))
        ..add(at(14.502))
        ..add(at(14.503));
      await tester.pump(const Duration(seconds: 5));
      expect(posted, hasLength(2));
      expect(posted.last['lat'], 14.503);

      await tester.pump(const Duration(seconds: 5));
      expect(posted, hasLength(3), reason: 'the beat keeps going with no new fix');
      await tracker.stop();
    });

    testWidgets('it stops by itself once the dispatch has ended', (tester) async {
      await tester.pumpWidget(const SizedBox());
      tracker.api = server(status: 403); // fire out, or withdrawn
      await tracker.start(incidentId: 'a1', dispatchId: 'd1');
      geo.streams.single.add(at(14.5));
      await tester.pump();
      expect(tracker.isSharing, isFalse);

      await tester.pump(const Duration(seconds: 15));
      expect(posted, hasLength(1), reason: 'nothing more is sent after the refusal');
    });

    testWidgets('opening the incident again does not start a second stream', (tester) async {
      await tester.pumpWidget(const SizedBox());
      tracker.api = server();
      await tracker.start(incidentId: 'a1', dispatchId: 'd1');
      await tracker.start(incidentId: 'a1', dispatchId: 'd1');
      expect(geo.streams, hasLength(1));
      await tracker.stop();
    });

    testWidgets('a refused foreground service still shares while the app is open', (tester) async {
      await tester.pumpWidget(const SizedBox());
      tracker.api = server();
      await tracker.start(incidentId: 'a1', dispatchId: 'd1');
      expect(geo.settings.first, isA<AndroidSettings>());

      geo.streams.first.addError(Exception('foreground service not allowed'));
      await tester.pump();
      expect(geo.settings, hasLength(2));
      expect(geo.settings.last, isNot(isA<AndroidSettings>()));
      expect(tracker.isSharing, isTrue);

      geo.streams.last.add(at(14.5));
      await tester.pump();
      expect(posted, hasLength(1));
      await tracker.stop();
    });
  });
}
