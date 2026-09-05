import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../domain/hotline.dart';

/// "Call for help" — the directory tab from the hand-off.
///
/// Everything here is local. No session, no network, no loading state: the
/// screen has to work when the rest of the app cannot.
class HotlinesScreen extends StatefulWidget {
  const HotlinesScreen({super.key, this.onProfile});

  final VoidCallback? onProfile;

  @override
  State<HotlinesScreen> createState() => _HotlinesScreenState();
}

class _HotlinesScreenState extends State<HotlinesScreen> {
  HotlineCategory _filter = HotlineCategory.all;

  List<Hotline> get _visible => _filter == HotlineCategory.all
      ? kHotlines
      : kHotlines
          .where((h) => h.category == _filter || h.featured)
          .toList(growable: false);

  Future<void> _dial(Hotline hotline) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: Hotline.dialable(hotline.primary));
    // The dialler is opened with the number filled in, never dialled outright:
    // a mis-tap that places a real emergency call is its own harm.
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the dialler for ${hotline.primary}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, top + 12, 24, 0),
          child: ScreenHeader(
            eyebrow: 'Emergency hotlines',
            title: 'Call for help',
            showBack: false,
            trailing: AvatarWell(onTap: widget.onProfile),
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
              Eyebrow(
                _filter == HotlineCategory.all
                    ? 'All hotlines'
                    : '${_filter.label} lines',
                color: AppColors.accent,
              ),
              Eyebrow('${_visible.length} numbers'),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: _visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _HotlineRow(hotline: _visible[i], onTap: () => _dial(_visible[i])),
          ),
        ),
      ],
    );
  }
}

class _HotlineRow extends StatelessWidget {
  const _HotlineRow({required this.hotline, required this.onTap});

  final Hotline hotline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Color(hotline.tint ?? 0xFFCFCFCF);
    // 911 is given the coral treatment; everything else is a plain glass row,
    // so the one number that always works is the one the eye finds first.
    return Panel(
      radius: AppRadius.card,
      onTap: onTap,
      color: hotline.featured
          ? AppColors.accent.withValues(alpha: 0.09)
          : AppColors.surfaceDim,
      border: hotline.featured
          ? AppColors.accent.withValues(alpha: 0.4)
          : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          IconWell(
            tint: tint,
            asset: hotline.art,
            icon: hotline.art == null ? Icons.call_rounded : null,
          ),
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
                  hotline.blurb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(
                    color: hotline.featured ? AppColors.label : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hotline.primary,
                style: TextStyle(
                  fontSize: hotline.primary.length > 6 ? 14 : 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: hotline.featured ? AppColors.accent : AppColors.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                hotline.secondary ?? 'Tap to dial',
                style: hotline.secondary != null
                    ? AppText.meta.copyWith(fontSize: 10, color: AppColors.faint)
                    : AppText.tag.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
