import 'package:flutter/material.dart';

import '../models/guide_article.dart';
import '../theme.dart';
import '../widgets/design.dart';

/// Full-article reader for one [GuideArticle]. Pure static content.
///
/// Deliberately plain — large type, generous spacing, nothing to load. Someone
/// reading this is following steps one-handed while help is on the way.
class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.article});

  final GuideArticle article;

  Color get _accent =>
      article.category == kCatHealth ? AppColors.ok : AppColors.accent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            const ScreenHeader(title: 'Safety guide'),
            const SizedBox(height: 28),
            IconWell(
              tint: _accent,
              icon: article.icon,
              size: 60,
              glyph: 28,
            ),
            const SizedBox(height: 18),
            Eyebrow(
              '${article.category} · ${article.readMins} min read',
              color: _accent,
            ),
            const SizedBox(height: 10),
            Text(
              article.title.toUpperCase(),
              style: AppText.display.copyWith(fontSize: 28, height: 32 / 28),
            ),
            const SizedBox(height: 12),
            Text(article.intro, style: AppText.body),
            const SizedBox(height: 26),
            for (final (i, section) in article.sections.indexed) ...[
              if (i > 0) const SizedBox(height: 14),
              _section(section, i + 1),
            ],
            const SizedBox(height: 22),
            Panel(
              radius: AppRadius.control,
              color: AppColors.glassDim,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
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

  Widget _section(GuideSection section, int number) {
    return Panel(
      padding: const EdgeInsets.all(20),
      color: AppColors.glassDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _accent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  section.heading.toUpperCase(),
                  style: AppText.cardTitle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (i, point) in section.points.indexed) ...[
            if (i > 0) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    point,
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
    );
  }
}
