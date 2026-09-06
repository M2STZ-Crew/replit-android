import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hotline.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'profile_screen.dart';

/// "Call for help" — the HOTLINES tab, in the v2 design.
///
/// Everything here is local. No session, no network, no loading state: the
/// screen has to work when the rest of the app cannot, which is the whole
/// reason it exists.
///
/// The numbers themselves are the team's existing [kHotlines] list, untouched.
/// The design's own directory listed two more (Pasay City General Hospital and
/// a DRRMO mobile) — those are not added here, because a hotline nobody on the
/// team has verified is worse than one fewer entry.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  HotlineCategory _filter = HotlineCategory.all;

  List<Hotline> get _visible => _filter == HotlineCategory.all
      ? kHotlines
      : kHotlines
            .where((h) => h.category == _filter || h.featured)
            .toList(growable: false);

  Future<void> _dial(Hotline hotline) async {
    // The dialler opens pre-filled and the user presses call — a mis-tap that
    // places a real emergency call is its own harm.
    final uri = Uri(scheme: 'tel', path: hotline.dialNumber);
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        _toast('Could not open the dialler for ${hotline.displayNumber}.');
      }
    } catch (_) {
      if (mounted) {
        _toast('Could not open the dialler for ${hotline.displayNumber}.');
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.live),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.hotlines),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: ScreenHeader(
                eyebrow: 'Emergency hotlines',
                title: 'Call for help',
                showBack: false,
                trailing: AvatarWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Tap to dial. These work without data and without signing in.',
                style: AppText.body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 0, 0),
              child: FilterChips(
                options: [for (final c in HotlineCategory.values) c.label],
                selected: _filter.label,
                onSelect: (label) => setState(() {
                  _filter = HotlineCategory.values.firstWhere(
                    (c) => c.label == label,
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Eyebrow(
                      _filter == HotlineCategory.all
                          ? 'All hotlines'
                          : '${_filter.label} lines',
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Eyebrow('${_visible.length} numbers'),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: _visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _HotlineRow(
                  hotline: _visible[i],
                  onTap: () => _dial(_visible[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotlineRow extends StatelessWidget {
  const _HotlineRow({required this.hotline, required this.onTap});

  final Hotline hotline;
  final VoidCallback onTap;

  Color get _tint => switch (hotline.category) {
    HotlineCategory.fire => AppColors.live,
    HotlineCategory.medical => AppColors.ok,
    HotlineCategory.police => AppColors.crime,
    HotlineCategory.pasay => AppColors.accent,
    HotlineCategory.all =>
      hotline.featured ? AppColors.accent : AppColors.textSoft,
  };

  @override
  Widget build(BuildContext context) {
    // 911 gets the coral treatment; everything else is a plain glass row, so
    // the one number that always works is the one the eye finds first.
    final short = hotline.displayNumber.length <= 4;

    return Panel(
      radius: AppRadius.card,
      onTap: onTap,
      color: hotline.featured
          ? AppColors.accent.withValues(alpha: 0.09)
          : AppColors.glassDim,
      border: hotline.featured
          ? AppColors.accent.withValues(alpha: 0.4)
          : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          IconWell(tint: _tint, icon: hotline.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hotline.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  hotline.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(
                    height: 15 / 11,
                    color: hotline.featured
                        ? AppColors.label
                        : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Capped and scaled down rather than allowed to push the row wide:
          // a landline like "(02) 8426-0219" at a 1.5x system font scale is
          // half the width of the phone on its own.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 108),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hotline.displayNumber,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: short ? 17 : 13,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: hotline.featured
                          ? AppColors.accent
                          : AppColors.onBackground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'TAP TO DIAL',
                    maxLines: 1,
                    style: AppText.tag.copyWith(
                      fontSize: 8,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
