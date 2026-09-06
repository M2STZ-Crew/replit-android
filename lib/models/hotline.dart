import 'package:flutter/material.dart';

/// What kind of help a hotline reaches. Drives the filter chips the v2 design
/// puts above the list; [HotlineCategory.all] entries appear under every filter
/// so the number that always works is never filtered off the screen.
enum HotlineCategory {
  all('All'),
  fire('Fire'),
  medical('Medical'),
  police('Police'),
  pasay('Pasay');

  const HotlineCategory(this.label);

  final String label;
}

/// One emergency hotline shown on the HOTLINES tab.
class Hotline {
  const Hotline({
    required this.name,
    required this.description,
    required this.displayNumber,
    required this.dialNumber,
    required this.icon,
    this.category = HotlineCategory.all,
    this.featured = false,
  });

  final String name;
  final String description;

  /// Human-readable number, e.g. "(02) 8426-0219".
  final String displayNumber;

  /// Digits only (plus optional leading +) used to build the `tel:` URI.
  final String dialNumber;

  final IconData icon;
  final HotlineCategory category;

  /// Given the coral treatment and pinned to every filter. 911 only.
  final bool featured;
}

/// Static directory of Philippine emergency hotlines (Metro Manila / Pasay
/// focused). These are publicly published numbers; tapping a card opens the
/// system dialer pre-filled so the user confirms the call.
const List<Hotline> kHotlines = [
  Hotline(
    name: 'National Emergency Hotline',
    description: 'The centralized, all-purpose emergency number in the '
        'Philippines. Call this for immediate police, fire, or medical response.',
    displayNumber: '911',
    dialNumber: '911',
    icon: Icons.emergency_share,
    category: HotlineCategory.all,
    featured: true,
  ),
  Hotline(
    name: '(BFP) Bureau of Fire Protection',
    description: 'Direct line for the National Capital Region fire bureau. '
        'While 911 works for fires, the BFP direct line can speed up response.',
    displayNumber: '(02) 8426-0219',
    dialNumber: '0284260219',
    icon: Icons.local_fire_department,
    category: HotlineCategory.fire,
  ),
  Hotline(
    name: '(MMDA) Metro Manila Dev. Authority',
    description: 'Call this for major traffic accidents, road emergencies, '
        'clearing operations, and flood-control assistance across Metro Manila.',
    displayNumber: '136',
    dialNumber: '136',
    icon: Icons.traffic,
    category: HotlineCategory.all,
  ),
  Hotline(
    name: '(PNP) Philippine National Police',
    description: 'For crimes in progress, public-safety threats, and police '
        'assistance. The PNP Patrol hotline connects you to the nearest unit.',
    displayNumber: '117',
    dialNumber: '117',
    icon: Icons.local_police,
    category: HotlineCategory.police,
  ),
  Hotline(
    name: '(PCG) Philippine Coast Guard',
    description: 'For maritime emergencies, ferry accidents, or coastal search '
        'and rescue operations.',
    displayNumber: '(02) 8527-8481',
    dialNumber: '0285278481',
    icon: Icons.sailing,
    category: HotlineCategory.all,
  ),
  Hotline(
    name: 'Philippine Red Cross',
    description: 'Ambulance, blood services, and disaster response. Call 143 '
        'for emergency assistance from the Red Cross.',
    displayNumber: '143',
    dialNumber: '143',
    icon: Icons.medical_services,
    category: HotlineCategory.medical,
  ),
  Hotline(
    name: '(NDRRMC) Disaster Response',
    description: 'National disaster operations center for typhoons, floods, '
        'earthquakes, and large-scale emergencies.',
    displayNumber: '(02) 8911-1406',
    dialNumber: '0289111406',
    icon: Icons.crisis_alert,
    category: HotlineCategory.all,
  ),
  Hotline(
    name: 'Pasay City Hall / CDRRMO',
    description: 'Local Pasay City disaster risk reduction and emergency '
        'operations for incidents within the city.',
    displayNumber: '(02) 8833-8534',
    dialNumber: '0288338534',
    icon: Icons.location_city,
    category: HotlineCategory.pasay,
  ),
];
