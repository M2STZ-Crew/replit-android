import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'national_id_screen.dart';
import 'phone_verify_screen.dart';

const Color _safeGreen = AppColors.ok;

/// Verification Center — the progressive-verification hub. Shows the user's
/// aggregate trust level (GET /auth/me) and the three ways to raise it:
/// Email (+10%), Phone (+40%), and National ID (+50%).
///
/// /auth/me only exposes the aggregate verified_percent + badge (no per-method
/// breakdown), so each method is shown as an action; the header % updates after
/// any step completes.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _me;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _api.getMe();
      if (mounted) setState(() => _me = me);
    } catch (_) {
      // keep previous values
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _percent => (_me?['verified_percent'] as num?)?.toInt() ?? 0;
  String get _badge => (_me?['badge'] as String?) ?? 'yellow';
  bool get _fullyVerified => _badge == 'green_check' || _percent >= 100;

  Color get _badgeColor {
    switch (_badge) {
      case 'green_check':
      case 'green':
        return _safeGreen;
      case 'light_green':
        return const Color(0xFF84CC16);
      default:
        return AppColors.warn;
    }
  }

  String get _badgeLabel {
    switch (_badge) {
      case 'green_check':
        return 'Fully Verified';
      case 'green':
        return 'Verified';
      case 'light_green':
        return 'Partially Verified';
      default:
        return 'Unverified';
    }
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
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhoneVerifyScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openNationalId() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NationalIdScreen()),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            ScreenHeader(
              eyebrow: 'Credibility',
              title: 'Verify your account',
              trailing: _loading
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconWellButton(
                      icon: Icons.refresh_rounded,
                      tint: AppColors.muted,
                      onTap: _load,
                    ),
            ),
            const SizedBox(height: 26),
            _trustHeader(),
            const SizedBox(height: 26),
            const Eyebrow('Three ways to raise it', color: AppColors.accent),
            const SizedBox(height: 12),
            _methodCard(
              icon: Icons.alternate_email,
              title: 'Email address',
              subtitle: 'Confirm your email via a secure link.',
              bonus: '+10%',
              onTap: _openEmail,
            ),
            const SizedBox(height: 10),
            _methodCard(
              icon: Icons.smartphone,
              title: 'Mobile number',
              subtitle: 'Verify your phone with an SMS code.',
              bonus: '+40%',
              onTap: _openPhone,
            ),
            const SizedBox(height: 10),
            _methodCard(
              icon: Icons.badge_outlined,
              title: 'National ID',
              subtitle: 'Upload a government ID and a selfie for review.',
              bonus: '+50%',
              onTap: _openNationalId,
            ),
            const SizedBox(height: 22),
            Panel(
              radius: AppRadius.control,
              color: AppColors.glassDim,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your documents are held privately and used only to '
                      'verify who you are. A National ID is reviewed by an '
                      'administrator before the bonus applies.',
                      style: AppText.meta.copyWith(height: 16 / 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trustHeader() {
    final pct = _percent.clamp(0, 100);
    return Panel(
      padding: const EdgeInsets.all(20),
      color: _badgeColor.withValues(alpha: 0.08),
      border: _badgeColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: AppText.numeral.copyWith(
                  fontSize: 40,
                  color: _badgeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    _badgeLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.tag.copyWith(
                      fontSize: 10,
                      color: _badgeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: AppColors.lineStrong,
              color: _badgeColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _fullyVerified
                ? 'Your account is fully verified. Thank you for keeping '
                      'reports trustworthy.'
                : 'Your level is shown to Fire Volunteer coordinators when they '
                      'review your reports. It never slows an incident down — it '
                      'helps them weigh unverified sources.',
            style: AppText.meta.copyWith(height: 16 / 11),
          ),
        ],
      ),
    );
  }

  Widget _methodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String bonus,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: _fullyVerified ? 0.5 : 1,
      child: Panel(
        onTap: _fullyVerified ? null : onTap,
        color: AppColors.glassDim,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            IconWell(tint: AppColors.accent, icon: icon, size: 44, glyph: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(height: 15 / 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              bonus,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.faint,
            ),
          ],
        ),
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
      if (mounted) setState(() => _message = 'Could not send the email. Check your connection.');
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
          16,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: const SheetHandle(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.alternate_email, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Verify your email',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Text(
                  '+10%',
                  style: TextStyle(
                    color: _safeGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _sent
                  ? "We've sent a verification link to your email. Open it to "
                      'confirm, then return here — your trust level updates '
                      'automatically.'
                  : "We'll email you a secure link. Open it on this device to "
                      'confirm your address and earn +10%.',
              style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: const TextStyle(color: AppColors.accent, fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _sending ? null : (_sent ? () => Navigator.of(context).pop() : _send),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.accentText),
                      )
                    : Text(
                        _sent ? 'DONE' : 'SEND VERIFICATION EMAIL',
                        style: const TextStyle(
                          color: AppColors.accentText,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
            if (_sent) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _sending ? null : _send,
                  child: const Text(
                    'Resend email',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
