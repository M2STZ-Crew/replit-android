import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../domain/safety_guide.dart';

/// "Safety guides" — the knowledge-base tab.
///
/// The design opens the first guide for you with its steps already visible.
/// That is the whole idea: nobody taps into a list while their kitchen is
/// alight, so the most urgent guide costs zero taps.
class SafetyGuidesScreen extends StatelessWidget {
  const SafetyGuidesScreen({super.key, this.onProfile});

  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final featured = kSafetyGuides.first;
    final rest = kSafetyGuides.skip(1).toList(growable: false);

    return ListView(
      padding: EdgeInsets.fromLTRB(24, top + 12, 24, 24),
      children: [
        ScreenHeader(
          eyebrow: 'Knowledge base',
          title: 'Safety guides',
          showBack: false,
          trailing: AvatarWell(onTap: onProfile),
        ),
        const SizedBox(height: 16),
        const Text(
          'Short steps to follow while help is on the way.',
          style: AppText.body,
        ),
        const SizedBox(height: 22),

        _FeaturedGuide(guide: featured),

        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Eyebrow('All guides', color: AppColors.accent),
            Eyebrow('${kSafetyGuides.length} lessons'),
          ],
        ),
        const SizedBox(height: 12),
        for (final guide in rest) ...[
          _GuideRow(guide: guide),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _FeaturedGuide extends StatelessWidget {
  const _FeaturedGuide({required this.guide});

  final SafetyGuide guide;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(20),
      border: AppColors.accent.withValues(alpha: 0.35),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.accent.withValues(alpha: 0.13),
          AppColors.live.withValues(alpha: 0.06),
        ],
      ),
      onTap: () => _openGuide(context, guide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconWell(
                tint: AppColors.live,
                asset: Art.agencyBfp,
                size: 40,
                glyph: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow(
                      'Start here · ${guide.readTime} read',
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide.title.toUpperCase(),
                      style: AppText.cardTitle.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Only the first three steps are shown inline. The rest are one tap
          // away — enough to act on immediately without turning the card into
          // a wall of text.
          for (final (i, step) in guide.steps.take(3).indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            _Step(number: i + 1, text: step),
          ],
          if (guide.steps.length > 3) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'READ ALL ${guide.steps.length} STEPS',
                  style: AppText.tag.copyWith(color: AppColors.accent),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 15, color: AppColors.accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 13,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 11,
              height: 16 / 11,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.guide});

  final SafetyGuide guide;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.surfaceDim,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      onTap: () => _openGuide(context, guide),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              guide.index,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.faint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              guide.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(guide.readTime.toUpperCase(), style: AppText.tag.copyWith(
            color: AppColors.faint,
            letterSpacing: 0.8,
          )),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.faint),
        ],
      ),
    );
  }
}

void _openGuide(BuildContext context, SafetyGuide guide) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => GuideDetailScreen(guide: guide)),
  );
}

/// One guide, full length. Kept deliberately plain — large type, generous
/// spacing, no images to load.
class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.guide});

  final SafetyGuide guide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            const ScreenHeader(title: 'Safety guide'),
            const SizedBox(height: 28),
            Eyebrow(
              'Guide ${guide.index} · ${guide.readTime} read',
              color: AppColors.accent,
            ),
            const SizedBox(height: 10),
            Text(guide.title.toUpperCase(), style: AppText.display),
            if (guide.intro != null) ...[
              const SizedBox(height: 12),
              Text(guide.intro!, style: AppText.body),
            ],
            const SizedBox(height: 26),
            Panel(
              padding: const EdgeInsets.all(20),
              color: AppColors.surfaceDim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, step) in guide.steps.indexed) ...[
                    if (i > 0) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              radius: AppRadius.control,
              color: AppColors.surfaceDim,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'General guidance, not medical advice. If someone is in '
                      'danger, send an SOS or call 911 first.',
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
}
