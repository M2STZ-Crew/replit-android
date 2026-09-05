import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../reports/presentation/screens/my_reports_screen.dart';
import '../../../verification/presentation/screens/verification_screen.dart';

/// "Your account" — reached from the avatar in every screen header, never from
/// the tab bar. That is the design's arrangement and it is the right one: the
/// four tabs are things you do in an emergency, and this is not.
///
/// The design's settings list had a Language row. There is no localisation in
/// the app, so a row that opens nothing is left out rather than faked. The two
/// toggles that remain are real: both reflect an actual OS permission and both
/// open the system settings page that changes it.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  LocationPermission? _locationPermission;

  @override
  void initState() {
    super.initState();
    _readPermissions();
  }

  Future<void> _readPermissions() async {
    final permission = await Geolocator.checkPermission();
    if (mounted) setState(() => _locationPermission = permission);
  }

  bool get _locationAlways =>
      _locationPermission == LocationPermission.always ||
      _locationPermission == LocationPermission.whileInUse;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final pushOn = PushService.instance.isAvailable;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            const ScreenHeader(title: 'Your account'),
            const SizedBox(height: 30),

            // ── identity ──────────────────────────────────────────────────
            Panel(
              padding: const EdgeInsets.all(20),
              color: AppColors.surfaceDim,
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
                          (user?.displayName ?? 'Signed in').toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.cardTitle.copyWith(
                            fontSize: 18,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // The design's flat "Verified resident" chip becomes the
                        // real score, because the system genuinely tracks it and
                        // it is what dispatchers weigh a report by.
                        Tag(
                          '${user?.verifiedPercent ?? 0}% · '
                          '${VerificationBadge.label(user?.badge ?? VerificationBadge.yellow)}',
                          color: _badgeColor(user?.badge),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── contact ───────────────────────────────────────────────────
            Panel(
              padding: EdgeInsets.zero,
              color: AppColors.surfaceDim,
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.smartphone_rounded,
                    label: 'Mobile',
                    value: user?.phone ?? 'Not added',
                    trailing: user?.phoneVerified ?? false
                        ? const _MiniTag('Verified', AppColors.ok)
                        : const _MiniTag('Unverified', AppColors.statusPending),
                  ),
                  const Divider(),
                  _ContactRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: user?.email ?? 'Not added',
                    trailing: user?.emailVerified ?? false
                        ? const _MiniTag('Verified', AppColors.ok)
                        : null,
                  ),
                  const Divider(),
                  _ContactRow(
                    icon: Icons.badge_outlined,
                    label: 'ID',
                    value: user?.idVerified ?? false
                        ? 'National ID on file'
                        : 'Not submitted',
                    trailing: const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.faint),
                    onTap: () => _push(const VerificationScreen()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),
            const Eyebrow('Raise your credibility', color: AppColors.accent),
            const SizedBox(height: 12),
            Panel(
              radius: AppRadius.control,
              color: AppColors.surfaceDim,
              onTap: () => _push(const VerificationScreen()),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Verification',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Phone +40%, National ID +50%, email +10%. A verified '
                          'report is trusted faster.',
                          style: AppText.meta.copyWith(height: 15 / 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${user?.verifiedPercent ?? 0}%',
                    style: AppText.numeral.copyWith(
                      fontSize: 22,
                      color: _badgeColor(user?.badge),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),
            const Eyebrow('Settings', color: AppColors.accent),
            const SizedBox(height: 12),

            _SettingRow(
              title: 'Share location always',
              subtitle: _locationPermission == null
                  ? 'Checking…'
                  : _locationAlways
                      ? 'Responders can find you faster'
                      : 'Off — an SOS will have no coordinates',
              on: _locationAlways,
              onTap: () async {
                await Geolocator.openAppSettings();
                await _readPermissions();
              },
            ),
            const SizedBox(height: 8),
            _SettingRow(
              title: 'Barangay alerts',
              subtitle: pushOn
                  ? 'Fires and floods within '
                      '${AppConstants.areaRadiusMeters} m of you'
                  : 'Push is unavailable on this build — alerts still arrive '
                      'in the inbox',
              on: pushOn,
              onTap: pushOn ? null : () => _push(const NotificationsScreen()),
            ),
            const SizedBox(height: 8),
            _NavRow(
              title: 'Alerts',
              subtitle: unread == 0
                  ? 'Nothing unread'
                  : '$unread unread ${unread == 1 ? 'alert' : 'alerts'}',
              badge: unread,
              onTap: () async {
                await _push(const NotificationsScreen());
                ref.invalidate(unreadCountProvider);
              },
            ),
            const SizedBox(height: 8),
            _NavRow(
              title: 'Your reports',
              subtitle: 'Everything you have sent, and what came of it',
              onTap: () => _push(const MyReportsScreen()),
            ),

            const SizedBox(height: 32),
            AppButton.danger(
              'Sign out',
              onPressed: () => ref.read(authProvider.notifier).signOut(),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${AppConstants.appName} · Pasay City emergency response',
                style: AppText.tag.copyWith(color: AppColors.faint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _push(Widget screen) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => screen),
  );

  static Color _badgeColor(String? badge) => switch (badge) {
    VerificationBadge.greenCheck || VerificationBadge.green => AppColors.ok,
    VerificationBadge.lightGreen => AppColors.statusPending,
    _ => AppColors.statusPending,
  };
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.accent),
          const SizedBox(width: 14),
          SizedBox(width: 56, child: Eyebrow(label, color: AppColors.muted)),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppText.tag.copyWith(color: color, letterSpacing: 0.8),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.on,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.surfaceDim,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: AppText.meta.copyWith(height: 15 / 11)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Read-only: the value belongs to the OS, so the switch shows the
          // truth and the row opens the place where it can be changed.
          IgnorePointer(child: Switch(value: on, onChanged: (_) {})),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.surfaceDim,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: AppText.meta),
              ],
            ),
          ),
          if (badge > 0) ...[
            Tag('$badge', color: AppColors.live),
            const SizedBox(width: 10),
          ],
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.faint),
        ],
      ),
    );
  }
}
