import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/location/live_position.dart';
import 'package:replit/navigation/navigation_controller.dart';
import 'package:replit/navigation/routing_service.dart';
import 'package:replit/navigation/nav_route.dart';

import 'navigation_test.dart' as nt;

/// The other way while driving to a fire (PRD v14 §4.9.2).
void main() {
  late DateTime now;
  late List<LatLng> fetchedFrom;
  late List<RouteSet> answers;

  RouteSet set(List<dynamic> routes) => RouteSet(
    routes: parseRoutes(nt.answer(routes.cast())),
    provider: 'mapbox',
    trafficAware: true,
  );

  LiveFix fix(LatLng p) =>
      LiveFix(point: p, time: now, accuracy: 5, speed: 10, heading: 0);

  Future<NavigationController> drive(List<dynamic> first) async {
    answers = [set(first)];
    final nav = NavigationController(
      destination: nt.at(1000, east: 1000),
      mode: TravelMode.driving,
      destinationName: 'the fire',
      arrivedWithinMetres: 100,
      liveAlternatives: true,
      clock: () => now,
      fetch: (from, to, {headingDeg}) async {
        fetchedFrom.add(from);
        return answers.removeAt(0);
      },
    );
    nav.onFix(fix(nt.at(0)));
    await nav.start(nt.at(0));
    nav.setNavigating(true);
    return nav;
  }

  /// From [from] to the fire: [points] after it, two minutes a kilometre.
  ({
    List<LatLng> points,
    List<Map<String, dynamic>> steps,
    double duration,
    String summary,
    List<String>? congestion,
    double? typical,
  })
  way(List<LatLng> points, String name) => (
    points: points,
    steps: [
      nt.step('depart', points.first, name: name, duration: 300),
      nt.step('arrive', points.last),
    ],
    duration: 300.0,
    summary: name,
    congestion: null,
    typical: null,
  );

  setUp(() {
    now = DateTime(2026, 10, 23, 9);
    fetchedFrom = [];
  });

  test(
    'an alternative is offered only while its fork is still ahead',
    () async {
      final nav = await drive([nt.lRoute, nt.longRoute]);
      expect(nav.alternative?.route.summary, 'EDSA');
      nav.onFix(fix(nt.at(500)));
      expect(nav.alternative, isNotNull, reason: 'both still go north here');
      nav.onFix(fix(nt.at(1000, east: 300)));
      expect(nav.alternative, isNull, reason: 'EDSA is behind, 300 m away');
    },
  );

  test(
    'taking it follows it at once; the old route becomes the alternative',
    () async {
      final nav = await drive([nt.lRoute, nt.longRoute]);
      final old = nav.route;
      nav.takeAlternative();
      expect(nav.route!.summary, 'EDSA');
      expect(nav.alternative!.route, same(old));
    },
  );

  test(
    'with no other way left it asks again from here, at most once a '
    'minute, keeping the route followed and adding only another way',
    () async {
      final nav = await drive([nt.lRoute]);
      final followed = nav.route;
      expect(nav.alternative, isNull);
      now = now.add(const Duration(seconds: 30));
      nav.onFix(fix(nt.at(100)));
      expect(fetchedFrom, hasLength(1), reason: 'not within the minute');

      answers.add(
        set([
          way([
            nt.at(200),
            nt.at(1000),
            nt.at(1000, east: 1000),
          ], 'Taft Avenue'),
          way([
            nt.at(200),
            nt.at(200, east: 1000),
            nt.at(1000, east: 1000),
          ], 'Harrison Street'),
        ]),
      );
      now = now.add(const Duration(seconds: 40));
      nav.onFix(fix(nt.at(200)));
      expect(nav.lookingForAlternative, isTrue);
      await pumpEventQueue();
      expect(fetchedFrom.last, nt.at(200));
      expect(nav.lookingForAlternative, isFalse);
      expect(nav.route, same(followed), reason: 'no reroute');
      expect(nav.routes, hasLength(2), reason: 'the same way is not offered');
      expect(nav.alternative!.route.summary, 'Harrison Street');
    },
  );

  test('a lookup that fails leaves the route as it was', () async {
    final nav = await drive([nt.lRoute]);
    now = now.add(const Duration(minutes: 2));
    nav.onFix(fix(nt.at(100))); // answers is empty: the fetch throws
    await pumpEventQueue();
    expect(nav.lookingForAlternative, isFalse);
    expect(nav.problem, isNull);
    expect(nav.routes, hasLength(1));
  });
}
