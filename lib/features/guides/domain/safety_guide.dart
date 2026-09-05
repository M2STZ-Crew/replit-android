/// The knowledge base from the hand-off: ten short guides, each written as
/// steps you can follow one-handed while help is on the way.
///
/// Held in the app rather than fetched, for the same reason as the hotlines —
/// the moment someone needs "stopping severe bleeding" is not the moment to
/// discover there is no signal.
class SafetyGuide {
  const SafetyGuide({
    required this.number,
    required this.title,
    required this.minutes,
    required this.steps,
    this.intro,
  });

  final int number;
  final String title;
  final int minutes;
  final String? intro;
  final List<String> steps;

  String get index => number.toString().padLeft(2, '0');
  String get readTime => '$minutes min';
}

const kSafetyGuides = <SafetyGuide>[
  SafetyGuide(
    number: 1,
    title: 'If your house is on fire',
    minutes: 2,
    intro: 'Getting out matters more than anything you own.',
    steps: [
      'Get everyone out first. Do not go back for belongings.',
      'Stay low under the smoke and close doors behind you.',
      'Once outside, send an SOS and wait where responders can see you.',
      'Do not re-enter the building, even if the fire looks small from outside.',
    ],
  ),
  SafetyGuide(
    number: 2,
    title: 'Using a fire extinguisher',
    minutes: 1,
    intro: 'Only for a fire smaller than you are, with your exit behind you.',
    steps: [
      'Pull the pin at the top of the handle.',
      'Aim the nozzle at the base of the flames, not the smoke.',
      'Squeeze the handle slowly and evenly.',
      'Sweep side to side until the fire is out. If it grows, leave.',
    ],
  ),
  SafetyGuide(
    number: 3,
    title: 'CPR basics',
    minutes: 3,
    intro: 'For an adult who is unresponsive and not breathing normally.',
    steps: [
      'Check for a response and shout for someone to call 911.',
      'Place the heel of one hand in the centre of the chest, the other on top.',
      'Push hard and fast — about two pushes a second, 5 cm deep.',
      'Let the chest come all the way back up between pushes.',
      'Keep going until responders take over or the person wakes.',
    ],
  ),
  SafetyGuide(
    number: 4,
    title: 'Stopping severe bleeding',
    minutes: 2,
    steps: [
      'Press hard directly on the wound with a clean cloth.',
      'Do not lift the cloth to look — add another on top if it soaks through.',
      'Keep pressing until help arrives.',
      'If the bleeding is from an arm or leg and will not stop, apply a tight band above it and note the time.',
    ],
  ),
  SafetyGuide(
    number: 5,
    title: 'Earthquake: drop, cover, hold',
    minutes: 2,
    steps: [
      'Drop to your hands and knees before the shaking knocks you down.',
      'Cover your head and neck. Get under a sturdy table if one is close.',
      'Hold on to it until the shaking stops.',
      'Only then move outside, away from walls, glass and power lines.',
      'Expect aftershocks and be ready to drop again.',
    ],
  ),
  SafetyGuide(
    number: 6,
    title: 'Flood safety and evacuation',
    minutes: 3,
    steps: [
      'Move to higher ground before the water rises, not after.',
      'Never walk or drive through moving water — knee-deep water can carry you.',
      'Switch off electricity at the main breaker if you can reach it dry.',
      'Take your phone, charger, medicines and IDs in a sealed bag.',
      'Head for the nearest shelter on the map and tell someone you are going.',
    ],
  ),
  SafetyGuide(
    number: 7,
    title: 'Smoke inhalation',
    minutes: 1,
    steps: [
      'Get the person into fresh air immediately.',
      'Loosen tight clothing around the neck and chest.',
      'Keep them sitting upright — it is easier to breathe than lying flat.',
      'Call for an ambulance even if they say they feel fine. Symptoms can be delayed.',
    ],
  ),
  SafetyGuide(
    number: 8,
    title: 'Electrical fire',
    minutes: 2,
    steps: [
      'Never use water. It conducts and will electrocute you.',
      'Cut the power at the breaker if you can reach it safely.',
      'Use a dry-chemical or CO2 extinguisher if the fire is still small.',
      'If it is spreading, leave and report it. Wiring fires travel inside walls.',
    ],
  ),
  SafetyGuide(
    number: 9,
    title: 'Helping someone who is trapped',
    minutes: 2,
    steps: [
      'Do not move them unless staying is more dangerous than moving.',
      'Talk to them constantly. Being heard keeps people calm and conscious.',
      'Send an SOS with a photo so responders know what they are arriving to.',
      'Clear a path for the crew and mark the spot where you can be seen.',
    ],
  ),
  SafetyGuide(
    number: 10,
    title: 'Preparing a go-bag',
    minutes: 2,
    intro: 'Pack it once. Keep it by the door.',
    steps: [
      'Water and food that needs no cooking, for three days.',
      'Any regular medicine, plus a copy of the prescription.',
      'Phone charger, power bank, and a torch with spare batteries.',
      'Photocopies of IDs and a little cash in small notes.',
      'A whistle. It carries much further than your voice.',
    ],
  ),
];
