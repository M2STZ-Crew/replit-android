import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hotline.dart';
import '../theme.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/design.dart';

/// "12 Hotlines" from the REPLIT-OVERHAUL Figma — "Call for help".
///
/// Everything here is local. No session, no network, no loading state: the
/// screen has to work when the rest of the app cannot, which is the whole
/// reason it exists.
///
/// The numbers themselves are the team's verified [kHotlines] list; see there
/// for why the frame's extra numbers are not added.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, this.guest = false});

  /// Opened with no account behind it: from sign-in, or when the account
  /// would not load. A plain screen with Back, and nothing that leads from
  /// here to the parts of the app that need one.
  final bool guest;

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
      SnackBar(content: Text(message), backgroundColor: context.pal.live),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      bottomNavigationBar: widget.guest
          ? null
          : const AppNavBar(active: AppTab.hotlines),
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
                showBack: widget.guest,
                trailing: widget.guest
                    ? null
                    : AvatarWell(
                        onTap: () =>
                            AppNavBar.switchTo(context, AppTab.profile),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Tap to dial. These work without data and without signing in.',
                style: context.type.body,
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
                      color: context.pal.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Eyebrow('${_visible.length} numbers'),
                ],
              ),
            ),
            Expanded(
              // The list fades at whichever edge has more past it (04 ·
              // Scroll fade), instead of a gradient that never moves.
              child: ScrollFade(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                  itemCount: _visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _HotlineRow(
                    hotline: _visible[i],
                    onTap: () => _dial(_visible[i]),
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

class _HotlineRow extends StatelessWidget {
  const _HotlineRow({required this.hotline, required this.onTap});

  final Hotline hotline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 911 gets the coral treatment; everything else is a plain glass row, so
    // the one number that always works is the one the eye finds first.
    final short = hotline.displayNumber.length <= 5;
    final neutral = hotline.isNeutral;
    final tint = hotline.tint(context.pal);

    return Semantics(
      button: true,
      label: '${hotline.name}, ${hotline.displayNumber}. Tap to dial.',
      excludeSemantics: true,
      child: Panel(
        radius: AppRadius.card,
        onTap: onTap,
        color: hotline.featured
            ? context.pal.accent.withValues(alpha: 0.10)
            : context.pal.glass,
        border: hotline.featured
            ? context.pal.accent.withValues(alpha: 0.45)
            : context.pal.line,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                // DAWI "11 HOTLINES": each agency on its deep 900 well, a
                // white glyph; the quiet desks keep the faint wash.
                color: neutral
                    ? tint.withValues(alpha: 0.10)
                    : context.pal.wellFor(tint),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              alignment: Alignment.center,
              // One filled glyph family for every row (03 · pass 3); the
              // agency's tone still carries on the well.
              child: Icon(
                hotline.icon,
                size: 20,
                color: neutral ? tint : context.pal.glyphOn(tint),
              ),
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
                    style: context.type.cardTitleSm,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hotline.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      color: context.pal.label,
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
              constraints: const BoxConstraints(maxWidth: 116),
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
                      style:
                          (short
                                  ? context.type.numeralSm
                                  : context.type.cardTitle)
                              .copyWith(
                                color: hotline.featured
                                    ? context.pal.accent
                                    : context.pal.onBackground,
                              ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hotline.featured ? 'Toll-free nationwide' : 'Tap to dial',
                      maxLines: 1,
                      style: context.type.captionSm,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
