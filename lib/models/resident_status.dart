import 'package:flutter/material.dart';

import '../theme.dart';

/// An incident's lifecycle as a resident sees it — the six-step rail on the
/// Area detail and Live tracking screens (REPLIT-OVERHAUL frames 06 and 10).
///
/// After fire out the crew still files its Post-Incident Report (Master
/// Context v10 §2.5); that is internal, so to a resident both
/// `post_incident_report` and `closed` are simply "resolved".
const List<String> kResidentRail = [
  'pending',
  'verified',
  'dispatched',
  'en_route',
  'arrived',
  'resolved',
];

String residentStatus(String? status) =>
    const {'post_incident_report', 'closed'}.contains(status)
    ? 'resolved'
    : (status ?? 'pending');

/// The status in a word or two, sentence case.
String residentWord(String status) => switch (status) {
  'en_route' => 'En route',
  'arrived' => 'On scene',
  'rejected' => 'Not confirmed',
  '' => 'Pending',
  _ => '${status[0].toUpperCase()}${status.substring(1)}',
};

Color residentTone(String status) => switch (status) {
  'pending' => AppColors.warn,
  'resolved' => AppColors.ok,
  'rejected' || 'merged' => AppColors.muted,
  _ => AppColors.live,
};

/// Finished, one way or another: nothing is coming and nothing can be added.
bool residentOver(String status) =>
    const {'resolved', 'rejected', 'merged'}.contains(status);
