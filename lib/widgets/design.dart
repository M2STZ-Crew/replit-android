import 'package:flutter/material.dart';

import '../theme.dart';

/// The handful of shapes the "General User App v2" hand-off repeats on every
/// screen. Building them once is what keeps forty-odd screens looking like one
/// app — and it is the only way the screens the design does *not* cover (the
/// Sub-Admin console, BFP, the responder flow) can be aligned to it without
/// guessing.

/// Design asset paths, so a rename is a one-line change rather than a hunt.
class Art {
  Art._();

  static const String _d = 'assets/design';
  static const String mark = '$_d/mark.png';

  /// The v2 lock-up: wordmark with the signal bars and pin, on a square
  /// canvas. Still used by [AppLogo].
  static const String wordmark = '$_d/wordmark.png';

  /// The overhaul's plain "REPLIT" type, tightly cropped (353×63 at 3x).
  static const String wordmarkType = '$_d/wordmark-type.png';
  static const String avatar = '$_d/avatar.png';

  // White agency glyphs from the REPLIT-OVERHAUL report frame, drawn on the
  // agency's own tinted well.
  static const String agFire = '$_d/ag-fire.png';
  static const String agMedical = '$_d/ag-medical.png';
  static const String agPolice = '$_d/ag-police.png';
  static const String agBarangay = '$_d/ag-barangay.png';

  static const String agency911 = '$_d/agency-911.png';
  static const String agencyBfp = '$_d/agency-bfp.png';
  static const String agencyPnp = '$_d/agency-pnp.png';
  static const String agencyMmda = '$_d/agency-mmda.png';

  static const String evac = '$_d/mk-evac.png';
  static const String hospital = '$_d/mk-hospital.png';
  static const String hydrant = '$_d/mk-hydrant.png';
  static const String incident = '$_d/mk-incident.png';
  static const String truck = '$_d/mk-truck.png';

  // Tab icons, exported at 3x from the REPLIT-OVERHAUL NavBar component. One
  // glyph per tab, tinted at runtime for the on/off state.
  static const String navMap = '$_d/nav-map.png';
  static const String navHotlines = '$_d/nav-hotlines.png';
  static const String navGuides = '$_d/nav-guides.png';
  static const String navProfile = '$_d/nav-profile.png';
}

/// The 10px uppercase section label used above every group in the design.
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

/// An eyebrow over a text field. The eyebrow turns coral while its field has
/// focus — how the overhaul's forms show where you are typing.
class LabeledField extends StatefulWidget {
  const LabeledField({super.key, required this.label, required this.builder});

  final String label;

  /// Builds the field; pass the [FocusNode] to it.
  final Widget Function(FocusNode focus) builder;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Eyebrow(
        widget.label,
        color: _focus.hasFocus ? AppColors.accent : AppColors.muted,
      ),
      const SizedBox(height: 9),
      widget.builder(_focus),
    ],
  );
}

/// A translucent card with a hairline edge — the design's only container.
///
/// The edge is drawn as a border rather than the CSS `inset box-shadow`,
/// because Flutter has no inset shadow; at 1px the two are indistinguishable
/// and a real border insets the child correctly.
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

  /// Tint the edge to make a card read as live (coral/red) or settled (green).
  /// The design tints the hairline, never the whole card.
  final Color? border;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.glass) : null,
        gradient: gradient,
        borderRadius: shape,
        border: Border.all(color: border ?? AppColors.line),
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

/// Small pill for status, agency and count labels.
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

  /// Leading dot. The design uses it wherever the state is live.
  final bool dot;

  /// Solid fill instead of a tint — used for the one selected filter.
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
                color: solid ? AppColors.accentText : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            text.toUpperCase(),
            style: AppText.tag.copyWith(
              color: solid ? AppColors.accentText : color,
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
          : Icon(icon ?? Icons.circle_outlined, size: glyph, color: tint),
    );
  }
}

enum _Tone { primary, secondary, danger }

