import 'package:flutter/material.dart';

import '../models/guide_article.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'guide_detail_screen.dart';

/// "13 Guides" from the REPLIT-OVERHAUL Figma — "Safety guides".
///
/// The design's argument for this screen is that the guide you need is
/// already open when you arrive: nobody browses a list while their kitchen is
/// alight. So the top card is the "Start here" guide — the one for while it
/// is happening — with its first steps on screen, and every other guide is a
/// plain list beneath it. The overhaul drops v2's search and category chips;
/// with this many guides one list is quicker than either.
///
/// The frame's list names guides this knowledge base does not have (CPR,
/// choking, earthquake…). They are not written here from a mock-up: safety
/// and first-aid steps need someone to vouch for them first.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  void _open(BuildContext context, GuideArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuideDetailScreen(article: article)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = kGuideArticles.firstWhere(
      (g) => g.startHere,
      orElse: () => kGuideArticles.first,
    );
    final rest = kGuideArticles.where((g) => g != featured).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.guides),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
              children: [
                ScreenHeader(
                  eyebrow: 'Knowledge base',
                  title: 'Safety guides',
                  showBack: false,
                  trailing: AvatarWell(
                    onTap: () => AppNavBar.switchTo(context, AppTab.profile),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Short steps to follow while help is on the way.',
                  style: AppText.body,
                ),
                const SizedBox(height: 32),
                _FeaturedGuide(
                  article: featured,
                  onTap: () => _open(context, featured),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Expanded(
                      child: Eyebrow('All guides', color: AppColors.accent),
                    ),
                    Eyebrow(
                      '${kGuideArticles.length} lessons',
                      color: AppColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final g in rest) ...[
                  _GuideRow(article: g, onTap: () => _open(context, g)),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            // The list fades into the tab bar rather than stopping at a hard
            // edge.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 54,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00131313), Color(0xF2131313)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Start here · 2 min read": the guide open before it is opened.
class _FeaturedGuide extends StatelessWidget {
  const _FeaturedGuide({required this.article, required this.onTap});

  final GuideArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fire = article.category == kCatFire;
    final steps = article.firstSteps;
    return Semantics(
      button: true,
      label: 'Start here: ${article.title}. Open the full guide.',
      child: Panel(
        padding: const EdgeInsets.all(20),
        border: AppColors.accent.withValues(alpha: 0.45),
        gradient: LinearGradient(
          begin: const Alignment(-0.27, -1),
          end: const Alignment(0.27, 1),
          stops: const [0.12, 0.87],
          colors: [
            AppColors.accent.withValues(alpha: 0.13),
            AppColors.live.withValues(alpha: 0.06),
          ],
        ),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.live.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  alignment: Alignment.center,
                  child: fire
                      ? Image.asset(Art.incident, width: 20, height: 20)
                      : Icon(article.icon, size: 20, color: AppColors.live),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'START HERE · ${article.readMins} MIN READ',
                        style: AppText.tag.copyWith(color: AppColors.accent),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        article.title.toUpperCase(),
                        style: AppText.headline,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final (i, step) in steps.indexed) ...[
              if (i > 0) const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 13,
                    child: Text(
                      '${i + 1}',
                      style: AppText.labelSm.copyWith(color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      step,
                      style: AppText.detail.copyWith(color: AppColors.textSoft),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.article, required this.onTap});

  final GuideArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${article.title}, ${article.readMins} minute read',
      excludeSemantics: true,
      child: Panel(
        radius: AppRadius.control,
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                article.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowValue.copyWith(color: AppColors.onBackground),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '${article.readMins} MIN',
              style: AppText.tag.copyWith(color: AppColors.muted),
            ),
            const SizedBox(width: 14),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
