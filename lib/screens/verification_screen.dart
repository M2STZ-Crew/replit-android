import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/session.dart';
import '../models/phone_numbers.dart';
import '../models/verification_state.dart';
import '../theme.dart';
import '../widgets/coordinator_kit.dart' show IconPlate, ListRow;
import '../widgets/design.dart';
import '../widgets/email_link_sheet.dart';
import 'national_id_screen.dart';
import 'phone_verify_screen.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';

/// "16 Verification" from the REPLIT-OVERHAUL Figma — "Verify your account".
///
/// Reads GET /verification/status, so each channel says where it actually
/// stands: done, submitted and awaiting an administrator, refused, or not
/// started — the aggregate percent alone cannot tell those apart, and a
/// resident told to upload their ID again while the first is still in the
/// queue would do exactly that. Phone is shown unavailable while no SMS
/// provider is chosen ([PhoneNumbers], §10.3).
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  VerificationState _state = VerificationState.empty;
  String? _email;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await _api.getVerificationStatus();
      if (mounted) setState(() => _state = VerificationState.fromJson(status));
    } catch (_) {
      // keep what is on screen
    }
    try {
      final me = await _api.getMe();
      if (mounted) setState(() => _email = me['email'] as String?);
    } catch (_) {
      _email ??= Session.instance.email;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _openEmail() async {
    await showEmailLinkSheet(context, email: _email, api: _api, sendNow: false);
    _load();
  }

  Future<void> _openPhone() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PhoneVerifyScreen()));
    if (changed == true) _load();
  }

  Future<void> _openNationalId() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            NationalIdScreen(percent: _loaded ? _state.percent : null),
      ),
    );
    // Sent, or not: either way, where it stands now.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
            children: [
              const Align(alignment: Alignment.centerLeft, child: BackWell()),
              const SizedBox(height: 20),
              Text(t('VERIFY YOUR ACCOUNT'), style: context.type.heading1),
              const SizedBox(height: 12),
              Text(
                t(
                  'Verification never blocks a report. It tells responders how '
                  'much weight to give what you send.',
                ),
                style: context.type.body,
              ),
              const SizedBox(height: 24),
              _progress(s),
              const SizedBox(height: 24),
              Eyebrow(t('Channels'), color: context.pal.muted),
              const SizedBox(height: 10),
              _phone(s),
              const SizedBox(height: 8),
              _nationalId(s),
              const SizedBox(height: 8),
              _emailRow(s),
              const SizedBox(height: 24),
              Eyebrow(t('Badges'), color: context.pal.muted),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Legend(t('Under 50'), context.pal.warn)),
                  SizedBox(width: 8),
                  Expanded(child: _Legend('50 to 89', context.pal.ok)),
                  SizedBox(width: 8),
                  Expanded(child: _Legend('90 to 99', context.pal.ok)),
                  SizedBox(width: 8),
                  Expanded(child: _Legend('100', context.pal.ok)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                t(
                  'Documents are held privately, used only to confirm who you '
                  'are, and deleted after review. A National ID is checked by an '
                  "administrator on PSA's PhilSys Check before its 50% applies.",
                ),
                style: context.type.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress(VerificationState s) {
    final pct = s.percent.clamp(0, 100);
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _loaded ? '$pct%' : '—',
                  style: context.type.numeralXl.copyWith(
                    color: s.colour(context.pal),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 22),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: s.colour(context.pal).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(
                    color: s.colour(context.pal).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  s.badgeName.toUpperCase(),
                  style: context.type.tag.copyWith(
                    color: s.colour(context.pal),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: context.pal.lineStrong,
              color: s.colour(context.pal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phone(VerificationState s) {
    const c = VerifyChannel.phone;
    if (s.isVerified(c)) {
      return _Channel(
        channel: c,
        icon: AppIcons.call,
        line: t('Verified by SMS code'),
        done: true,
      );
    }
    if (!PhoneNumbers.open) {
      // Greyed out, "Coming soon" (WHAT'S NEXT, 2.2).
      return _Channel(
        channel: c,
        icon: AppIcons.call,
        line: t('Coming soon'),
        dimmed: true,
      );
    }
    return _Channel(
      channel: c,
      icon: AppIcons.call,
      line: t('Confirm it with a code by SMS'),
      onTap: _openPhone,
    );
  }

  Widget _nationalId(VerificationState s) {
    const c = VerifyChannel.nationalId;
    if (s.isVerified(c)) {
      return _Channel(
        channel: c,
        icon: AppIcons.photoCamera,
        line: t('Checked by an administrator'),
        done: true,
      );
    }
    if (s.isInReview(c)) {
      return _Channel(
        channel: c,
        icon: AppIcons.photoCamera,
        line: t('Submitted — an administrator is checking it'),
        tone: context.pal.warn,
        trailing: Icon(AppIcons.schedule, size: 18, color: context.pal.warn),
      );
    }
    final refused = s.isRefused(c);
    return _Channel(
      channel: c,
      icon: AppIcons.photoCamera,
      line: refused
          ? s.refusalReason(c) ?? t('Not accepted — take the photos again')
          : t('Camera only — the photo and selfie must be live'),
      tone: refused ? context.pal.live : null,
      onTap: _openNationalId,
    );
  }

  Widget _emailRow(VerificationState s) {
    const c = VerifyChannel.email;
    if (s.isVerified(c)) {
      return _Channel(
        channel: c,
        icon: AppIcons.mail,
        line: maskEmail(_email) ?? t('Verified'),
        done: true,
      );
    }
    return _Channel(
      channel: c,
      icon: AppIcons.mail,
      line: s.status(c) == 'pending'
          ? t('Link sent — open it on this phone')
          : t('Tap for a confirmation link'),
      onTap: _openEmail,
    );
  }
}

/// An address as 15 · Verification shows it, "m•••@example.com": enough to
/// know which, not enough to read off over a shoulder.
@visibleForTesting
String? maskEmail(String? email) {
  if (email == null) return null;
  final at = email.indexOf('@');
  if (at < 1) return email;
  return '${email[0]}•••${email.substring(at)}';
}

/// One channel (15 · Verification, List item): its icon on a plate (green
/// once verified, coral while it waits on the resident, the tone of a review
/// or a refusal), what it is worth and where it stands, then Verified, or a
/// chevron where a tap goes on.
class _Channel extends StatelessWidget {
  const _Channel({
    required this.channel,
    required this.icon,
    required this.line,
    this.tone,
    this.trailing,
    this.onTap,
    this.done = false,
    this.dimmed = false,
  });

  final VerifyChannel channel;
  final IconData icon;
  final String line;

  /// The line's tone and the plate's: in review, or refused.
  final Color? tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool done;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final tint = done
        ? pal.ok
        : dimmed
        ? null
        : tone ?? (onTap != null ? pal.accent : null);
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: ListRow(
        title: t(channel.label),
        subtitle: '+${channel.percent}% · $line',
        subtitleColor: tone,
        leading: IconPlate(icon, tint: tint),
        trailing: done
            ? Text(
                t('Verified'),
                style: context.type.rowValue.copyWith(color: pal.ok),
              )
            : trailing,
        chevron: !done && trailing == null && onTap != null,
        onTap: onTap,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.pal.glass,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: context.pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: context.type.eyebrow.copyWith(
              color: context.pal.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}
