import 'package:flutter/material.dart';

/// Category labels shown on the GUIDE tab's segmented control.
const String kCatFire = 'FIRE PREVENTION';
const String kCatHealth = 'HEALTH';

/// One heading + its bullet points inside a guide article.
class GuideSection {
  const GuideSection(this.heading, this.points);

  final String heading;
  final List<String> points;
}

/// A single static safety guide (no backend — this is offline knowledge-base
/// content, per Phase 15's "GUIDE tab = static fire-safety content").
class GuideArticle {
  const GuideArticle({
    required this.category,
    required this.icon,
    required this.title,
    required this.summary,
    required this.readMins,
    required this.intro,
    required this.sections,
    this.startHere = false,
  });

  final String category;
  final IconData icon;
  final String title;
  final String summary;
  final int readMins;
  final String intro;
  final List<GuideSection> sections;

  /// The guide the GUIDES tab opens already expanded ("Start here"): the one
  /// to follow while it is happening, not a prevention read.
  final bool startHere;

  /// Up to three steps for the "Start here" card: the first point of each
  /// section, or the first points of a single-section guide.
  List<String> get firstSteps => sections.length >= 3
      ? [for (final s in sections.take(3)) s.points.first]
      : [for (final s in sections) ...s.points].take(3).toList();
}