/// Primary (coral gradient), secondary (glass) and destructive buttons.
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
    final Color fg;
    final Color? bg;
    final Gradient? gradient;
    final Color? border;

    switch (_tone) {
      case _Tone.primary:
        fg = AppColors.accentText;
        bg = null;
        gradient = enabled ? AppColors.accentGradient : null;
        border = enabled ? null : AppColors.line;
      case _Tone.secondary:
        fg = AppColors.textSoft;
        bg = AppColors.glass;
        gradient = null;
        border = AppColors.line;
      case _Tone.danger:
        fg = AppColors.live;
        bg = AppColors.live.withValues(alpha: 0.1);
        gradient = null;
        border = AppColors.live.withValues(alpha: 0.35);
    }

    // The overhaul draws every button at the control radius and flat: glow is
    // reserved for the splash mark and the SOS disc (§2.7), so the v2 coral
    // drop shadow is gone.
    final shape = BorderRadius.circular(AppRadius.control);
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
              color: gradient == null ? (bg ?? AppColors.glass) : null,
              gradient: gradient,
              borderRadius: shape,
              border: border == null ? null : Border.all(color: border),
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
                      Flexible(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.action.copyWith(
                            color: fg,
                            fontWeight: _tone == _Tone.primary
                                ? FontWeight.w900
                                : FontWeight.w700,
                            fontSize: _tone == _Tone.primary ? 12 : 11,
                            letterSpacing: _tone == _Tone.primary ? 1.2 : 1.1,
                          ),
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

/// Back chevron in its own glass well — the design's only back affordance.
/// 48px square at the control radius with a hairline edge ("Back" in every
/// REPLIT-OVERHAUL frame that has one).
class BackWell extends StatelessWidget {
  const BackWell({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.control);
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Material(
        color: AppColors.glass,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(color: AppColors.line),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: AppColors.onBackground,
            ),
          ),
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
      children: [
        if (showBack) ...[const BackWell(), const SizedBox(width: 16)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Eyebrow(eyebrow!, color: AppColors.label),
                const SizedBox(height: 6),
              ],
              Text(
                title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

/// Avatar well in the header. Tapping it opens the profile — the design keeps
/// profile off the tab bar deliberately.
class AvatarWell extends StatelessWidget {
  const AvatarWell({super.key, this.onTap, this.initials});

  final VoidCallback? onTap;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.card);
    return Material(
      color: AppColors.glass,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: shape,
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
                    color: AppColors.onBackground,
                  ),
                )
              : Image.asset(Art.avatar, width: 28, height: 28),
        ),
      ),
    );
  }
}

/// A square glass well holding one icon — the header's secondary actions.
class IconWellButton extends StatelessWidget {
  const IconWellButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tint,
    this.size = 44,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;
  final double size;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.card);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.glass,
          borderRadius: shape,
          child: InkWell(
            borderRadius: shape,
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(
                icon,
                size: size * 0.43,
                color: tint ?? AppColors.onBackground,
              ),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.live,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.background, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                badge > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onBackground,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Empty / error state. Plain language, no illustration — the design never
/// shows a mascot.
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
      color: AppColors.glassDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.numeral.copyWith(
              color: color ?? AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 7),
          Eyebrow(label, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// A horizontal filter-chip row.
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
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                  color: on
                      ? AppColors.accent.withValues(alpha: 0.45)
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
      opacity: Tween<double>(
        begin: 1,
        end: 0.25,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.8),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrolling page whose [footer] sits at the foot of the screen when the
/// content is short, and simply follows the content when it is not — the sign
/// in and sign up frames both pin their last line to the bottom.
///
/// Built from a min-height Column rather than SliverFillRemaining: that one
/// sizes itself from intrinsic heights, which text fields under-report at
/// large font scales, and the page overflowed at 1.5x.
class FootedScroll extends StatelessWidget {
  const FootedScroll({
    super.key,
    required this.content,
    required this.footer,
    this.padding = EdgeInsets.zero,
    this.gap = 32,
  });

  final List<Widget> content;
  final Widget footer;
  final EdgeInsets padding;

  /// The least space kept between the content and the footer.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: content,
              ),
              Padding(
                padding: EdgeInsets.only(top: gap),
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard page padding: 24px sides, matching the 402px design frame.
const EdgeInsets kPagePadding = EdgeInsets.symmetric(horizontal: 24);
