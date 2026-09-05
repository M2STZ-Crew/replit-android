import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The handful of shapes the "General User App v2" hand-off repeats on every
/// screen. Building them once is what keeps eleven screens looking like one
/// app — and it is the only way the pieces the design does *not* cover
/// (verification, the responder view, notifications) can be aligned to it
/// without guessing.

/// Asset paths, so a rename is a one-line change rather than a hunt.
abstract final class Art {
  static const _d = 'assets/design';
  static const mark = '$_d/mark.png';
  static const wordmark = '$_d/wordmark.png';
  static const avatar = '$_d/avatar.png';

  static const agency911 = '$_d/agency-911.png';
  static const agencyBfp = '$_d/agency-bfp.png';
  static const agencyPnp = '$_d/agency-pnp.png';
  static const agencyMmda = '$_d/agency-mmda.png';

  static const evac = '$_d/mk-evac.png';
  static const hospital = '$_d/mk-hospital.png';
  static const hydrant = '$_d/mk-hydrant.png';
  static const incident = '$_d/mk-incident.png';
  static const truck = '$_d/mk-truck.png';

  // Tab icons come in on/off pairs; the mapping is from NavBar.dc.html.
  static const navMapOn = '$_d/nav-a.png';
  static const navMapOff = '$_d/nav-f.png';
  static const navSosOn = '$_d/nav-g.png';
  static const navSosOff = '$_d/nav-b.png';
  static const navCallOn = '$_d/nav-e.png';
  static const navCallOff = '$_d/nav-h.png';
  static const navGuideOn = '$_d/nav-d.png';
  static const navGuideOff = '$_d/nav-c.png';
}

/// The 10px uppercase section label. Used above every group in the design.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppText.eyebrow.copyWith(color: color ?? AppColors.faint),
  );
}

/// A translucent card with an inset hairline — the design's only container.
///
/// The hairline is drawn as a border rather than the CSS `inset box-shadow`
/// because Flutter has no inset shadow; at 1px the two are indistinguishable,
/// and a real border keeps the child inset correctly.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.panel,
    this.color,
    this.border,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;

  /// Pass a tinted colour to make a card read as live (coral/red) or settled
  /// (green) — the design tints the hairline, never the whole card.
  final Color? border;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: shape,
        border: Border.all(color: border ?? AppColors.line, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: InkWell(borderRadius: shape, onTap: onTap, child: content),
    );
  }
}

/// Small pill used for status, agency and count labels.
class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    required this.color,
    this.dot = false,
    this.solid = false,
  });

  final String text;
  final Color color;

  /// Draw a leading dot. The design uses it wherever the state is live.
  final bool dot;

  /// Solid coral fill instead of a tint — used for the one selected filter.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: solid ? 1 : 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: solid ? AppColors.onAccent : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            text.toUpperCase(),
            style: AppText.tag.copyWith(
              color: solid ? AppColors.onAccent : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-square icon well. Every list row in the design leads with one.
class IconWell extends StatelessWidget {
  const IconWell({
    super.key,
    required this.tint,
    this.asset,
    this.icon,
    this.size = 42,
    this.glyph = 21,
  });

  final Color tint;
  final String? asset;
  final IconData? icon;
  final double size;
  final double glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: asset != null
          ? Image.asset(asset!, width: glyph, height: glyph)
          : Icon(icon, size: glyph, color: tint),
    );
  }
}