/// The full knowledge base. Bite-sized, locally-relevant fire & health guidance.
const List<GuideArticle> kGuideArticles = [
  // ----------------------------------------------------------- fire ---
  GuideArticle(
    category: kCatFire,
    icon: Icons.electrical_services,
    title: 'Prevent Common Fire Hazards',
    summary:
        'Inspect wiring, unplug idle appliances, and keep flammables away '
        'from heat sources.',
    readMins: 4,
    intro:
        'Most home fires start from everyday hazards that are easy to '
        'control. A few minutes of checking can prevent a tragedy.',
    sections: [
      GuideSection('Electrical safety', [
        'Inspect cords for fraying, cracks, or exposed wires and replace damaged ones.',
        "Avoid overloading outlets and extension cords ('octopus' connections).",
        'Unplug irons, chargers, and appliances when they are not in use.',
        'Have a licensed electrician check old or faulty wiring.',
      ]),
      GuideSection('In the kitchen', [
        'Never leave cooking unattended, especially when frying.',
        'Keep curtains, paper, and plastic well away from the stove.',
        'Close the LPG tank valve after cooking and check hoses for leaks.',
      ]),
      GuideSection('Open flame and smoking', [
        'Keep candles, matches, and lighters out of reach of children.',
        'Put out cigarettes completely and never smoke in bed.',
        'Store gasoline and flammable liquids outside, in sealed containers.',
      ]),
    ],
  ),
  GuideArticle(
    category: kCatFire,
    icon: Icons.notifications_active,
    title: 'Smoke Alarm Maintenance',
    summary:
        'Test alarms monthly, replace batteries yearly, and swap units '
        'every 10 years.',
    readMins: 3,
    intro:
        'A working smoke alarm gives you the early warning you need to '
        'escape. Maintenance takes only minutes.',
    sections: [
      GuideSection('Where to place them', [
        'Install alarms inside each bedroom and on every level of the home.',
        'Mount on the ceiling or high on a wall, away from vents and windows.',
      ]),
      GuideSection('Monthly and yearly', [
        'Press the test button every month to confirm it sounds.',
        'Replace the battery at least once a year, or as soon as it chirps.',
        'Clear dust away with a vacuum or a soft brush.',
      ]),
      GuideSection('When to replace', [
        'Replace the entire unit every 10 years.',
        'Never disable an alarm for nuisance cooking smoke — relocate it instead.',
      ]),
    ],
  ),
  GuideArticle(
    category: kCatFire,
    icon: Icons.directions_run,
    title: 'Build an Escape Plan',
    summary:
        'Map two exits per room, agree on a meet point, and practice with '
        'your household.',
    readMins: 5,
    intro:
        'In a real fire you may have less than two minutes to get out. A '
        'plan you have practiced saves lives.',
    sections: [
      GuideSection('Map your exits', [
        'Identify two ways out of every room — usually a door and a window.',
        'Make sure windows and security grills open quickly from the inside.',
      ]),
      GuideSection('Agree on a meeting point', [
        "Pick a safe spot outside, like a specific post, tree, or neighbor's gate.",
        'Account for everyone there, and never go back inside for belongings.',
      ]),
      GuideSection('Practice it', [
        'Walk through the plan with your whole household, including children.',
        'Practice once during the day and once at night.',
        'Teach everyone the emergency hotline and how to trigger an SOS here.',
      ]),
    ],
  ),
  GuideArticle(
    category: kCatFire,
    icon: Icons.air,
    title: "If There's Smoke: Stay Low",
    startHere: true,
    summary:
        'Crawl beneath the smoke layer, cover your mouth, and feel doors '
        'before opening.',
    readMins: 2,
    intro:
        'Smoke and toxic gas — not flames — cause most fire deaths. Staying '
        'low keeps you in the cleaner air near the floor.',
    sections: [
      GuideSection('Move low and fast', [
        'Crawl on your hands and knees, below the smoke layer.',
        'Cover your nose and mouth with a cloth, ideally a damp one.',
      ]),
      GuideSection('Check before you open', [
        'Feel doors with the back of your hand before opening them.',
        'If a door is hot, use your second exit instead.',
      ]),
      GuideSection("Once you're out", [
        'Stay out and go straight to your meeting point.',
        'Call for help and report the location; do not re-enter.',
      ]),
    ],
  ),
  // --------------------------------------------------------- health ---
  GuideArticle(
    category: kCatHealth,
    icon: Icons.healing,
    title: 'Treating Minor Burns',
    summary:
        'Cool the burn under running water, cover it loosely, and avoid '
        'home remedies.',
    readMins: 3,
    intro:
        'Quick, correct first aid limits the damage from minor burns. Know '
        'what to do — and what to avoid.',
    sections: [
      GuideSection('Cool the burn', [
        'Hold the area under cool (not ice-cold) running water for 10–20 minutes.',
        'Remove rings or tight items near the burn before it swells.',
      ]),
      GuideSection('Protect it', [
        'Cover loosely with a clean, non-stick cloth or sterile gauze.',
        'Do not apply toothpaste, butter, or ice — these worsen the injury.',
      ]),
      GuideSection('When to seek help', [
        'Get medical care for burns larger than your palm, or on the face, hands, or genitals.',
        'Seek help for blistering, charred or white skin, or any burn on a child.',
      ]),
    ],
  ),
  GuideArticle(
    category: kCatHealth,
    icon: Icons.masks,
    title: 'Smoke Inhalation First Aid',
    summary:
        'Get to fresh air, watch for trouble breathing, and call for help '
        'on warning signs.',
    readMins: 3,
    intro:
        'Breathing in smoke can harm someone even without visible burns. '
        'Watch closely for the warning signs.',
    sections: [
      GuideSection('Get to fresh air', [
        'Move the person to fresh air immediately, keeping yourself safe.',
        'Loosen tight clothing around the neck and chest.',
      ]),
      GuideSection('Watch for danger signs', [
        'Coughing, hoarseness, soot around the nose or mouth, or trouble breathing.',
        'Confusion, dizziness, or bluish lips — call emergency services at once.',
      ]),
      GuideSection('While waiting for help', [
        'Keep them calm and sitting upright to ease breathing.',
        'If you are trained and they stop breathing, begin CPR.',
      ]),
    ],
  ),
  GuideArticle(
    category: kCatHealth,
    icon: Icons.favorite,
    title: 'Helping Someone in Shock',
    summary:
        'Lay them down, keep them warm, and get medical help — do not give '
        'food or drink.',
    readMins: 2,
    intro:
        'Shock can follow any serious injury or fright. Simple steps keep '
        'the person stable until help arrives.',
    sections: [
      GuideSection('Recognize it', [
        'Pale, cold, clammy skin; rapid breathing; weakness or confusion.',
      ]),
      GuideSection('What to do', [
        'Lay them down and raise their legs slightly if no injury prevents it.',
        'Keep them warm with a blanket and reassure them.',
        'Do not give food or drink; call for medical help.',
      ]),
    ],
  ),
  GuideArticle(
    category: kCatHealth,
    icon: Icons.bloodtype,
    title: 'Stop Bleeding from a Wound',
    summary:
        'Press firmly with a clean cloth, keep pressure on, and call for '
        'serious bleeding.',
    readMins: 4,
    intro:
        'Controlling heavy bleeding fast can save a life before responders '
        'arrive.',
    sections: [
      GuideSection('Apply pressure', [
        'Press firmly on the wound with a clean cloth or a gloved hand.',
        'Keep steady pressure; do not lift it to check too often.',
      ]),
      GuideSection('Keep it up', [
        "Add more cloth on top if blood soaks through — don't remove the first layer.",
        'Raise the injured limb above heart level if possible.',
      ]),
      GuideSection('Get help', [
        'Call emergency services for deep, spurting, or non-stopping bleeding.',
        'Keep the person warm and still until help arrives.',
      ]),
    ],
  ),
];
