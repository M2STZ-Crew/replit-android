import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../models/verification_state.dart';
import '../sound/sound_cues.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import '../widgets/notification_bell.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'login_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';
import 'verification_screen.dart';

/// "15 Profile" from the REPLIT-OVERHAUL Figma — "Your profile", now a tab.
///
/// Wired to GET /auth/me (name, email, mobile) and GET /verification/status
/// (the ring, the badge, and which step to suggest next). Settings are only
/// the ones that do something: "Barangay alerts" registers or unregisters this
/// phone for pushes, and "Notification sounds" is the "salamat" cue (v10
/// §2.8). The frame's "Share location always" and "Language" are left out —
/// there is no background sharing for residents and no second language yet,
/// and a switch that changes nothing is a lie (§2.7.1). Below the frame: your
/// reports, the notification inbox (the bell moved here from the SOS screen),
/// help, and log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  Map<String, dynamic>? _me;
  VerificationState _verification = VerificationState.empty;
  bool _alerts = true;
  bool _sounds = true;
  bool _alertsBusy = false;
  bool _testing = false;
  bool _loggingOut = false;

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
      // Falls back to the cached session email below.
    }
    try {
      final status = await _api.getVerificationStatus();
      if (mounted) {
        setState(() => _verification = VerificationState.fromJson(status));
      }
    } catch (_) {
      // The ring stays empty rather than guessing.
    }
    try {
      final alerts = await PushService.instance.isEnabled();
      final sounds = await SoundCues.instance.reportSentEnabled();
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _sounds = sounds;
        });
      }
    } catch (_) {
      // Keep the defaults.
    }
  }

  String get _name {
    final n = _me?['full_name'] as String?;
    if (n != null && n.trim().isNotEmpty) return n;
    final email = _email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'RepLiT user';
  }

  String? get _email => (_me?['email'] as String?) ?? Session.instance.email;

  String? get _mobile {
    final m = _me?['mobile'] as String?;
    return (m != null && m.trim().isNotEmpty) ? m : null;
  }

  // ------------------------------------------------------------ actions ---
  Future<void> _openVerification() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VerificationScreen()));
    _load();
  }

  Future<void> _editProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          fullName: _me?['full_name'] as String?,
          mobile: _me?['mobile'] as String?,
          dateOfBirth: _me?['date_of_birth'] as String?,
          gender: _me?['gender'] as String?,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _setAlerts(bool on) async {
    setState(() {
      _alerts = on;
      _alertsBusy = true;
    });
    await PushService.instance.setEnabled(on);
    if (mounted) setState(() => _alertsBusy = false);
  }

  Future<void> _setSounds(bool on) async {
    setState(() => _sounds = on);
    await SoundCues.instance.setReportSentEnabled(on);
    // Let the resident hear what they just turned on.
    if (on) SoundCues.instance.playReportSent();
  }

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    String message;
    try {
      message = await _api.sendTestPush();
    } on ApiException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Could not send a test alert.';
    }
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    final navigator = Navigator.of(context);
    await PushService.instance.unregister();
    await _api.logout();
    await Session.instance.clear();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _about() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SheetHandle()),
              Text('ABOUT REPLIT', style: AppText.title),
              SizedBox(height: 14),
              Text(
                'RepLiT is Barangay 76\'s emergency reporting network for '
                'Pasay City. Report an incident, see what is happening near '
                'you and where the shelters are, learn the basics, and reach '
                'responders fast.',
                style: AppText.body,
              ),
              SizedBox(height: 14),
              Text(
                'In a real emergency, hold SOS or call 911.',
                style: AppText.bodySm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    // As a tab it is the only route: it carries the bar and has nothing to go
    // back to. Opened from elsewhere it keeps a back chevron.
    final pushed = Navigator.of(context).canPop();
    final next = _verification.nextStep;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.profile),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              ScreenHeader(
                eyebrow: 'Account',
                title: 'Your profile',
                showBack: pushed,
                trailing: const NotificationBell(),
              ),
              const SizedBox(height: 20),
              _identity(),
              if (next != null) ...[
                const SizedBox(height: 10),
                _nextStep(next),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Eyebrow('Account details', color: AppColors.muted),
                  ),
                  GestureDetector(
                    onTap: _editProfile,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Eyebrow('Edit', color: AppColors.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _details(),
              const SizedBox(height: 20),
              const Eyebrow('Settings', color: AppColors.muted),
              const SizedBox(height: 8),
              _Toggle(
                title: 'Barangay alerts',
                line: 'Fires reported within 300 m, and news on your reports',
                value: _alerts,
                busy: _alertsBusy,
                onChanged: _setAlerts,
              ),
              const SizedBox(height: 8),
              _Toggle(
                title: 'Notification sounds',
                line: 'A short cue when a report sends',
                value: _sounds,
                onChanged: _setSounds,
              ),
              const SizedBox(height: 8),
              _Link(
                title: 'Send a test alert',
                line: 'Check this phone receives them',
                busy: _testing,
                onTap: _testing ? null : _sendTest,
              ),
              const SizedBox(height: 20),
              const Eyebrow('More', color: AppColors.muted),
              const SizedBox(height: 8),
              _Link(
                title: 'Your reports',
                line: 'Everything you have sent, and where it got to',
                onTap: () => _push(const MyReportsScreen()),
              ),
              const SizedBox(height: 8),
              _Link(
                title: 'Notifications',
                line: 'Alerts and updates sent to you',
                onTap: () => _push(const NotificationsScreen()),
              ),
              const SizedBox(height: 8),
              _Link(
                title: 'Help centre',
                line: 'How reporting works, and what happens next',
                onTap: () => _push(const HelpCenterScreen()),
              ),
              const SizedBox(height: 8),
              _Link(
                title: 'About RepLiT',
                line: 'Barangay 76, Pasay City',
                onTap: _about,
              ),
              const SizedBox(height: 24),
              AppButton.danger(
                'Log out',
                icon: Icons.logout_rounded,
                busy: _loggingOut,
                onPressed: _loggingOut ? null : _logout,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'REPLIT · BARANGAY 76 · V1.0.0',
                  style: AppText.tag.copyWith(color: AppColors.faint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar in its verification ring, the name, and the badge.
  Widget _identity() {
    final v = _verification;
    final pct = v.percent.clamp(0, 100);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.lineStrong,
                    color: v.color,
                  ),
                ),
                Opacity(
                  opacity: 0.9,
                  child: Image.asset(Art.avatar, width: 38, height: 38),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_name.toUpperCase(), style: AppText.headline),
                const SizedBox(height: 7),
                Tag('$pct% verified', color: v.color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Add your National ID for +50%" — whatever is most worth doing next.
  Widget _nextStep(VerifyChannel next) {
    final inReview = _verification.isInReview(next);
    final (String title, String line) = switch (next) {
      VerifyChannel.nationalId when inReview => (
        'Your National ID is being checked',
        'Its 50% applies once an administrator approves it',
      ),
      VerifyChannel.nationalId => (
        'Add your National ID for +50%',
        'Responders weigh verified reports more heavily',
      ),
      VerifyChannel.email => (
        'Confirm your email for +10%',
        'One tap on a link we send you',
      ),
      VerifyChannel.phone => (
        'Add your mobile number for +40%',
        'Confirmed with a code by SMS',
      ),
    };
    return Semantics(
      button: true,
      label: '$title. $line',
      excludeSemantics: true,
      child: Panel(
        radius: AppRadius.card,
        color: AppColors.accent.withValues(alpha: 0.10),
        border: AppColors.accent.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        onTap: _openVerification,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppText.rowTitleLg),
                  const SizedBox(height: 5),
                  Text(
                    line,
                    style: AppText.caption.copyWith(color: AppColors.label),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _details() {
    final emailOk = _verification.isVerified(VerifyChannel.email);
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: _email ?? '—',
            action: emailOk ? 'Verified' : 'Verify',
            actionColor: emailOk ? AppColors.ok : AppColors.accent,
            onTap: emailOk ? null : _openVerification,
          ),
          const Divider(),
          _DetailRow(
            icon: Icons.smartphone_rounded,
            label: 'Mobile',
            value: _mobile ?? 'Not added yet',
            muted: _mobile == null,
            action: _mobile == null ? 'Add' : null,
            actionColor: AppColors.accent,
            onTap: _mobile == null ? _editProfile : null,
          ),
        ],
      ),
    );
  }
}

/// A row in "Account details": icon, label, value, and what a tap does.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionColor,
    this.action,
    this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? action;
  final Color actionColor;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.accent),
            const SizedBox(width: 14),
            SizedBox(width: 58, child: Eyebrow(label, color: AppColors.muted)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowValue.copyWith(
                  color: muted ? AppColors.muted : AppColors.onBackground,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 10),
              Text(
                action!.toUpperCase(),
                style: AppText.tag.copyWith(color: actionColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A 58px settings row with a switch.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.line,
    required this.value,
    required this.onChanged,
    this.busy = false,
  });

  final String title;
  final String line;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.label),
                const SizedBox(height: 5),
                Text(line, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: busy ? null : onChanged),
        ],
      ),
    );
  }
}

/// A 58px row that opens something.
class _Link extends StatelessWidget {
  const _Link({
    required this.title,
    required this.line,
    this.onTap,
    this.busy = false,
  });

  final String title;
  final String line;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.card,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.label),
                const SizedBox(height: 5),
                Text(line, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
        ],
      ),
    );
  }
}