/// Primary (coral gradient) and secondary (glass) buttons.
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.height = 52,
    this.busy = false,
  }) : _tone = _Tone.primary;

  const AppButton.secondary(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.height = 52,
    this.busy = false,
  }) : _tone = _Tone.secondary;

  /// Destructive — the design uses a red-tinted glass panel, never a red fill.
  const AppButton.danger(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.height = 48,
    this.busy = false,
  }) : _tone = _Tone.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool busy;
  final _Tone _tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final (fg, bg, gradient, border) = switch (_tone) {
      _Tone.primary => (
        AppColors.onAccent,
        null,
        enabled ? AppColors.accentGradient : null,
        enabled ? null : AppColors.line,
      ),
      _Tone.secondary => (
        AppColors.textSoft,
        AppColors.surface,
        null,
        AppColors.line,
      ),
      _Tone.danger => (
        AppColors.live,
        AppColors.live.withValues(alpha: 0.1),
        null,
        AppColors.live.withValues(alpha: 0.35),
      ),
    };

    final shape = BorderRadius.circular(AppRadius.card);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: enabled ? onPressed : null,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: gradient == null
                  ? (bg ?? AppColors.surface)
                  : null,
              gradient: gradient,
              borderRadius: shape,
              border: border == null ? null : Border.all(color: border),
              boxShadow: _tone == _Tone.primary && enabled
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: fg),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label.toUpperCase(),
                        style: AppText.action.copyWith(
                          color: fg,
                          fontWeight: _tone == _Tone.primary
                              ? FontWeight.w900
                              : FontWeight.w700,
                          fontSize: _tone == _Tone.primary ? 12 : 11,
                          letterSpacing: _tone == _Tone.primary ? 1.2 : 1.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

enum _Tone { primary, secondary, danger }

/// Back chevron in its own glass well — the design's only back affordance.
class BackWell extends StatelessWidget {
  const BackWell({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.lineLight),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left_rounded,
              size: 22, color: AppColors.text),
        ),
      ),
    );
  }
}

/// Screen header: back chevron (optional), eyebrow + title, trailing slot.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.showBack = true,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack) ...[const BackWell(), const SizedBox(width: 16)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (eyebrow != null) ...[
                Eyebrow(eyebrow!, color: AppColors.label),
                const SizedBox(height: 6),
              ],
              Text(
                title.toUpperCase(),
                style: eyebrow == null ? AppText.screenTitle : AppText.title,
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Circular avatar well in the header. Tapping it opens the profile — the
/// design deliberately keeps profile off the tab bar.
class AvatarWell extends StatelessWidget {
  const AvatarWell({super.key, this.onTap, this.initials});

  final VoidCallback? onTap;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.lineLight),
          ),
          alignment: Alignment.center,
          child: initials != null && initials!.isNotEmpty
              ? Text(
                  initials!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: AppColors.text,
                  ),
                )
              : Image.asset(Art.avatar, width: 28, height: 28),
        ),
      ),
    );
  }
}

/// Empty / error state used wherever a list has nothing in it. Plain language,
/// no illustration — the design never shows a mascot.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.inbox_outlined,
    this.tone,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color? tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.faint;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconWell(tint: color, icon: icon, size: 52, glyph: 24),
            const SizedBox(height: 18),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppText.cardTitle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(body, textAlign: TextAlign.center, style: AppText.body),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// The grab handle at the top of every bottom sheet in the design.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: AppColors.label.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// A stat tile — the trio at the top of the incident-history screen.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      radius: AppRadius.card,
      color: AppColors.surfaceDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppText.numeral.copyWith(color: color ?? AppColors.text),
          ),
          const SizedBox(height: 7),
          Eyebrow(label, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// A horizontal filter chip row — hotlines and the map layer picker.
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final on = option == selected;
          return GestureDetector(
            onTap: () => onSelect(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: on
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                  color: on
                      ? AppColors.accent.withValues(alpha: 0.55)
                      : AppColors.line,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                option.toUpperCase(),
                style: AppText.tag.copyWith(
                  letterSpacing: 1,
                  color: on ? AppColors.accent : AppColors.label,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A dot that pulses, for anything the design marks "live".
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = AppColors.live, this.size = 8});

  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: widget.color.withValues(alpha: 0.8), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Standard page padding: 24px sides, matching the 402px design frame.
const kPagePadding = EdgeInsets.symmetric(horizontal: 24);
