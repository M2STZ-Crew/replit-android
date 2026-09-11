import 'package:flutter/material.dart';

import '../theme.dart';

/// What kind of help a hotline reaches. Drives the filter chips the design
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
    required this.summary,
    required this.description,
    required this.displayNumber,
    required this.dialNumber,
    required this.icon,
    required this.tint,
    this.art,
    this.category = HotlineCategory.all,
    this.featured = false,
  });

  final String name;

  /// One line for the list row ("Crimes in progress, public safety").
  final String summary;

  /// The longer explanation of when to call.
  final String description;

  /// Human-readable number, e.g. "(02) 8426-0219".
  final String displayNumber;

  /// Digits only (plus optional leading +) used to build the `tel:` URI.
  final String dialNumber;

  /// Glyph for the row's well when there is no agency logo ([art]).
  final IconData icon;

  /// The row's colour, as the REPLIT-OVERHAUL hotline frame gives it.
  final Color tint;

  /// The agency's own logo, where the design has one.
  final String? art;

  final HotlineCategory category;

  /// Given the coral treatment and pinned to every filter. 911 only.
  final bool featured;
}

/// Static directory of Philippine emergency hotlines (Metro Manila / Pasay
/// focused). These are publicly published numbers; tapping a card opens the
/// system dialer pre-filled so the user confirms the call.
///
/// The numbers are the team's verified list, unchanged. The REPLIT-OVERHAUL
/// frame lists ten, with some numbers not here (a BFP short code, a hospital,
/// a DRRMO mobile, Meralco); they are not added on the design's word, because
/// a hotline nobody on the team has verified is worse than one fewer entry.
const List<Hotline> kHotlines = [
  Hotline(
    name: 'National emergency',
    summary: 'Fire, medical or police — anywhere',
    description:
        'The centralized, all-purpose emergency number in the '
        'Philippines. Call this for immediate police, fire, or medical response.',
    displayNumber: '911',
    dialNumber: '911',
    icon: Icons.emergency_share,
    tint: AppColors.accent,
    art: 'assets/design/agency-911.png',
    category: HotlineCategory.all,
    featured: true,
  ),
  Hotline(
    name: 'Bureau of Fire · NCR',
    summary: 'Direct line to the fire bureau',
    description:
        'Direct line for the National Capital Region fire bureau. '
        'While 911 works for fires, the BFP direct line can speed up response.',
    displayNumber: '(02) 8426-0219',
    dialNumber: '0284260219',
    icon: Icons.local_fire_department,
    tint: AppColors.fire,
    art: 'assets/design/agency-bfp.png',
    category: HotlineCategory.fire,
  ),
  Hotline(
    name: 'Philippine National Police',
    summary: 'Crimes in progress, public safety',
    description:
        'For crimes in progress, public-safety threats, and police '
        'assistance. The PNP Patrol hotline connects you to the nearest unit.',
    displayNumber: '117',
    dialNumber: '117',
    icon: Icons.local_police,
    tint: AppColors.police,
    art: 'assets/design/agency-pnp.png',
    category: HotlineCategory.police,
  ),
  Hotline(
    name: 'Pasay City CDRRMO',
    summary: 'City rescue and disaster response',
    description:
        'Local Pasay City disaster risk reduction and emergency '
        'operations for incidents within the city.',
    displayNumber: '(02) 8833-8534',
    dialNumber: '0288338534',
    icon: Icons.call_outlined,
    tint: AppColors.barangay,
    category: HotlineCategory.pasay,
  ),
  Hotline(
    name: 'Philippine Red Cross',
    summary: 'Ambulance, blood, disaster response',
    description:
        'Ambulance, blood services, and disaster response. Call 143 '
        'for emergency assistance from the Red Cross.',
    displayNumber: '143',
    dialNumber: '143',
    icon: Icons.call_outlined,
    tint: AppColors.medical,
    category: HotlineCategory.medical,
  ),
  Hotline(
    name: 'MMDA',
    summary: 'Road crashes, flooding, clearing',
    description:
        'Call this for major traffic accidents, road emergencies, '
        'clearing operations, and flood-control assistance across Metro Manila.',
    displayNumber: '136',
    dialNumber: '136',
    icon: Icons.traffic,
    tint: AppColors.textSoft,
    art: 'assets/design/agency-mmda.png',
    category: HotlineCategory.all,
  ),
  Hotline(
    name: 'Philippine Coast Guard',
    summary: 'Sea rescue, Manila Bay incidents',
    description:
        'For maritime emergencies, ferry accidents, or coastal search '
        'and rescue operations.',
    displayNumber: '(02) 8527-8481',
    dialNumber: '0285278481',
    icon: Icons.call_outlined,
    tint: AppColors.coastguard,
    category: HotlineCategory.all,
  ),
  Hotline(
    name: 'NDRRMC',
    summary: 'National disaster operations centre',
    description:
        'National disaster operations center for typhoons, floods, '
        'earthquakes, and large-scale emergencies.',
    displayNumber: '(02) 8911-1406',
    dialNumber: '0289111406',
    icon: Icons.call_outlined,
    tint: AppColors.barangay,
    category: HotlineCategory.all,
  ),
];
