import 'package:flutter/material.dart';

import '../theme.dart';

/// Whether phone verification can be done at all. Master Context v10 §10.3:
/// it is paused until an SMS provider is chosen, so the channel shows as
/// unavailable (as the REPLIT-OVERHAUL verification frame draws it) instead
/// of opening a form that cannot send a code. Flip when a provider is live.
const bool kPhoneVerificationOpen = false;

/// The three channels and what each is worth (the server's weights).
enum VerifyChannel {
  phone('phone', 40, 'Mobile number'),
  nationalId('national_id', 50, 'National ID'),
  email('email', 10, 'Email address');

  const VerifyChannel(this.key, this.percent, this.label);

  final String key;
  final int percent;
  final String label;
}

/// GET /verification/status, read once: the total, the badge, and where each
/// channel stands.
class VerificationState {
  const VerificationState({
    required this.percent,
    required this.badge,
    required this.channels,
  });

  static const VerificationState empty = VerificationState(
    percent: 0,
    badge: 'yellow',
    channels: {},
  );

  factory VerificationState.fromJson(Map<String, dynamic> json) {
    final channels = <String, String>{};
    for (final c in (json['channels'] as List? ?? const [])) {
      final m = c as Map<String, dynamic>;
      channels['${m['type']}'] = '${m['status']}';
    }
    return VerificationState(
      percent: (json['verified_percent'] as num?)?.toInt() ?? 0,
      badge: (json['badge'] as String?) ?? 'yellow',
      channels: channels,
    );
  }

  final int percent;

  /// yellow (<50) · light_green (50–89) · green (90–99) · green_check (100).
  final String badge;

  /// channel key → pending | verified | manual_review | rejected | failed.
  final Map<String, String> channels;

  String? status(VerifyChannel c) => channels[c.key];
  bool isVerified(VerifyChannel c) => channels[c.key] == 'verified';

  /// A National ID submitted and waiting for an administrator.
  bool isInReview(VerifyChannel c) =>
      c == VerifyChannel.nationalId &&
      const {'pending', 'manual_review'}.contains(channels[c.key]);

  bool isRefused(VerifyChannel c) =>
      const {'rejected', 'failed'}.contains(channels[c.key]);

  bool get complete => badge == 'green_check' || percent >= 100;

  /// Yellow under 50%, green from there — the frame's two swatch colours.
  Color get color => badge == 'yellow' ? AppColors.warn : AppColors.ok;

  String get badgeName => switch (badge) {
    'light_green' => 'Light green',
    'green' => 'Green',
    'green_check' => 'Verified',
    _ => 'Yellow',
  };

  /// The single most useful thing left to do, for the profile's prompt — or
  /// null when nothing is (everything done, or only the paused channel left).
  VerifyChannel? get nextStep {
    for (final c in const [VerifyChannel.nationalId, VerifyChannel.email]) {
      if (!isVerified(c)) return c;
    }
    if (kPhoneVerificationOpen && !isVerified(VerifyChannel.phone)) {
      return VerifyChannel.phone;
    }
    return null;
  }
}
