import 'package:flutter/material.dart';

import '../models/guide_article.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';
import 'guide_detail_screen.dart';
import 'profile_screen.dart';

/// "Safety guides" — the GUIDES tab, in the v2 design.
///
/// The design's argument for this screen is that the first guide is already
/// open when you arrive: nobody taps into a list while their kitchen is alight.
/// So the top card is the first fire guide with its opening steps visible, and
/// the rest is a numbered list beneath it.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final TextEditingController _search = TextEditingController();

  String _category = kCatFire;
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isSearch => _searching && _query.isNotEmpty;

  List<GuideArticle> get _visible {
    if (_isSearch) {
      final q = _query.toLowerCase();
      return kGuideArticles
          .where(
            (g) =>
                g.title.toLowerCase().contains(q) ||
                g.summary.toLowerCase().contains(q),
          )
          .toList();
    }
    return kGuideArticles.where((g) => g.category == _category).toList();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search.clear();
        _query = '';
      }
    });
  }

  void _open(GuideArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuideDetailScreen(article: article)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    // The featured card is only meaningful when browsing a category — during a
    // search every result is equally relevant, so the list stands alone.
    final featured = _isSearch || items.isEmpty ? null : items.first;
    final rest = featured == null ? items : items.skip(1).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppNavBar(active: AppTab.guides),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: ScreenHeader(
                eyebrow: 'Knowledge base',
                title: 'Safety guides',
                showBack: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconWellButton(
                      icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                      tint: _searching ? AppColors.accent : AppColors.onBackground,
                      onTap: _toggleSearch,
                    ),
                    const SizedBox(width: 8),
                    AvatarWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onBackground,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search guides…',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Short steps to follow while help is on the way.',
                  style: AppText.body,
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: FilterChips(
                  options: const [kCatFire, kCatHealth],
                  selected: _category,
                  onSelect: (c) => setState(() => _category = c),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Nothing matches',
                      body: 'No guide matches that search. Try a shorter word.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        if (featured != null) ...[
                          _FeaturedGuide(
                            article: featured,
                            onTap: () => _open(featured),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Eyebrow(
                                'All guides',
                                color: AppColors.accent,
                              ),
                              Eyebrow('${items.length} lessons'),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (final (i, g) in rest.indexed) ...[
                          _GuideRow(
                            article: g,
                            index: featured == null ? i + 1 : i + 2,
                            onTap: () => _open(g),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedGuide extends StatelessWidget {
  const _FeaturedGuide({required this.article, required this.onTap});

  final GuideArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The opening section's points are the ones worth having on screen already.
    final points = article.sections.isEmpty
        ? const <String>[]
        : article.sections.first.points;

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
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(
                tint: AppColors.live,
                icon: article.icon,
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
                      'Start here · ${article.readMins} min read',
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.title.toUpperCase(),
                      style: AppText.cardTitle.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (i, point) in points.take(3).indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 13,
                  child: Text(
                    '${i + 1}',
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
                    point,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSoft,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'READ THE FULL GUIDE',
                style: AppText.tag.copyWith(color: AppColors.accent),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.article,
    required this.index,
    required this.onTap,
  });

  final GuideArticle article;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.glassDim,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              index.toString().padLeft(2, '0'),
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
              article.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: AppColors.onBackground,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${article.readMins} MIN',
            style: AppText.tag.copyWith(
              color: AppColors.faint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: AppColors.faint,
          ),
        ],
      ),
    );
  }
}
