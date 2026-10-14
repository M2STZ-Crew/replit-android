import 'package:flutter/material.dart';
import '../widgets/app_icons.dart';

/// A responder unit a citizen can request. The [key] is the backend agency_type
/// value sent to /reports/submit (selected_agencies).
class ResponderUnit {
  const ResponderUnit(this.key, this.title, this.subtitle, this.icon);

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// The citizen-selectable responder units, in display order. Shared by the SOS
/// report picker and the live "add more help" list (which excludes the ones
/// already requested).
const List<ResponderUnit> kResponderUnits = [
  ResponderUnit(
    'fire_volunteer',
    'Fire Department',
    'HERCULES FIRE VOLUNTEER',
    AppIcons.localFireDepartment,
  ),
  ResponderUnit(
    'police',
    'Police Department',
    'PASAY POLICE STATION',
    AppIcons.localPolice,
  ),
  ResponderUnit(
    'medical',
    'Medical Support',
    'METRO PASAY HOSPITAL',
    AppIcons.medicalServices,
  ),
  ResponderUnit(
    'barangay',
    'Barangay Personnel',
    'BARANGAY 76, BARANGAY HALL',
    AppIcons.groups,
  ),
];
