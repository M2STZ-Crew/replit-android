import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/guide_article.dart';
import '../models/hotline.dart';
import '../theme.dart';
import '../widgets/design.dart';

/// "14 Guide detail" from the REPLIT-OVERHAUL Figma: one guide, as numbered
/// steps, with the right hotline one tap away at the foot.
///
/// Deliberately plain — large type, generous spacing, nothing to load. Someone
/// reading this is following steps one-handed while help is on the way.
///
/// The frame flattens a guide into steps; these guides have sections, so the
/// section names stay as small labels over their steps and the numbering runs
/// on across them. The call button uses the team's verified BFP line for fire
/// guides and 911 otherwise — not the frame's "BFP · 160".
class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.article});

  final GuideArticle article;

  Hotline get _hotline {
    final fire = article.category == kCatFire;
    return kHotlines.firstWhere(
      (h) => fire ? h.category == HotlineCategory.fire : h.featured,
      orElse: () => kHotlines.firstWhere((h) => h.featured),
    );
  }

  String get _kicker =>
      '${article.category == kCatFire ? 'Fire' : 'Health'} · ${article.readMins} min';

  Future<void> _call(BuildContext context) async {
    final h = _hotline;
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: h.dialNumber));
      if (!ok && context.mounted) _cannotDial(context, h);
    } catch (_) {
      if (context.mounted) _cannotDial(context, h);
    }
  }

  void _cannotDial(BuildContext context, Hotline h) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open the dialler for ${h.displayNumber}.'),
        backgroundColor: AppColors.live,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotline = _hotline;
    var n = 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          content: [
            Row(
              children: [
                const BackWell(),
                const SizedBox(width: 16),
                Expanded(child: Eyebrow(_kicker, color: AppColors.accent)),
              ],
            ),
            const SizedBox(height: 24),
            Text(article.title.toUpperCase(), style: AppText.heading1),
            const SizedBox(height: 10),
            Text(article.intro, style: AppText.body),
            const SizedBox(height: 20),
            for (final (i, section) in article.sections.indexed) ...[
              if (i > 0) const SizedBox(height: 18),
              Eyebrow(section.heading, color: AppColors.muted),
              const SizedBox(height: 10),
              for (final (j, point) in section.points.indexed) ...[
                if (j > 0) const SizedBox(height: 10),
                _Step(number: ++n, text: point),
              ],
            ],
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'General guidance, not medical advice. If someone is in '
                    'danger, send an SOS or call 911 first.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ],
          footer: _CallButton(
            label: hotline.featured
                ? 'Call ${hotline.displayNumber}'
                : 'Call BFP · ${hotline.displayNumber}',
            onTap: () => _call(context),
          ),
        ),
      ),
    );
  }
}

/// One numbered step card.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: AppText.action.copyWith(
                color: AppColors.accent,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: AppText.bodySm.copyWith(color: AppColors.textSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Call BFP · …" — the coral-tinted hotline button at the foot of a guide.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.card);
    return Material(
      color: AppColors.accent.withValues(alpha: 0.16),
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.call_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppText.action.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
