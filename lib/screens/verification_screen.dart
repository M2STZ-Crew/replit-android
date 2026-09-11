import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/session.dart';
import '../models/verification_state.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'national_id_screen.dart';
import 'phone_verify_screen.dart';

/// "16 Verification" from the REPLIT-OVERHAUL Figma — "Verify your account".
///
/// Reads GET /verification/status, so each channel says where it actually
/// stands: done, submitted and awaiting an administrator, refused, or not
/// started — the aggregate percent alone cannot tell those apart, and a
/// resident told to upload their ID again while the first is still in the
/// queue would do exactly that. Phone is shown unavailable while no SMS
/// provider is chosen ([kPhoneVerificationOpen], §10.3).
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => _EmailVerifySheet(api: _api),
    );
    _load();
  }

  Future<void> _openPhone() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PhoneVerifyScreen()));
    if (changed == true) _load();
  }

  Future<void> _openNationalId() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const NationalIdScreen()));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              const Align(alignment: Alignment.centerLeft, child: BackWell()),
              const SizedBox(height: 28),
              const Text('VERIFY YOUR ACCOUNT', style: AppText.heading1),
              const SizedBox(height: 12),
              const Text(
                'Verification never blocks a report. It tells responders how '
                'much weight to give what you send.',
                style: AppText.body,
              ),
              const SizedBox(height: 24),
              _progress(s),
              const SizedBox(height: 24),
              const Eyebrow('Channels', color: AppColors.muted),
              const SizedBox(height: 10),
              _phone(s),
              const SizedBox(height: 8),
              _nationalId(s),
              const SizedBox(height: 8),
              _emailRow(s),
              const SizedBox(height: 24),
              const Eyebrow('Badges', color: AppColors.muted),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(child: _Legend('Under 50', AppColors.warn)),
                  SizedBox(width: 8),
                  Expanded(child: _Legend('50 to 89', AppColors.ok)),
                  SizedBox(width: 8),
                  Expanded(child: _Legend('90 to 99', AppColors.ok)),
                  SizedBox(width: 8),
                  Expanded(child: _Legend('100', AppColors.ok)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Documents are held privately and used only to confirm who '
                'you are. A National ID is checked by an administrator before '
                'its 50% applies.',
                style: AppText.caption,
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
                  style: AppText.numeralXl.copyWith(color: s.color),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 22),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: s.color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  s.badgeName.toUpperCase(),
                  style: AppText.tag.copyWith(color: s.color),
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
              backgroundColor: AppColors.lineStrong,
              color: s.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phone(VerificationState s) {
    const c = VerifyChannel.phone;
    if (s.isVerified(c)) {
      return const _Channel(channel: c, line: 'Verified', done: true);
    }
    if (!kPhoneVerificationOpen) {
      return const _Channel(
        channel: c,
        line: 'Unavailable while we change SMS provider',
        lineColor: AppColors.warn,
        trailing: Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.warn,
        ),
        dimmed: true,
      );
    }
    return _Channel(
      channel: c,
      line: 'Confirm it with a code by SMS',
      onTap: _openPhone,
    );
  }

  Widget _nationalId(VerificationState s) {
    const c = VerifyChannel.nationalId;
    if (s.isVerified(c)) {
      return const _Channel(channel: c, line: 'Verified', done: true);
    }
    if (s.isInReview(c)) {
      return const _Channel(
        channel: c,
        line: 'Submitted — an administrator is checking it',
        lineColor: AppColors.warn,
        trailing: Icon(Icons.schedule_rounded, size: 16, color: AppColors.warn),
      );
    }
    return _Channel(
      channel: c,
      line: s.isRefused(c)
          ? 'Not accepted — take the photos again'
          : 'Camera only — the photo and selfie must be live',
      lineColor: s.isRefused(c) ? AppColors.live : null,
      onTap: _openNationalId,
    );
  }

  Widget _emailRow(VerificationState s) {
    const c = VerifyChannel.email;
    if (s.isVerified(c)) {
      return _Channel(channel: c, line: _email ?? 'Verified', done: true);
    }
    return _Channel(
      channel: c,
      line: s.status(c) == 'pending'
          ? 'Link sent — open it on this phone'
          : 'Tap for a confirmation link',
      onTap: _openEmail,
    );
  }
}

/// One channel row: what it is worth, where it stands, what a tap does.
class _Channel extends StatelessWidget {
  const _Channel({
    required this.channel,
    required this.line,
    this.lineColor,
    this.trailing,
    this.onTap,
    this.done = false,
    this.dimmed = false,
  });

  final VerifyChannel channel;
  final String line;
  final Color? lineColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool done;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final tone = done ? AppColors.ok : AppColors.accent;
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Semantics(
        button: onTap != null,
        label: '${channel.label}, plus ${channel.percent} percent. $line',
        excludeSemantics: true,
        child: Panel(
          radius: AppRadius.card,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: done ? 0.14 : 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${channel.percent}%',
                  style: AppText.cardTitleSm.copyWith(color: tone),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(channel.label, style: AppText.rowTitleLg),
                    const SizedBox(height: 5),
                    Text(
                      line,
                      style: AppText.caption.copyWith(
                        color: lineColor ?? AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  (done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.ok,
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.accent,
                        )),
            ],
          ),
        ),
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
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
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
            style: AppText.eyebrow.copyWith(color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }
}

/// Email verification bottom sheet: send the link, then prompt the user to open
/// it and come back. Confirmation happens in the browser (GET .../email/confirm).
class _EmailVerifySheet extends StatefulWidget {
  const _EmailVerifySheet({required this.api});

  final ApiClient api;

  @override
  State<_EmailVerifySheet> createState() => _EmailVerifySheetState();
}

class _EmailVerifySheetState extends State<_EmailVerifySheet> {
  bool _sending = false;
  bool _sent = false;
  String? _message;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final msg = await widget.api.requestEmailVerification();
      if (mounted) {
        setState(() {
          _sent = true;
          _message = msg;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not send the email. Check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          10,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetHandle()),
            Row(
              children: [
                const Expanded(
                  child: Text('CONFIRM YOUR EMAIL', style: AppText.title),
                ),
                Text(
                  '+10%',
                  style: AppText.cardTitleSm.copyWith(color: AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _sent
                  ? "The link is on its way. Open it on this phone, then come "
                        'back — your level updates by itself.'
                  : "We'll email you a secure link. Opening it on this phone "
                        'confirms the address.',
              style: AppText.body,
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: AppText.caption.copyWith(color: AppColors.accent),
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              _sent ? 'Done' : 'Send the link',
              busy: _sending,
              onPressed: _sending
                  ? null
                  : _sent
                  ? () => Navigator.of(context).pop()
                  : _send,
            ),
            if (_sent) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _sending ? null : _send,
                child: const Text('Send it again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
