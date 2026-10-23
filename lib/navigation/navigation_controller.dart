import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../location/live_position.dart';
import '../location/route_progress.dart';
import 'instructions.dart';
import 'nav_route.dart';
import 'routing_service.dart';

/// Fetches routes for a trip. [headingDeg] is the direction of travel when
/// the phone is moving. Throws [RoutingException] when there is none.
typedef RouteFetch =
    Future<RouteSet> Function(LatLng from, LatLng to, {double? headingDeg});

/// Where the person is on the active route, recomputed with every fix.
class NavProgress {
  const NavProgress({
    required this.along,
    required this.offRoute,
    required this.remainingMetres,
    required this.remainingSeconds,
    required this.nextStep,
    required this.metresToNext,
  });

  /// Metres from the start of the route to where the person is placed on it.
  final double along;

  /// Metres between the person and the route line.
  final double offRoute;
  final double remainingMetres;
  final double remainingSeconds;

  /// Index of the next maneuver in the route's steps, or null when the route
  /// has none (a straight line).
  final int? nextStep;

  /// Metres to that maneuver.
  final double metresToNext;
}

/// What the map should draw for "you": the point (placed on the road when the
/// fix agrees with it), how sure it is, and the direction of travel while
/// moving (null when still, so the compass turns the map instead).
class NavDisplay {
  const NavDisplay(this.point, this.accuracy, this.travelHeadingDeg);
  final LatLng point;
  final double? accuracy;
  final double? travelHeadingDeg;
}

