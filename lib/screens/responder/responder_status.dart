import 'package:flutter/material.dart';

import '../../theme.dart';

/// Shared label/colour helpers for incident status + agency, used across the
/// responder console.

/// After fire out (Master Context v10 §2.5): the response is over. The
/// incident then waits in 'post_incident_report' until its team captain files,
/// and 'closed' is terminal. Mirrors the post-fire part of OFF_FEED_STATUSES in
/// app/services/incident.py.
const Set<String> kAfterFireOut = {'resolved', 'post_incident_report', 'closed'};

Color responderStatusColor(String status) {
  switch (status) {
    case 'verified':
      return AppColors.info; // blue
    case 'dispatched':
    case 'en_route':
      return const Color(0xFFFF9066); // orange
    case 'arrived':
      return AppColors.ok; // green
    case 'resolved':
      return AppColors.ok;
    case 'post_incident_report':
    case 'closed':
      return AppColors.forStatus(status);
    case 'rejected':
      return AppColors.live; // red
    default: // pending
      return AppColors.warn; // amber
  }
}

String responderStatusLabel(String status) => switch (status) {
  // The whole enum value is too long for a chip, and "report due" is what a
  // captain needs to read in it.
  'post_incident_report' => 'REPORT DUE',
  _ => status.replaceAll('_', ' ').toUpperCase(),
};

/// Response Teams exist in all five agencies (v10 §2.6), but fire codes — Need
/// Water, Fire Out — are the fire service's. A police, medical or barangay
/// crew is not offered them.
bool isFireCrew(String? agency) => agency == 'fire_volunteer' || agency == 'bfp';

/// Mirrors POST /alarm-requests: of the Response Teams, only Fire Volunteer
/// responders may ask BFP to raise the alarm. Anyone else would be refused,
/// so the control is not shown to them (§2.7.1).
bool mayRequestAlarm(String? agency) => agency == 'fire_volunteer';

/// Whether Admin has routed an incident to this responder's agency or team
/// (v10 §2.6.2), as a short label — null when it has not.
///
/// A detail (with `routes`) can say "your team"; a feed summary only knows
/// which agencies were routed, so it says the agency.
String? routingLabel(
  Map<String, dynamic> incident, {
  required String? agency,
  String? orgId,
}) {
  if (agency == null) return null;
  final routes = incident['routes'];
  if (routes is List) {
    final mine = routes.cast<Map<String, dynamic>>().where((r) => r['agency'] == agency);
    if (mine.isEmpty) return null;
    if (orgId != null && mine.any((r) => r['organization_id'] == orgId)) {
      return 'ROUTED TO YOUR TEAM';
    }
    if (mine.any((r) => r['organization_id'] == null)) {
      return 'ROUTED TO ${responderAgencyLabel(agency).toUpperCase()}';
    }
    final teams = mine.map((r) => r['organization_name'] as String?).whereType<String>();
    return teams.isEmpty ? null : 'ROUTED TO ${teams.join(', ').toUpperCase()}';
  }
  final routed = incident['routed_agencies'];
  if (routed is List && routed.contains(agency)) {
    return 'ROUTED TO ${responderAgencyLabel(agency).toUpperCase()}';
  }
  return null;
}

String responderAgencyLabel(String? agency) {
  switch (agency) {
    case 'fire_volunteer':
      return 'Fire Volunteer';
    case 'bfp':
      return 'BFP';
    case 'barangay':
      return 'Barangay';
    case 'medical':
      return 'Medical';
    case 'police':
      return 'Police';
    default:
      return 'Responder';
  }
}
