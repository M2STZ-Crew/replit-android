import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'call_screen.dart';
import 'edit_profile_screen.dart';
import 'guide_screen.dart';
import 'help_center_screen.dart';
import 'login_screen.dart';
import 'my_reports_screen.dart';
import 'notification_settings_screen.dart';
import 'verification_screen.dart';

const Color _safeGreen = AppColors.ok;

/// "Your account" — reached from the avatar in every screen header, never
/// from the tab bar. That is the v2 design's arrangement and it is the right
/// one: the four tabs are things you do in an emergency, and this is not.
///
/// v1 opened with a coral gradient banner. The design reserves coral for the
/// SOS moment, so identity is a glass card like every other surface.
///
/// Wired to the backend: GET /auth/me (identity + verified_percent + badge),
/// links to My Reports (GET /reports/mine), and logout (POST /auth/logout).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _me;
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
  }

  // ----------------------------------------------------------- getters ---
  String get _name {
    final n = _me?['full_name'] as String?;
    if (n != null && n.trim().isNotEmpty) return n;
    final email = (_me?['email'] as String?) ?? Session.instance.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'RepLiT User';
  }

  String get _email => (_me?['email'] as String?) ?? Session.instance.email ?? '—';

  String get _mobile {
    final m = _me?['mobile'] as String?;
    return (m != null && m.trim().isNotEmpty) ? m : 'Not added';
  }

  String get _dobLabel {
    final d = _me?['date_of_birth'] as String?;
    return (d != null && d.trim().isNotEmpty) ? d : 'Not added';
  }

  String get _genderLabel {
    final g = _me?['gender'] as String?;
    return (g != null && g.trim().isNotEmpty) ? g : 'Not added';
  }

  int get _percent => (_me?['verified_percent'] as num?)?.toInt() ?? 0;

  String get _badge => (_me?['badge'] as String?) ?? 'yellow';

  bool get _fullyVerified => _badge == 'green_check' || _percent >= 100;

  String get _roleLabel {
    switch (_me?['role'] as String?) {
      case 'admin':
        return 'Administrator';
      case 'sub_admin':
        return 'Sub-Admin';
      case 'response_team':
        return 'Response Team';
      default:
        return 'General User';
    }
  }

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

  // ------------------------------------------------------------ actions ---
  Future<void> _openVerification() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
    );
    _load(); // refresh trust level after returning
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            const ScreenHeader(title: 'Your account'),
            const SizedBox(height: 26),
            _identityCard(),
            const SizedBox(height: 22),
            _trustCard(),

            const SizedBox(height: 26),
            const Eyebrow('My account', color: AppColors.accent),
            const SizedBox(height: 12),
            _menuCard([
              _MenuRow(
                Icons.person_outline,
                'Personal information',
                subtitle: 'Name, email, and contact',
                onTap: _personalInfoSheet,
              ),
              _MenuRow(
                Icons.assignment_outlined,
                'Your reports',
                subtitle: 'Incidents you have submitted',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyReportsScreen()),
                ),
              ),
              _MenuRow(
                Icons.verified_user_outlined,
                'Verification',
                trailingText: '$_percent%',
                onTap: _openVerification,
              ),
            ]),

            const SizedBox(height: 22),
            const Eyebrow('App', color: AppColors.accent),
            const SizedBox(height: 12),
            _menuCard([
              _MenuRow(
                Icons.menu_book_outlined,
                'Safety guides',
                subtitle: 'Fire prevention and first aid',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GuideScreen()),
                ),
              ),
              _MenuRow(
                Icons.call_outlined,
                'Emergency hotlines',
                subtitle: 'Tap to dial responders fast',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CallScreen()),
                ),
              ),
              _MenuRow(
                Icons.notifications_none,
                'Notifications',
                subtitle: 'Push alerts for nearby incidents',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 22),
            const Eyebrow('Support', color: AppColors.accent),
            const SizedBox(height: 12),
            _menuCard([
              _MenuRow(
                Icons.help_outline,
                'Help centre',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                ),
              ),
              _MenuRow(Icons.info_outline, 'About RepLiT', onTap: _showAbout),
            ]),

            const SizedBox(height: 30),
            AppButton.danger(
              'Log out',
              icon: Icons.logout_rounded,
              busy: _loggingOut,
              onPressed: _loggingOut ? null : _logout,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'REPLIT · PASAY CITY · V1.0.0',
                style: AppText.tag.copyWith(color: AppColors.faint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- identity ---
  /// The design replaces v1's coral gradient banner with a glass card. Coral is
  /// reserved for the SOS moment; a profile screen is not one.
  Widget _identityCard() {
    return Panel(
      padding: const EdgeInsets.all(20),
      color: AppColors.glassDim,
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.surfaceSolid,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Image.asset(Art.avatar, width: 42, height: 42),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(
                    fontSize: 18,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _fullyVerified ? null : _openVerification,
                  child: Tag(
                    _fullyVerified ? 'Fully verified' : _badgeLabel,
                    color: _badgeColor,
                    dot: !_fullyVerified,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- trust card ---
  Widget _trustCard() {
    final pct = _percent.clamp(0, 100);
    return Panel(
      padding: const EdgeInsets.all(20),
      color: _badgeColor.withValues(alpha: 0.07),
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
                  fontSize: 36,
                  color: _badgeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Eyebrow('Trust level', color: _badgeColor),
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
                : 'Phone +40%, National ID +50%, email +10%. A verified report '
                      'is trusted faster.',
            style: AppText.meta.copyWith(height: 16 / 11),
          ),
          if (!_fullyVerified) ...[
            const SizedBox(height: 16),
            AppButton('Get verified', height: 46, onPressed: _openVerification),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------- menu ---
  Widget _menuCard(List<_MenuRow> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(_menuRowTile(rows[i]));
      if (i < rows.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(left: 64),
            child: Divider(),
          ),
        );
      }
    }
    return Panel(
      padding: EdgeInsets.zero,
      color: AppColors.glassDim,
      child: Column(children: children),
    );
  }

  Widget _menuRowTile(_MenuRow row) {
    return InkWell(
      onTap: row.onTap,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            IconWell(
              tint: AppColors.accent,
              icon: row.icon,
              size: 38,
              glyph: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: AppColors.onBackground,
                    ),
                  ),
                  if (row.subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      row.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta,
                    ),
                  ],
                ],
              ),
            ),
            if (row.trailingText != null) ...[
              const SizedBox(width: 10),
              Text(
                row.trailingText!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
            ],
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

  // ------------------------------------------------------------ sheets ---
  void _personalInfoSheet() {
    final id = (_me?['id'] as String?);
    final shortId = (id != null && id.length >= 8) ? '${id.substring(0, 8)}…' : (id ?? '—');
    _sheet(
      title: 'Personal Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Full name', _name),
          _infoRow('Email', _email),
          _infoRow('Mobile number', _mobile),
          _infoRow('Date of birth', _dobLabel),
          _infoRow('Gender', _genderLabel),
          _infoRow('Account type', _roleLabel),
          _infoRow('Trust level', '$_percent% • $_badgeLabel'),
          _infoRow('Account ID', shortId),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              _openEditProfile();
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.accent),
              ),
              child: const Text(
                'EDIT PROFILE',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Email and account type are managed by your administrator.',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfile() async {
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

  void _showAbout() {
    _sheet(
      title: 'About RepLiT',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RepLiT is a fire-volunteer emergency response platform for Pasay '
            'City. Report incidents, see active areas and safe sites near you, '
            'learn fire-safety basics, and reach responders fast.',
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 16),
          Text(
            'In a real emergency, trigger an SOS from the ALERT tab or dial 911.',
            style: TextStyle(color: AppColors.accent, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Eyebrow(label, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 17 / 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sheet({required String title, required Widget child}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              Text(title.toUpperCase(), style: AppText.title),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow {
  const _MenuRow(
    this.icon,
    this.title, {
    this.subtitle,
    this.trailingText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;
}
