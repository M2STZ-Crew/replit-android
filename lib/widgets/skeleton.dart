import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

/// Placeholders in the shape of what is loading (the 5 November issue list,
/// 1.6): grey blocks where the rows, cards and titles will be, with a soft
/// highlight sweeping across them, instead of a spinner on an empty screen.
/// The screen keeps its layout while it loads, so nothing jumps when the
/// content arrives, and the wait reads as progress.
///
/// [Skeleton] draws the sweep once over everything under it, so all its blocks
/// shimmer together. Under reduced motion they hold still. A screen reader
/// hears "Loading" once, not every block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child, this.label = 'Loading'});

  final Widget child;
  final String label;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = SkeletonTone.of(context);
    final still = Motion.of(context).reduced;
    return Semantics(
      label: widget.label,
      container: true,
      child: ExcludeSemantics(
        child: still
            ? widget.child
            : AnimatedBuilder(
                animation: _sweep,
                child: widget.child,
                builder: (context, child) => ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [tone.base, tone.highlight, tone.base],
                    stops: const [0.35, 0.5, 0.65],
                    transform: _Slide(_sweep.value),
                  ).createShader(rect),
                  child: child,
                ),
              ),
      ),
    );
  }
}

/// The sweep's position: from off the left edge to off the right.
class _Slide extends GradientTransform {
  const _Slide(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// The block colour and the sweep's, on either ground.
class SkeletonTone {
  const SkeletonTone(this.base, this.highlight);

  final Color base;
  final Color highlight;

  static SkeletonTone of(BuildContext context) {
    final pal = context.pal;
    return pal.isLight
        ? const SkeletonTone(Color(0xFFE1DFDB), Color(0xFFF2F1EE))
        : const SkeletonTone(Color(0xFF262626), Color(0xFF363636));
  }
}

/// One block: a line of text, an icon plate, a photo.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: SkeletonTone.of(context).base,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// A list row while it loads: the 40 px plate, a title and a subtitle, as
/// ListRow lays them out.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.leading = true, this.trailing = false});

  final bool leading;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.pal.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.pal.line),
      ),
      child: Row(
        children: [
          if (leading) ...[
            const SkeletonBox(width: 40, height: 40, radius: 10),
            const SizedBox(width: 14),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.62,
                  child: SkeletonBox(height: 13),
                ),
                SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: 0.88,
                  child: SkeletonBox(height: 10),
                ),
              ],
            ),
          ),
          if (trailing) ...[
            const SizedBox(width: 14),
            const SkeletonBox(width: 44, height: 22, radius: 11),
          ],
        ],
      ),
    );
  }
}

/// A list while it loads: [rows] rows under an optional section title.
///
/// Scrolls like the list it stands in for, so pull-to-refresh above it keeps
/// working. [padding] matches the list's own.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 6,
    this.leading = true,
    this.trailing = false,
    this.header = false,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 24),
    this.shrinkWrap = false,
  });

  final int rows;
  final bool leading;
  final bool trailing;
  final bool header;
  final EdgeInsets padding;

  /// For a list inside another scroll view.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        key: const ValueKey('skeleton-list'),
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        children: _rows(
          rows: rows,
          leading: leading,
          trailing: trailing,
          header: header,
        ),
      ),
    );
  }
}

List<Widget> _rows({
  required int rows,
  required bool leading,
  required bool trailing,
  required bool header,
}) => [
  if (header) ...[
    const FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: 0.4,
      child: SkeletonBox(height: 11),
    ),
    const SizedBox(height: 14),
  ],
  for (var i = 0; i < rows; i++) ...[
    if (i > 0) const SizedBox(height: 8),
    SkeletonRow(leading: leading, trailing: trailing),
  ],
];

/// Rows while they load, inside a list or a column that is already there
/// (a section of a screen that has the rest of its content).
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({
    super.key,
    this.rows = 3,
    this.leading = true,
    this.trailing = false,
    this.header = false,
  });

  final int rows;
  final bool leading;
  final bool trailing;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        key: const ValueKey('skeleton-rows'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _rows(
          rows: rows,
          leading: leading,
          trailing: trailing,
          header: header,
        ),
      ),
    );
  }
}

/// A detail screen while it loads: a title, a line under it, a strip of
/// three figures, a panel of prose, and rows. [scrollable] when it stands in
/// for a whole screen body; otherwise a column for a list already there.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.rows = 3,
    this.media = false,
    this.scrollable = true,
  });

  final EdgeInsets padding;
  final int rows;

  /// A map or photo block at the top.
  final bool media;

  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      if (media) ...[
        const SkeletonBox(height: 180, radius: AppRadius.panel),
        const SizedBox(height: 20),
      ],
      const FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.55,
        child: SkeletonBox(height: 22, radius: 8),
      ),
      const SizedBox(height: 10),
      const FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.8,
        child: SkeletonBox(height: 12),
      ),
      const SizedBox(height: 22),
      const Row(
        children: [
          Expanded(child: SkeletonBox(height: 64, radius: AppRadius.card)),
          SizedBox(width: 8),
          Expanded(child: SkeletonBox(height: 64, radius: AppRadius.card)),
          SizedBox(width: 8),
          Expanded(child: SkeletonBox(height: 64, radius: AppRadius.card)),
        ],
      ),
      const SizedBox(height: 20),
      const SkeletonBox(height: 96, radius: AppRadius.panel),
      for (var i = 0; i < rows; i++) ...[
        const SizedBox(height: 8),
        const SkeletonRow(),
      ],
    ];
    return Skeleton(
      child: scrollable
          ? ListView(
              key: const ValueKey('skeleton-detail'),
              padding: padding,
              children: parts,
            )
          : Padding(
              key: const ValueKey('skeleton-detail'),
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: parts,
              ),
            ),
    );
  }
}

/// A block filling its space while it loads: a map, a photo, a viewfinder.
class SkeletonFill extends StatelessWidget {
  const SkeletonFill({super.key, this.radius = 0, this.label = 'Loading'});

  final double radius;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      label: label,
      child: SizedBox.expand(
        key: const ValueKey('skeleton-fill'),
        child: SkeletonBox(radius: radius, height: double.infinity),
      ),
    );
  }
}
