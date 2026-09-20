import 'package:flutter/material.dart';

import '../theme.dart';

/// An incident's lifecycle as a resident sees it — the rail on the Area detail
/// and Live tracking screens (REPLIT-OVERHAUL frames 06 and 10).
///
/// Five steps in v11, not six: Accept takes an incident from Reported through
/// Verified to En route in one act (Master Context v11 §2.5.1), so there is no
/// "dispatched" step between them for a resident to watch.
///
/// After fire out the crew still files its Post-Incident Report (§2.5.3); that
/// is internal, so to a resident both `post_incident_report` and `closed` are
/// simply "fire out".
const List<String> kResidentRail = [
  'reported',
  'verified',
  'en_route',
  'arrived',
  'fire_out',
];

String residentStatus(String? status) =>
    const {'post_incident_report', 'closed'}.contains(status)
    ? 'fire_out'
    : (status ?? 'reported');

/// The status in a word or two, sentence case.
String residentWord(String status) => switch (status) {
  'en_route' => 'En route',
  'arrived' => 'On scene',
  'fire_out' => 'Fire out',
  'rejected' => 'Not confirmed',
  '' => 'Reported',
  _ => '${status[0].toUpperCase()}${status.substring(1)}',
};

Color residentTone(String status, AppPalette pal) => switch (status) {
  'reported' => pal.warn,
  'fire_out' => pal.ok,
  'rejected' || 'merged' => pal.muted,
  _ => pal.live,
};

/// Finished, one way or another: nothing is coming and nothing can be added.
bool residentOver(String status) =>
    const {'fire_out', 'rejected', 'merged'}.contains(status);
