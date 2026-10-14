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
/// left before it, as the voice says it.
String spokenInstruction(
  NavStep step,
  double metres, {
  String destination = 'your destination',
}) {
  final what = instructionFor(step, destination: destination);
  if (step.type == 'arrive') {
    return 'In ${spokenDistance(metres)}, you will arrive at $destination';
  }
  return 'In ${spokenDistance(metres)}, ${what[0].toLowerCase()}${what.substring(1)}';
}

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
