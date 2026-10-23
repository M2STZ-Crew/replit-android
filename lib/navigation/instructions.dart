import 'nav_route.dart';

/// What to do at a maneuver, in words: "Turn left onto Taft Avenue".
///
/// Built from the step's maneuver type, modifier and street, the same way
/// for both providers, so the banner and the voice read alike whichever one
/// answered. [destination] names the place on arrival ("the fire").
String instructionFor(NavStep step, {String destination = 'your destination'}) {
  final onto = step.name.isEmpty ? '' : ' onto ${step.name}';
  final on = step.name.isEmpty ? '' : ' on ${step.name}';
  final side = _side(step.modifier);
  switch (step.type) {
    case 'depart':
      final heading = _compass(step.bearingAfter);
      return 'Head${heading == null ? '' : ' $heading'}$on';
    case 'arrive':
      return 'You have arrived at $destination';
    case 'new name':
      return 'Continue$onto';
    case 'merge':
      return side == null ? 'Merge$onto' : 'Merge $side$onto';
    case 'on ramp':
      return side == null
          ? 'Take the ramp$onto'
          : 'Take the ramp on the $side$onto';
    case 'off ramp':
      return side == null
          ? 'Take the exit$onto'
          : 'Take the exit on the $side$onto';
    case 'fork':
      return side == null
          ? 'Keep straight at the fork$onto'
          : 'Keep $side at the fork$onto';
    case 'end of road':
      return 'At the end of the road, ${_turn(step.modifier).toLowerCase()}$onto';
    case 'roundabout':
    case 'rotary':
      final exit = step.exit;
      return exit == null
          ? 'Enter the roundabout and exit$onto'
          : 'At the roundabout, take the ${_ordinal(exit)} exit$onto';
    case 'roundabout turn':
      return 'At the roundabout, ${_turn(step.modifier).toLowerCase()}$onto';
    case 'exit roundabout':
    case 'exit rotary':
      return 'Exit the roundabout$onto';
    case 'continue':
      if (step.modifier == 'uturn') return 'Make a U-turn$onto';
      if (step.modifier == null || step.modifier == 'straight') {
        return 'Continue$on';
      }
      return '${_turn(step.modifier)}$onto';
    case 'turn':
    default:
      return '${_turn(step.modifier)}$onto';
  }
}

/// "In 200 m, turn left onto Taft Avenue" — the instruction with the distance
/// left before it, as the voice says it. [withLanes] adds which lanes to be
/// in, when the step has them ("… Stay in the left two lanes"): for a driver.
String spokenInstruction(
  NavStep step,
  double metres, {
  String destination = 'your destination',
  bool withLanes = false,
}) {
  final what = instructionFor(step, destination: destination);
  if (step.type == 'arrive') {
    return 'In ${spokenDistance(metres)}, you will arrive at $destination';
  }
  final said =
      'In ${spokenDistance(metres)}, ${what[0].toLowerCase()}${what.substring(1)}';
  final lanes = withLanes ? lanePhrase(step.lanes) : null;
  return lanes == null ? said : '$said. Stay in $lanes';
}

/// The road that sets [route] apart from [other], for "via Harrison
/// Street": its first named step that [other] does not take, else the first
/// road of its summary that [other]'s does not list. Null when nothing does.
String? viaName(NavRoute route, NavRoute other) {
  final taken = {for (final s in other.steps) s.name};
  for (final s in route.steps) {
    if (s.name.isNotEmpty && !taken.contains(s.name)) return s.name;
  }
  final theirs = {for (final r in other.summary.split(',')) r.trim()};
  for (final road in route.summary.split(',')) {
    final r = road.trim();
    if (r.isNotEmpty && !theirs.contains(r)) return r;
  }
  return null;
}

/// Which lanes to be in, in words: "the left two lanes", "the right lane",
/// "the middle lane" (PRD v14 §4.9.2). Null when the lanes do not narrow the
/// choice (every lane works, or there is one lane), when there are none, or
/// when the usable lanes are not side by side — the strip still shows those.
String? lanePhrase(List<LaneInfo>? lanes) {
  if (lanes == null || lanes.length < 2) return null;
  final valid = [
    for (var i = 0; i < lanes.length; i++)
      if (lanes[i].valid) i,
  ];
  if (valid.isEmpty || valid.length == lanes.length) return null;
  final first = valid.first;
  final last = valid.last;
  if (last - first + 1 != valid.length) return null;
  final side = first == 0
      ? 'left'
      : last == lanes.length - 1
      ? 'right'
      : 'middle';
  final n = valid.length;
  if (n == 1) return 'the $side lane';
  const words = {2: 'two', 3: 'three', 4: 'four', 5: 'five'};
  return 'the $side ${words[n] ?? '$n'} lanes';
}

/// The banner's lane line: "Use the left two lanes", or null.
String? laneInstruction(NavStep step) {
  final phrase = lanePhrase(step.lanes);
  return phrase == null ? null : 'Use $phrase';
}

/// Metres before a maneuver at which its lane strip appears.
///
/// PRD v14 §18 leaves open whether the strip shows only for maneuvers or on
/// every road. This shows it for the next maneuver only, from 500 m out —
/// one place to change that policy without touching how lanes are drawn.
const double kLaneStripFromMetres = 500;

/// Whether the banner shows [step]'s lane strip, [metres] before it.
bool laneStripVisible(NavStep step, double metres) =>
    step.lanes != null && metres <= kLaneStripFromMetres;

/// A distance the way a driver hears it: "50 metres", "200 metres",
/// "1.2 kilometres". Rounded so it never sounds more precise than GPS is.
String spokenDistance(double metres) {
  if (metres >= 1000) {
    return '${(metres / 1000).toStringAsFixed(1)} kilometres';
  }
  return '${roundedMetres(metres)} metres';
}

/// The banner's distance to the next maneuver: "50 m", "250 m", "1.2 km".
String bannerDistance(double metres) {
  if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km';
  return '${roundedMetres(metres)} m';
}

/// Metres rounded to what is worth saying: to 10 m below 100 m, to 50 m
/// below a kilometre.
int roundedMetres(double metres) {
  if (metres < 100) return ((metres / 10).round() * 10).clamp(10, 100);
  return (metres / 50).round() * 50;
}

String _turn(String? modifier) => switch (modifier) {
  'uturn' => 'Make a U-turn',
  'sharp right' => 'Turn sharp right',
  'right' => 'Turn right',
  'slight right' => 'Bear right',
  'sharp left' => 'Turn sharp left',
  'left' => 'Turn left',
  'slight left' => 'Bear left',
  _ => 'Continue straight',
};

String? _side(String? modifier) => switch (modifier) {
  'sharp right' || 'right' || 'slight right' => 'right',
  'sharp left' || 'left' || 'slight left' => 'left',
  _ => null,
};

String? _compass(double? bearing) {
  if (bearing == null) return null;
  const names = [
    'north',
    'northeast',
    'east',
    'southeast',
    'south',
    'southwest',
    'west',
    'northwest',
  ];
  return names[((bearing % 360) / 45).round() % 8];
}

String _ordinal(int n) => switch (n) {
  1 => 'first',
  2 => 'second',
  3 => 'third',
  4 => 'fourth',
  5 => 'fifth',
  _ => '${n}th',
};