/// Turn-by-turn navigation state (v1.12.9) — kept apart from the map that
/// draws it, the service that routes it, and the GPS that feeds it.
///
/// - **Progress.** Each fix is placed on the active route, searching near
///   where the last one was placed so a road passing close to another part of
///   the route cannot pull the person backwards or forwards along it. The next
///   maneuver only ever moves forward until the route changes. Remaining
///   time is the provider's own per-step times (traffic-aware with Mapbox).
/// - **Leaving the route.** Off by more than the larger of 35 m and the fix's
///   own accuracy (capped at 80 m), on two usable fixes at least three seconds
///   apart, asks for a new route from where they are. A fix worse than 50 m
///   neither counts nor clears the count: poor GPS is not a wrong turn.
/// - **One request at a time, latest wins.** A routine reroute waits for the
///   one in flight; a destination change or a manual retry supersedes it, and
///   whatever answers late for a superseded request is dropped, so an old
///   route can never replace a newer one.
/// - **Failures.** The last good route stays on screen with [problem] saying
///   it could not be updated; retries back off 5, 10, 20, 40, 60 s. Before any
///   road route exists, a straight line marked [NavRoute.approximate] stands
///   in, with no turns, and a real route is retried on the same schedule.
/// - **Voice.** [announcements] says each maneuver twice — once ahead (300 m
///   driving, 60 m walking) and once at it — and arrival once.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required LatLng destination,
    required this.fetch,
    required this.mode,
    required this.destinationName,
    required this.arrivedWithinMetres,
    DateTime Function()? clock,
  }) : _destination = destination,
       _clock = clock ?? DateTime.now;

  final RouteFetch fetch;
  final TravelMode mode;

  /// How the voice and banner name where this ends ("the fire").
  final String destinationName;

  /// This close to the destination counts as there.
  final double arrivedWithinMetres;
  final DateTime Function() _clock;

  // ------------------------------------------------------------ public ---
  LatLng get destination => _destination;
  LatLng _destination;

  /// Every route from the last answer, recommended first; [active] is the
  /// one being followed.
  List<NavRoute> get routes => _routes;
  List<NavRoute> _routes = const [];
  int get active => _active;
  int _active = 0;
  NavRoute? get route => _routes.isEmpty ? null : _routes[_active];

  /// The index of the quickest route, labelled "Fastest".
  int get fastest {
    var best = 0;
    for (var i = 1; i < _routes.length; i++) {
      if (_routes[i].duration < _routes[best].duration) best = i;
    }
    return best;
  }

  /// The index of the shortest route by distance, labelled "Shortest" when
  /// it is not also the fastest.
  int get shortest {
    var best = 0;
    for (var i = 1; i < _routes.length; i++) {
      if (_routes[i].length < _routes[best].length) best = i;
    }
    return best;
  }

  /// Who routed it, and whether its times include live traffic.
  String? get provider => _provider;
  String? _provider;
  bool get trafficAware => _trafficAware;
  bool _trafficAware = false;

  bool get navigating => _navigating;
  bool _navigating = false;
  bool get arrived => _arrived;
  bool _arrived = false;

  /// A first route is being fetched.
  bool get loading => _loading;
  bool _loading = false;

  /// A new route is being fetched while the old one stays up.
  bool get rerouting => _rerouting;
  bool _rerouting = false;

  /// What went wrong with routing, in words, while it is still wrong.
  String? get problem => _problem;
  String? _problem;

  NavProgress? get progress => _progress;
  NavProgress? _progress;
  LiveFix? get lastFix => _lastFix;
  LiveFix? _lastFix;

  /// When they will arrive, by the active route's remaining time.
  DateTime? get eta {
    final p = _progress;
    if (p == null) return null;
    return _clock().add(Duration(seconds: p.remainingSeconds.round()));
  }

  /// Poor GPS: the last fix was worse than 50 m.
  bool get weakSignal => (_lastFix?.accuracy ?? 0) > _usableAccuracy;

  /// Where to draw the person, each fix.
  Stream<NavDisplay> get displays => _displays.stream;
  final StreamController<NavDisplay> _displays =
      StreamController<NavDisplay>.broadcast();

  /// What the voice should say, as it happens.
  Stream<String> get announcements => _announcements.stream;
  final StreamController<String> _announcements =
      StreamController<String>.broadcast();

  // ----------------------------------------------------------- tuning ---
  static const double _minOffRoute = 35;
  static const double _maxOffRoute = 80;
  static const double _usableAccuracy = 50;
  static const Duration _offRouteFor = Duration(seconds: 3);
  static const Duration _rerouteGap = Duration(seconds: 8);

  /// Moving at least this fast (m/s, about 3 km/h) the direction of travel
  /// turns the map; slower, the compass does (PRD v12 §4.9.4).
  static const double movingSpeed = 0.83;

  double get _aheadMetres => mode == TravelMode.driving ? 300 : 60;
  double get _atMetres => mode == TravelMode.driving ? 50 : 15;

  // ---------------------------------------------------------- private ---
  int _generation = 0;
  int _seq = 0;
  bool _inFlight = false;
  int _failures = 0;
  DateTime? _nextAttempt;
  Timer? _retry;
  int? _segment;
  int _next = 1;
  DateTime? _offSince;
  int _offCount = 0;
  final Set<String> _said = {};
  bool _disposed = false;

  /// The first route, from [from].
  Future<void> start(LatLng from, {double? headingDeg}) =>
      _request(from, headingDeg: headingDeg, force: true, first: true);

  /// Follow route [index] instead.
  void select(int index) {
    if (index < 0 || index >= _routes.length || index == _active) return;
    _active = index;
    _resetTracking();
    _replace();
    notifyListeners();
  }

  /// Start or stop turn-by-turn guidance on the active route.
  void setNavigating(bool on) {
    if (on == _navigating) return;
    _navigating = on;
    if (on && _progress != null && route != null) _announceStart();
    notifyListeners();
  }

  /// Fetch again now, superseding anything in flight (the Retry button).
  Future<void> retry() {
    final from = _lastFix?.point;
    if (from == null) return Future.value();
    return _request(from, headingDeg: _travelHeading(_lastFix), force: true);
  }

  /// The incident moved (more reports joined it): route to the new point.
  Future<void> setDestination(LatLng to) {
    _destination = to;
    _arrived = false;
    final from = _lastFix?.point;
    notifyListeners();
    if (from == null) return Future.value();
    return _request(from, headingDeg: _travelHeading(_lastFix), force: true);
  }

  /// A new GPS fix.
  void onFix(LiveFix fix) {
    if (_disposed) return;
    _lastFix = fix;
    final route = this.route;
    if (route == null) {
      _displays.add(NavDisplay(fix.point, fix.accuracy, _travelHeading(fix)));
      notifyListeners();
      return;
    }
    final placed = _place(route, fix.point);
    final metresLeft = const Distance().as(
      LengthUnit.Meter,
      fix.point,
      _destination,
    );
    if (!_arrived && metresLeft <= arrivedWithinMetres) {
      _arrived = true;
      _say('arrived', 'You have arrived at $destinationName.');
    }
    _progress = placed;
    _displays.add(_display(route, placed, fix));
    if (!_arrived) {
      if (!route.approximate) {
        _watchOffRoute(placed, fix);
        if (_navigating) _announceNext(route, placed);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    unawaited(_displays.close());
    unawaited(_announcements.close());
    super.dispose();
  }

  // ---------------------------------------------------------- routing ---
  Future<void> _request(
    LatLng from, {
    double? headingDeg,
    bool force = false,
    bool first = false,
  }) async {
    if (_disposed) return;
    if (_inFlight && !force) return;
    final seq = ++_seq;
    _inFlight = true;
    _retry?.cancel();
    if (first || _routes.isEmpty || route!.approximate) {
      _loading = _routes.isEmpty;
    } else {
      _rerouting = true;
    }
    notifyListeners();
    try {
      final set = await fetch(from, _destination, headingDeg: headingDeg);
      if (_disposed || seq != _seq) return; // superseded: drop it
      final rerouted = _routes.isNotEmpty && !route!.approximate;
      _routes = set.routes;
      _provider = set.provider;
      _trafficAware = set.trafficAware;
      _active = fastest;
      _failures = 0;
      _problem = null;
      _nextAttempt = _clock().add(_rerouteGap);
      _resetTracking();
      _replace();
      if (rerouted && _navigating) _say('rerouted', 'Route updated.');
    } catch (e) {
      if (_disposed || seq != _seq) return;
      _failures++;
      final wait = _backoff(_failures);
      _nextAttempt = _clock().add(wait);
      if (_routes.isEmpty) {
        // Nothing to show yet: a straight line, said to be one, while a real
        // route is retried.
        _routes = [
          NavRoute.straight(
            from,
            _destination,
            pace: mode == TravelMode.driving ? 30000 / 3600 : kWalkingPace,
          ),
        ];
        _active = 0;
        _provider = null;
        _trafficAware = false;
        _resetTracking();
        _replace();
      }
      _problem = route!.approximate
          ? 'No road route yet — showing a straight line. Trying again.'
          : 'Could not update the route. Showing the last one; trying again.';
      _retry = Timer(wait, () {
        final last = _lastFix?.point ?? from;
        unawaited(_request(last, headingDeg: _travelHeading(_lastFix)));
      });
    } finally {
      if (!_disposed && seq == _seq) {
        _inFlight = false;
        _loading = false;
        _rerouting = false;
        notifyListeners();
      }
    }
  }

  static Duration _backoff(int failures) =>
      Duration(seconds: math.min(60, 5 * math.pow(2, failures - 1).toInt()));

  /// The route changed: forget where the person was on the old one, and
  /// place the latest fix on the new one at once.
  void _resetTracking() {
    _generation++;
    _segment = null;
    _next = 1;
    _offSince = null;
    _offCount = 0;
    _progress = null;
  }

  void _replace() {
    final fix = _lastFix;
    final route = this.route;
    if (fix == null || route == null) return;
    _progress = _place(route, fix.point);
    _displays.add(_display(route, _progress!, fix));
    if (_navigating && !_arrived) _announceStart();
  }

  // --------------------------------------------------------- tracking ---
  NavProgress _place(NavRoute route, LatLng here) {
    final points = route.points;
    final last = _segment;
    var p = last == null
        ? RouteProgress.of(points, here)
        : RouteProgress.of(
            points,
            here,
            fromSegment: last - 3,
            toSegment: last + 60,
          );
    if (last != null && p.offRouteMetres > _minOffRoute) {
      // Not near where they were: they may have jumped (a GPS outage, a
      // tunnel). Take the whole route if it fits clearly better.
      final whole = RouteProgress.of(points, here);
      if (whole.offRouteMetres + 10 < p.offRouteMetres) p = whole;
    }
    _segment = p.segment;
    final along =
        route.along[p.segment] +
        const Distance(
          roundResult: false,
        ).as(LengthUnit.Meter, points[p.segment], p.onRoute);
    final remaining = math.max(0.0, route.length - along);

    final steps = route.steps;
    int? next;
    var toNext = remaining;
    var seconds = route.length == 0
        ? 0.0
        : route.duration * remaining / route.length;
    if (steps.length > 1) {
      // The next maneuver ahead, never one already passed.
      var k = _next.clamp(1, steps.length - 1);
      while (k < steps.length - 1 && steps[k].at <= along + 3) {
        k++;
      }
      _next = k;
      next = k;
      toNext = math.max(0, steps[k].at - along);
      final current = steps[k - 1];
      final span = steps[k].at - current.at;
      final share = span <= 0 ? 0.0 : (toNext / span).clamp(0.0, 1.0);
      seconds = current.duration * share;
      for (var j = k; j < steps.length; j++) {
        seconds += steps[j].duration;
      }
    }
    return NavProgress(
      along: along,
      offRoute: p.offRouteMetres,
      remainingMetres: remaining,
      remainingSeconds: seconds,
      nextStep: next,
      metresToNext: toNext,
    );
  }

  /// On the road when the fix agrees with it: within the smaller of 20 m and
  /// the fix's accuracy (8 m at least), with a fix better than 30 m. Anything
  /// else is drawn where the GPS says, so a real wrong turn shows.
  NavDisplay _display(NavRoute route, NavProgress p, LiveFix fix) {
    final accuracy = fix.accuracy ?? 15;
    final snap =
        _navigating &&
        !route.approximate &&
        accuracy <= 30 &&
        p.offRoute <= math.max(8, math.min(20, accuracy));
    if (!snap) {
      return NavDisplay(fix.point, fix.accuracy, _travelHeading(fix));
    }
    final seg = _segment ?? 0;
    final moving = (fix.speed ?? 0) >= movingSpeed;
    return NavDisplay(
      _pointAt(route, p.along),
      fix.accuracy,
      // Moving along the road: the road's own direction, steadier than GPS.
      moving ? _bearing(route.points[seg], route.points[seg + 1]) : null,
    );
  }

  LatLng _pointAt(NavRoute route, double along) {
    final seg = (_segment ?? 0).clamp(0, route.points.length - 2);
    final a = route.points[seg];
    final b = route.points[seg + 1];
    final len = route.along[seg + 1] - route.along[seg];
    final t = len <= 0
        ? 0.0
        : ((along - route.along[seg]) / len).clamp(0.0, 1.0);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  static double? _travelHeading(LiveFix? fix) {
    if (fix == null) return null;
    if ((fix.speed ?? 0) < movingSpeed) return null;
    return fix.heading;
  }

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _watchOffRoute(NavProgress p, LiveFix fix) {
    final accuracy = fix.accuracy ?? 15;
    if (accuracy > _usableAccuracy) return; // poor GPS: neither way
    final limit = math.min(
      _maxOffRoute,
      math.max(_minOffRoute, accuracy * 1.5),
    );
    if (p.offRoute <= limit) {
      _offSince = null;
      _offCount = 0;
      return;
    }
    _offSince ??= fix.time;
    _offCount++;
    final long = fix.time.difference(_offSince!) >= _offRouteFor;
    final allowed = _nextAttempt == null || !_clock().isBefore(_nextAttempt!);
    if (_offCount >= 2 && long && allowed && !_inFlight) {
      _offSince = null;
      _offCount = 0;
      unawaited(_request(fix.point, headingDeg: _travelHeading(fix)));
    }
  }

  /// Off the route right now, by the same measure that triggers a reroute.
  bool get offRoute {
    final p = _progress;
    final r = route;
    if (p == null || r == null || r.approximate) return false;
    final accuracy = _lastFix?.accuracy ?? 15;
    if (accuracy > _usableAccuracy) return false;
    return p.offRoute >
        math.min(_maxOffRoute, math.max(_minOffRoute, accuracy * 1.5));
  }

  // ------------------------------------------------------------ voice ---
  void _announceStart() {
    final route = this.route;
    final p = _progress;
    if (route == null || p == null || p.nextStep == null) return;
    final step = route.steps[p.nextStep!];
    _say(
      'start',
      spokenInstruction(
        step,
        p.metresToNext,
        destination: destinationName,
        withLanes: mode == TravelMode.driving,
      ),
    );
  }

  void _announceNext(NavRoute route, NavProgress p) {
    final k = p.nextStep;
    if (k == null) return;
    final step = route.steps[k];
    final d = p.metresToNext;
    if (d <= _atMetres) {
      _say('$k:at', '${instructionFor(step, destination: destinationName)}.');
    } else if (d <= _aheadMetres) {
      _say(
        '$k:ahead',
        '${spokenInstruction(step, d, destination: destinationName, withLanes: mode == TravelMode.driving)}.',
      );
    }
  }

  /// Say [text] once per route under [key], only while navigating.
  void _say(String key, String text) {
    if (!_navigating) return;
    if (!_said.add('$_generation:$key')) return;
    if (!_announcements.isClosed) _announcements.add(text);
  }
}
