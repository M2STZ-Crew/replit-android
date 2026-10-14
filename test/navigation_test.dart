import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/location/live_position.dart';
import 'package:replit/navigation/instructions.dart';
import 'package:replit/navigation/nav_route.dart';
import 'package:replit/navigation/navigation_controller.dart';
import 'package:replit/navigation/routing_service.dart';

const _start = LatLng(14.5378, 121.0014);
const _mPerDegLat = 110630.0;

/// [north] metres north of the start, [east] metres east.
LatLng at(double north, {double east = 0}) => LatLng(
  _start.latitude + north / _mPerDegLat,
  _start.longitude + east / (_mPerDegLat * 0.968),
);

List<double> _lngLat(LatLng p) => [p.longitude, p.latitude];

Map<String, dynamic> step(
  String type,
  LatLng where, {
  String? modifier,
  String name = '',
  double distance = 0,
  double duration = 0,
  double? bearingAfter,
  int? exit,
}) => {
  'maneuver': {
    'type': type,
    'modifier': ?modifier,
    'location': _lngLat(where),
    'bearing_after': ?bearingAfter,
    'exit': ?exit,
  },
  'name': name,
  'distance': distance,
  'duration': duration,
};

/// An OSRM/Mapbox-shaped answer: one route per entry.
Map<String, dynamic> answer(
  List<
    ({
      List<LatLng> points,
      List<Map<String, dynamic>> steps,
      double duration,
      String summary,
      List<String>? congestion,
      double? typical,
    })
  >
  routes,
) => {
  'code': 'Ok',
  'routes': [
    for (final r in routes)
      {
        'geometry': {
          'type': 'LineString',
          'coordinates': [for (final p in r.points) _lngLat(p)],
        },
        'distance': 0.0,
        'duration': r.duration,
        'duration_typical': ?r.typical,
        'legs': [
          {
            'summary': r.summary,
            'steps': r.steps,
            if (r.congestion != null)
              'annotation': {'congestion': r.congestion},
          },
        ],
      },
  ],
};

/// 1 km north on Taft Avenue, right onto Gil Puyat Avenue, 1 km east to the
/// fire. Two minutes a kilometre.
final lRoute = (
  points: [at(0), at(500), at(1000), at(1000, east: 500), at(1000, east: 1000)],
  steps: [
    step(
      'depart',
      at(0),
      name: 'Taft Avenue',
      distance: 1000,
      duration: 120,
      bearingAfter: 0,
    ),
    step(
      'turn',
      at(1000),
      modifier: 'right',
      name: 'Gil Puyat Avenue',
      distance: 1000,
      duration: 120,
      bearingAfter: 90,
    ),
    step('arrive', at(1000, east: 1000)),
  ],
  duration: 240.0,
  summary: 'Taft Avenue, Gil Puyat Avenue',
  congestion: <String>['low', 'moderate', 'heavy', 'unknown'],
  typical: 200.0,
);

/// The same trip the long way: 3 km straight north, slower.
final longRoute = (
  points: [at(0), at(1500), at(3000)],
  steps: [
    step('depart', at(0), name: 'EDSA', distance: 3000, duration: 400),
    step('arrive', at(3000)),
  ],
  duration: 400.0,
  summary: 'EDSA',
  congestion: null,
  typical: null,
);

