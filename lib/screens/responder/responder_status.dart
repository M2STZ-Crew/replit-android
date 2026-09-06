import 'package:flutter/material.dart';

import '../../theme.dart';

/// Shared label/colour helpers for incident status + agency, used across the
/// responder console.

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
    case 'rejected':
      return AppColors.live; // red
    default: // pending
      return AppColors.warn; // amber
  }
}

String responderStatusLabel(String status) => status.replaceAll('_', ' ').toUpperCase();

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
