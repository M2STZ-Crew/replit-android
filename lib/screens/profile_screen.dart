import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../app_version.dart';
import 'change_password_screen.dart';
import '../location/location_beacon.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../models/verification_state.dart';
import '../privacy/contact_mask.dart';
import '../updates/app_updates.dart';
import '../models/active_report.dart';
import '../api/report_queue.dart';
import '../theme.dart';
import '../tutorial/practice.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/coordinator_kit.dart';
import '../widgets/design.dart';
import '../widgets/notification_bell.dart';
import '../widgets/theme_picker.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'login_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';
import 'verification_screen.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';
import '../i18n/language_switch.dart';

/// "15 Profile" from the REPLIT-OVERHAUL Figma — "Your profile", now a tab.
///
/// Wired to GET /auth/me (name, email, mobile) and GET /verification/status
/// (the ring, the badge, and which step to suggest next). Settings are only
/// the ones that do something: "Barangay alerts" registers or unregisters this
/// phone for pushes. "Notification sounds" went with the "salamat" cue it
/// switched (v1.12.23: sending a report plays nothing). The frame's "Share
/// location always" and "Language" are left out —
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
  bool _alertsBusy = false;

  /// Location allowed "All the time" (Android): fire alerts while closed.
  bool _allTheTime = false;
  bool _testing = false;
  String? _testNote;
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
    unawaited(_loadClosedAlerts());
    try {
      final alerts = await PushService.instance.isEnabled();
      if (mounted) setState(() => _alerts = alerts);
    } catch (_) {
      // Keep the defaults.
    }
  }

  String get _name {
    final n = _me?['full_name'] as String?;
    if (n != null && n.trim().isNotEmpty) return n;
    final email = _email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return t('RepLiT user');
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

  /// Whether location is allowed "All the time", which is what lets fire
  /// alerts find the resident while RepLiT is closed (LocationBeacon).
  Future<void> _loadClosedAlerts() async {
    if (!_canAskAllTheTime) return;
    try {
      final always =
          await Geolocator.checkPermission() == LocationPermission.always;
      if (mounted) setState(() => _allTheTime = always);
    } catch (_) {
      // Shown as not allowed.
    }
  }

  /// Ask for location "All the time": the screen says why first, then the
  /// phone asks (from Android 11 that is a page in Settings). Afterwards the
  /// closed-app reports are scheduled, or not, to match.
  Future<void> _allowAllTheTime() async {
    if (_allTheTime) {
      // Already on: Settings is where it is turned off again.
      await Geolocator.openAppSettings();
      return;
    }
    final go = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Fire alerts with the app closed')),
        content: Text(
          t(
            'RepLiT tells you about a fire within 100 m of where you are now. '
            'To know that while the app is closed, it needs your location '
            '"All the time". It sends it to RepLiT about every 15 minutes, '
            'and only for these alerts.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('Not now')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('Allow')),
          ),
        ],
      ),
    );
    if (go != true) return;
    try {
      var perm = await Geolocator.checkPermission();
      // While-in-use first; Android asks for "All the time" only after it.
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      // The row says where it stands after the reload below.
    }
    await _loadClosedAlerts();
    await LocationBeacon.syncClosed(alertsOn: _alerts);
  }

  /// Only Android has "All the time" to give here.
  static bool get _canAskAllTheTime =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _setAlerts(bool on) async {
    setState(() {
      _alerts = on;
      _alertsBusy = true;
    });
    await PushService.instance.setEnabled(on);
    if (mounted) setState(() => _alertsBusy = false);
  }

  /// The answer goes on the row, not in a banner: the test alert itself
  /// arrives as a banner (or in the shade) moments later, and a second banner
  /// would queue behind it and hold the screen for its whole run.
  Future<void> _sendTest() async {
    setState(() {
      _testing = true;
      _testNote = null;
    });
    String note;
    try {
      await _api.sendTestPush();
      note = 'Sent. It should reach this phone in a few seconds.';
    } on ApiException catch (e) {
      note = e.message;
    } catch (_) {
      note = 'Could not send a test alert. Check your signal.';
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testNote = note;
    });
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

  /// The LIT tutorial again, on the real screens: never over a report in
  /// progress or one waiting to send, which those screens belong to.
  void _replayTutorial() {
    if (ActiveReportStore.mine != null ||
        ReportQueue.instance.pending.value.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'You have a report in progress. Replay the tutorial once it is '
              'done.',
            ),
          ),
        ),
      );
      return;
    }
    LitPractice.open(
      context,
      account: Session.instance.email ?? '',
      replay: true,
    );
  }

  void _about() {
    showAppSheet<void>(
      context: context,
      backgroundColor: context.pal.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SheetHandle()),
              Text(t('ABOUT REPLIT'), style: context.type.title),
              SizedBox(height: 14),
              Text(
                t(
                  'RepLiT is the emergency reporting network for Pasay City. '
                  'Report an incident, see what is happening near '
                  'you and where the shelters are, learn the basics, and reach '
                  'responders fast.',
                ),
                style: context.type.body,
              ),
              SizedBox(height: 14),
              Text(
                t('In a real emergency, hold SOS or call 911.'),
                style: context.type.bodySm,
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
      backgroundColor: context.pal.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.profile),
      body: SafeArea(
        bottom: false,
        child: ScrollFade(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              children: [
                ScreenHeader(
                  eyebrow: t('Account'),
                  title: t('Your profile'),
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
                    Expanded(
                      child: Eyebrow(
                        t('Account details'),
                        color: context.pal.muted,
                      ),
                    ),
                    // Shows or hides the email and mobile below.
                    const ContactMaskToggle(),
                    GestureDetector(
                      onTap: _editProfile,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Eyebrow(t('Edit'), color: context.pal.accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _details(),
                const SizedBox(height: 20),
                SectionHeader(t('Settings')),
                const SizedBox(height: 12),
                _Toggle(
                  icon: AppIcons.notificationsActive,
                  title: t('Barangay alerts'),
                  line: t(
                    'Fires reported within 100 m, and news on your reports',
                  ),
                  value: _alerts,
                  busy: _alertsBusy,
                  onChanged: _setAlerts,
                ),
                if (_canAskAllTheTime && _alerts) ...[
                  const SizedBox(height: 8),
                  _Link(
                    icon: AppIcons.myLocation,
                    title: t('Fire alerts with the app closed'),
                    line: _allTheTime
                        ? t(
                            'On. Fires within 100 m reach you even when RepLiT '
                            'is closed.',
                          )
                        : t(
                            'Allow location "All the time" so fires within '
                            '100 m reach you when RepLiT is closed.',
                          ),
                    onTap: _allowAllTheTime,
                  ),
                ],
                const SizedBox(height: 8),
                // System, Light or Dark (Figma 14T, with System).
                const ThemeRow(),
                const SizedBox(height: 8),
                // As on a coordinator's and a responder's Profile.
                ListRow(
                  leading: const IconPlate(AppIcons.campaign),
                  title: t('Language'),
                  subtitle: t('Your alerts come in the same language'),
                ),
                const SizedBox(height: 8),
                LanguageSwitch(api: _api),
                const SizedBox(height: 8),
                _Link(
                  icon: AppIcons.key,
                  title: t('Change password'),
                  line: t('Signs you out of your other phones'),
                  onTap: () => ChangePasswordScreen.open(context, api: _api),
                ),
                const SizedBox(height: 8),
                _Link(
                  icon: AppIcons.send,
                  title: t('Send a test alert'),
                  line: _testNote ?? t('Check this phone receives them'),
                  busy: _testing,
                  onTap: _testing ? null : _sendTest,
                ),
                const SizedBox(height: 20),
                SectionHeader(t('More')),
                const SizedBox(height: 12),
                _Link(
                  icon: AppIcons.assignment,
                  title: t('Your reports'),
                  line: t('Everything you have sent, and where it got to'),
                  onTap: () => _push(const MyReportsScreen()),
                ),
                const SizedBox(height: 8),
                _Link(
                  icon: AppIcons.notifications,
                  title: t('Notifications'),
                  line: t('Alerts and updates sent to you'),
                  onTap: () => _push(const NotificationsScreen()),
                ),
                const SizedBox(height: 8),
                // The LIT tutorial, watched again (12 November 2026: "put
                // the replay tutorial in profile"; answered: Profile
                // only).
                _Link(
                  icon: AppIcons.restartAlt,
                  title: t('Replay the tutorial'),
                  line: t('Practice a report with Lit. Nothing is sent.'),
                  onTap: _replayTutorial,
                ),
                const SizedBox(height: 8),
                _Link(
                  icon: AppIcons.help,
                  title: t('Help center'),
                  line: t('How reporting works, and what happens next'),
                  onTap: () => _push(const HelpCenterScreen()),
                ),
                const SizedBox(height: 8),
                _Link(
                  icon: AppIcons.info,
                  title: t('About RepLiT'),
                  line: t('Emergency reporting for Pasay City'),
                  onTap: _about,
                ),
                if (AppUpdates.supported) ...[
                  const SizedBox(height: 8),
                  _Link(
                    icon: AppIcons.download,
                    title: t('Check for updates'),
                    line: AppVersion.label.isEmpty
                        ? t('Get the newest version of RepLiT')
                        : t('Version {v} installed', {'v': AppVersion.label}),
                    onTap: () => showUpdateSheet(context),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton.danger(
                  t('Log out'),
                  icon: AppIcons.logout,
                  busy: _loggingOut,
                  onPressed: _loggingOut ? null : _logout,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    // The build as App Distribution lists it: "1.11.0 (57)".
                    [
                      t('REPLIT · PASAY CITY'),
                      if (AppVersion.label.isNotEmpty) 'V${AppVersion.label}',
                    ].join(' · '),
                    style: context.type.tag.copyWith(color: context.pal.faint),
                  ),
                ),
              ],
            ),
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
                    backgroundColor: context.pal.lineStrong,
                    color: v.colour(context.pal),
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
                Text(_name.toUpperCase(), style: context.type.headline),
                const SizedBox(height: 7),
                Tag('$pct% verified', color: v.colour(context.pal)),
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
        t('Your National ID is being checked'),
        t('Its 50% applies once an administrator approves it'),
      ),
      VerifyChannel.nationalId => (
        t('Add your National ID for +50%'),
        t('Responders weigh verified reports more heavily'),
      ),
      VerifyChannel.email => (
        t('Confirm your email for +10%'),
        t('One tap on a link we send you'),
      ),
      VerifyChannel.phone => (
        t('Add your mobile number for +40%'),
        t('Confirmed with a code by SMS'),
      ),
    };
    return Semantics(
      button: true,
      label: '$title. $line',
      excludeSemantics: true,
      child: Panel(
        radius: AppRadius.card,
        color: context.pal.accent.withValues(alpha: 0.10),
        border: context.pal.accent.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        onTap: _openVerification,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.type.rowTitleLg),
                  const SizedBox(height: 5),
                  Text(
                    line,
                    style: context.type.caption.copyWith(
                      color: context.pal.label,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(AppIcons.chevronRight, size: 18, color: context.pal.accent),
          ],
        ),
      ),
    );
  }

  /// The email and mobile number, masked until the eye above them is tapped.
  Widget _details() => ValueListenableBuilder<bool>(
    valueListenable: ContactMask.hidden,
    builder: (context, hidden, _) => _detailRows(hidden),
  );

  Widget _detailRows(bool hidden) {
    final emailOk = _verification.isVerified(VerifyChannel.email);
    final email = _email;
    final mobile = _mobile;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DetailRow(
            icon: AppIcons.mail,
            label: t('Email'),
            value: email == null
                ? '—'
                : hidden
                ? ContactMask.email(email)
                : email,
            action: emailOk ? t('Verified') : t('Verify'),
            actionColor: emailOk ? context.pal.ok : context.pal.accent,
            onTap: emailOk ? null : _openVerification,
          ),
          const Divider(),
          _DetailRow(
            icon: AppIcons.smartphone,
            label: t('Mobile'),
            value: mobile == null
                ? t('Not added yet')
                : hidden
                ? ContactMask.mobile(mobile)
                : mobile,
            muted: _mobile == null,
            action: _mobile == null ? t('Add') : null,
            actionColor: context.pal.accent,
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
            Icon(icon, size: 17, color: context.pal.accent),
            const SizedBox(width: 14),
            SizedBox(
              width: 58,
              child: Eyebrow(label, color: context.pal.muted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.rowValue.copyWith(
                  color: muted ? context.pal.muted : context.pal.onBackground,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 10),
              Text(
                action!.toUpperCase(),
                style: context.type.tag.copyWith(color: actionColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A settings row with a switch: the shared [ListRow], icon plate first, as
/// on a coordinator's and a responder's Profile (8 November: the resident's
/// rows had no icons where the coordinator's did).
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.title,
    required this.line,
    required this.value,
    required this.onChanged,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String line;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: IconPlate(icon),
      title: title,
      subtitle: line,
      trailing: Switch(value: value, onChanged: busy ? null : onChanged),
      onTap: busy ? null : () => onChanged(!value),
    );
  }
}

/// A row that opens something: the shared [ListRow], icon plate first, with
/// a chevron, or a spinner while it works.
class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.line,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String line;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: IconPlate(icon),
      title: title,
      subtitle: line,
      chevron: !busy,
      trailing: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: onTap,
    );
  }
}