void main() {
  // ------------------------------------------------------------ parser ---
  group('reading a route answer', () {
    test('every route, its steps placed along it, and its traffic', () {
      final routes = parseRoutes(answer([lRoute, longRoute]));
      expect(routes, hasLength(2));
      final r = routes.first;
      expect(r.length, closeTo(2000, 15));
      expect(r.duration, 240);
      expect(r.typicalDuration, 200);
      expect(r.summary, 'Taft Avenue, Gil Puyat Avenue');
      expect([for (final s in r.steps) s.type], ['depart', 'turn', 'arrive']);
      expect(r.steps[1].at, closeTo(1000, 10));
      expect(r.steps[2].at, closeTo(r.length, 1));
      expect(r.steps[1].modifier, 'right');
      expect(r.steps[1].name, 'Gil Puyat Avenue');
      expect(r.congestion, [
        Congestion.low,
        Congestion.moderate,
        Congestion.heavy,
        Congestion.unknown,
      ]);
      expect(r.hasTraffic, isTrue);
      expect(routes[1].congestion, isNull);
      expect(routes[1].hasTraffic, isFalse);
    });

    test('a walker on a driving network is timed at walking pace', () {
      final r = parseRoutes(answer([lRoute]), walkingPace: kWalkingPace).single;
      expect(r.duration, closeTo(0 / kWalkingPace, 1), reason: 'distance 0');
      expect(r.steps.first.duration, closeTo(1000 / kWalkingPace, 1));
      expect(r.typicalDuration, isNull);
    });

    test('a road with several names is called by the first', () {
      final json = answer([lRoute]);
      // A copy of the steps: the fixture is shared with the other tests.
      final leg = (json['routes'] as List).first['legs'][0] as Map;
      leg['steps'] = [
        for (final s in leg['steps'] as List)
          Map<String, dynamic>.of(s as Map<String, dynamic>),
      ];
      (leg['steps'] as List)[1]['name'] =
          'A. Arnaiz Avenue; Antonio S. Arnaiz Avenue';
      expect(parseRoutes(json).single.steps[1].name, 'A. Arnaiz Avenue');
    });

    test('a route without a line is dropped, not drawn', () {
      final json = answer([lRoute]);
      (json['routes'] as List).first['geometry']['coordinates'] = [
        _lngLat(at(0)),
      ];
      expect(parseRoutes(json), isEmpty);
    });

    test('a straight line stands in, marked as one, with no turns', () {
      final line = NavRoute.straight(at(0), at(1000), pace: 10);
      expect(line.approximate, isTrue);
      expect(line.steps, isEmpty);
      expect(line.duration, closeTo(100, 2));
    });
  });

  // ------------------------------------------------------ instructions ---
  group('what the banner and voice say', () {
    NavStep s(
      String type, {
      String? modifier,
      String name = 'Taft Avenue',
      int? exit,
      double? bearing,
    }) => NavStep(
      type: type,
      modifier: modifier,
      name: name,
      exit: exit,
      bearingAfter: bearing,
      location: at(0),
      distance: 0,
      duration: 0,
      at: 0,
    );

    test('turns, by how sharp and which way', () {
      expect(
        instructionFor(s('turn', modifier: 'left')),
        'Turn left onto Taft Avenue',
      );
      expect(
        instructionFor(s('turn', modifier: 'slight right')),
        'Bear right onto Taft Avenue',
      );
      expect(
        instructionFor(s('turn', modifier: 'sharp left', name: '')),
        'Turn sharp left',
      );
      expect(
        instructionFor(s('continue', modifier: 'uturn')),
        'Make a U-turn onto Taft Avenue',
      );
      expect(
        instructionFor(s('end of road', modifier: 'right')),
        'At the end of the road, turn right onto Taft Avenue',
      );
      expect(
        instructionFor(s('fork', modifier: 'slight left')),
        'Keep left at the fork onto Taft Avenue',
      );
      expect(
        instructionFor(s('roundabout', exit: 2)),
        'At the roundabout, take the second exit onto Taft Avenue',
      );
      expect(instructionFor(s('new name')), 'Continue onto Taft Avenue');
    });

    test('departure says which way, arrival says where', () {
      expect(
        instructionFor(s('depart', bearing: 2)),
        'Head north on Taft Avenue',
      );
      expect(
        instructionFor(s('arrive'), destination: 'the fire'),
        'You have arrived at the fire',
      );
    });

    test('distances are rounded to what is worth saying', () {
      expect(bannerDistance(47), '50 m');
      expect(bannerDistance(238), '250 m');
      expect(bannerDistance(1240), '1.2 km');
      expect(spokenDistance(5), '10 metres');
      expect(
        spokenInstruction(s('turn', modifier: 'right'), 212),
        'In 200 metres, turn right onto Taft Avenue',
      );
      expect(
        spokenInstruction(s('arrive'), 95, destination: 'the fire'),
        'In 100 metres, you will arrive at the fire',
      );
    });
  });

  // ---------------------------------------------------------- service ---
  group('where routes come from', () {
    late List<Uri> asked;

    RoutingService service({
      String token = 'pk.test',
      int mapboxStatus = 200,
      int osrmStatus = 200,
      Map<String, dynamic>? body,
    }) {
      return RoutingService(
        mapboxToken: token,
        client: MockClient((req) async {
          asked.add(req.url);
          final mapbox = req.url.host == 'api.mapbox.com';
          final status = mapbox ? mapboxStatus : osrmStatus;
          if (status != 200) return http.Response('{"message":"no"}', status);
          return http.Response(jsonEncode(body ?? answer([lRoute])), 200);
        }),
      );
    }

    setUp(() => asked = []);

    test('Mapbox driving-traffic first: alternatives, steps, truck width, '
        'the way the truck is heading', () async {
      final set = await service().routes(
        at(0),
        at(2000),
        mode: TravelMode.driving,
        headingDeg: 92.4,
      );
      final uri = asked.single;
      expect(uri.host, 'api.mapbox.com');
      expect(uri.path, contains('/mapbox/driving-traffic/'));
      expect(uri.queryParameters['alternatives'], 'true');
      expect(uri.queryParameters['steps'], 'true');
      expect(uri.queryParameters['annotations'], 'congestion,duration');
      expect(uri.queryParameters['max_width'], '2.5');
      expect(uri.queryParameters['bearings'], '92,45;');
      expect(set.provider, 'mapbox');
      expect(set.trafficAware, isTrue);
    });

    test('no traffic in the answer, no claim of traffic', () async {
      final set = await service(
        body: answer([longRoute]),
      ).routes(at(0), at(3000), mode: TravelMode.driving);
      expect(set.trafficAware, isFalse);
    });

    test(
      'Mapbox refusing falls back to OSRM, which never claims traffic',
      () async {
        final set = await service(
          mapboxStatus: 401,
        ).routes(at(0), at(2000), mode: TravelMode.driving);
        expect(asked.map((u) => u.host), [
          'api.mapbox.com',
          'router.project-osrm.org',
        ]);
        expect(set.provider, 'osrm');
        expect(set.trafficAware, isFalse);
      },
    );

    test('without a token, OSRM only', () async {
      await service(
        token: '',
      ).routes(at(0), at(2000), mode: TravelMode.driving);
      expect(asked.single.host, 'router.project-osrm.org');
    });

    test(
      'walking asks Mapbox for walking, and OSRM times it at walking pace',
      () async {
        await service().routes(at(0), at(2000), mode: TravelMode.walking);
        expect(asked.single.path, contains('/mapbox/walking/'));
        expect(asked.single.queryParameters.containsKey('max_width'), isFalse);

        asked.clear();
        final set = await service(
          mapboxStatus: 500,
        ).routes(at(0), at(2000), mode: TravelMode.walking);
        expect(
          set.routes.first.steps.first.duration,
          closeTo(1000 / kWalkingPace, 1),
        );
      },
    );

    test('nobody answering is an error, never an invented route', () async {
      expect(
        () => service(
          mapboxStatus: 503,
          osrmStatus: 503,
        ).routes(at(0), at(2000), mode: TravelMode.driving),
        throwsA(isA<RoutingException>()),
      );
    });
  });

  // ------------------------------------------------------- controller ---
  group('following a route', () {
    late DateTime now;
    late List<({LatLng from, LatLng to, double? heading})> fetches;
    late List<Future<RouteSet> Function()> answers;
    late NavigationController nav;
    late List<String> said;

    RouteSet set(List<dynamic> routes, {bool traffic = true}) => RouteSet(
      routes: parseRoutes(answer(routes.cast())),
      provider: 'mapbox',
      trafficAware: traffic,
    );

    LiveFix fix(
      LatLng p, {
      double accuracy = 5,
      double speed = 10,
      double heading = 0,
    }) => LiveFix(
      point: p,
      time: now,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
    );

    setUp(() async {
      now = DateTime(2026, 10, 15, 14);
      fetches = [];
      answers = [];
      said = [];
      nav = NavigationController(
        destination: at(1000, east: 1000),
        mode: TravelMode.driving,
        destinationName: 'the fire',
        arrivedWithinMetres: 100,
        clock: () => now,
        fetch: (from, to, {headingDeg}) {
          fetches.add((from: from, to: to, heading: headingDeg));
          return answers.isEmpty
              ? Future.value(set([lRoute]))
              : answers.removeAt(0)();
        },
      );
      nav.announcements.listen(said.add);
      nav.onFix(fix(at(0)));
      await nav.start(at(0));
    });

    tearDown(() => nav.dispose());

    test('the next maneuver, its distance, and what is left', () {
      nav.onFix(fix(at(400)));
      final p = nav.progress!;
      expect(nav.route!.steps[p.nextStep!].name, 'Gil Puyat Avenue');
      expect(p.metresToNext, closeTo(600, 10));
      expect(p.remainingMetres, closeTo(1600, 15));
      expect(p.remainingSeconds, closeTo(72 + 120, 3));
      expect(nav.eta, now.add(Duration(seconds: p.remainingSeconds.round())));
    });

    test('past the turn the next maneuver is arrival, and noise behind the '
        'corner does not take it back', () {
      nav.onFix(fix(at(1000, east: 30)));
      expect(nav.route!.steps[nav.progress!.nextStep!].type, 'arrive');
      nav.onFix(fix(at(985)));
      expect(nav.route!.steps[nav.progress!.nextStep!].type, 'arrive');
    });

    test('the fastest route is chosen; another can be', () async {
      answers.add(() async => set([longRoute, lRoute]));
      await nav.retry();
      expect(nav.routes, hasLength(2));
      expect(nav.fastest, 1);
      expect(nav.active, 1, reason: 'fastest, not first');
      nav.select(0);
      expect(nav.route!.summary, 'EDSA');
      expect(nav.progress, isNotNull, reason: 'placed on the new one at once');
    });

    test('leaving the route: two usable fixes three seconds apart reroute, '
        'from where they are and the way they are going', () {
      now = now.add(const Duration(seconds: 10));
      nav.onFix(fix(at(500, east: 150), heading: 90));
      expect(fetches, hasLength(1), reason: 'one stray fix is GPS noise');
      now = now.add(const Duration(seconds: 1));
      nav.onFix(fix(at(510, east: 160), heading: 90));
      expect(fetches, hasLength(1), reason: 'not yet three seconds');
      now = now.add(const Duration(seconds: 3));
      nav.onFix(fix(at(520, east: 170), heading: 90));
      expect(fetches, hasLength(2));
      expect(fetches.last.from, at(520, east: 170));
      expect(fetches.last.heading, 90);
    });

    test('poor GPS is neither a wrong turn nor proof of being on route', () {
      now = now.add(const Duration(seconds: 10));
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(seconds: 2));
        nav.onFix(fix(at(500, east: 150), accuracy: 120));
      }
      expect(fetches, hasLength(1));
      expect(nav.weakSignal, isTrue);
      expect(nav.offRoute, isFalse);
    });

    test(
      'a fix within its accuracy of the road is drawn on the road',
      () async {
        final shown = <NavDisplay>[];
        nav.displays.listen(shown.add);
        nav.setNavigating(true);
        nav.onFix(fix(at(400, east: 6)));
        nav.onFix(fix(at(400, east: 60), accuracy: 5));
        await Future<void>.delayed(Duration.zero);
        expect(shown[0].point.longitude, closeTo(at(400).longitude, 1e-6));
        expect(
          shown[0].travelHeadingDeg,
          closeTo(0, 1),
          reason: 'road bearing',
        );
        expect(
          shown[1].point,
          at(400, east: 60),
          reason: 'a real wrong turn shows',
        );
      },
    );

    test(
      'an answer that comes back late for a superseded request is dropped',
      () async {
        final late = Completer<RouteSet>();
        answers
          ..add(() => late.future)
          ..add(() async => set([longRoute]));
        now = now.add(const Duration(seconds: 10));
        unawaited(nav.retry()); // the first, slow
        await nav.setDestination(at(3000)); // supersedes it
        expect(nav.route!.summary, 'EDSA');
        late.complete(set([lRoute]));
        await Future<void>.delayed(Duration.zero);
        expect(nav.route!.summary, 'EDSA', reason: 'the newer route stays');
        expect(fetches.last.to, at(3000));
      },
    );

    test(
      'a failed reroute keeps the last route, says so, and backs off',
      () async {
        answers.add(() async => throw const RoutingException('offline'));
        now = now.add(const Duration(seconds: 10));
        await nav.retry();
        expect(nav.route!.summary, 'Taft Avenue, Gil Puyat Avenue');
        expect(nav.problem, contains('Could not update the route'));
        // Off the route again at once, for 3 s: still inside the 5 s backoff.
        for (final s in [1.0, 2.5, 4.0]) {
          nav.onFix(
            LiveFix(
              point: at(500, east: 150),
              time: now.add(Duration(milliseconds: (s * 1000).round())),
              accuracy: 5,
            ),
          );
        }
        expect(fetches, hasLength(2), reason: 'no request inside the backoff');
        // Past it, the next off-route fix asks again.
        now = now.add(const Duration(seconds: 6));
        nav.onFix(fix(at(500, east: 150)));
        expect(fetches, hasLength(3));
      },
    );

    test('the voice: the first instruction, each turn ahead and at it, and '
        'arrival, each once', () async {
      // Announcements are a stream: let each one arrive before reading it.
      Future<void> heard() => Future<void>.delayed(Duration.zero);
      nav.setNavigating(true);
      await heard();
      expect(
        said.single,
        'In 1.0 kilometres, turn right onto Gil Puyat Avenue',
      );
      nav.onFix(fix(at(760)));
      nav.onFix(fix(at(780)));
      await heard();
      expect(said.last, 'In 250 metres, turn right onto Gil Puyat Avenue.');
      nav.onFix(fix(at(970)));
      await heard();
      expect(said.last, 'Turn right onto Gil Puyat Avenue.');
      nav.onFix(fix(at(1000, east: 930)));
      await heard();
      expect(said.last, 'You have arrived at the fire.');
      expect(nav.arrived, isTrue);
      expect(said.toSet().length, said.length, reason: 'nothing twice');
    });

    test('nothing is said before Start', () async {
      nav.onFix(fix(at(970)));
      await Future<void>.delayed(Duration.zero);
      expect(said, isEmpty);
    });
  });

  testWidgets('no road route at first: a straight line, said to be one, and '
      'a real route tried again', (tester) async {
    var calls = 0;
    final nav = NavigationController(
      destination: at(2000),
      mode: TravelMode.driving,
      destinationName: 'the fire',
      arrivedWithinMetres: 100,
      fetch: (from, to, {headingDeg}) async {
        calls++;
        if (calls == 1) throw const RoutingException('offline');
        return RouteSet(
          routes: parseRoutes(answer([longRoute])),
          provider: 'osrm',
          trafficAware: false,
        );
      },
    );
    addTearDown(nav.dispose);
    await nav.start(at(0));
    expect(nav.route!.approximate, isTrue);
    expect(nav.problem, contains('straight line'));
    await tester.pump(const Duration(seconds: 6));
    expect(calls, 2);
    expect(nav.route!.approximate, isFalse);
    expect(nav.problem, isNull);
  });
}
