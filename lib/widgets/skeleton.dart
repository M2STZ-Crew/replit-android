import 'package:flutter/material.dart';

import '../theme.dart';

/// Grey shapes where something is coming, with a light passing over them.
///
/// 13 November 2026: "create a skeleton loading on that map screen in
/// citizen" (answered: on the map; every other screen keeps the splash's
/// loader, LoadingView). The map's location card and its "Active areas near
/// you" rows show their shape while the fix and the areas come in, so the map
/// never stands empty or names a place that is not yet known.
///
/// With reduced motion the light holds still. A screen reader hears the
/// [label] once, never the shapes.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child, this.label});

  /// The placeholder shapes ([SkeletonBar]s).
  final Widget child;

  /// What is loading, for a screen reader.
  final String? label;

  /// One pass of the light.
  static const Duration period = Duration(milliseconds: 1400);

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: SkeletonShimmer.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _light
        ..stop()
        ..value = 0.5;
    } else if (!_light.isAnimating) {
      _light.repeat();
    }
  }

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final shapes = ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _light,
        child: widget.child,
        builder: (context, child) {
          // A band of light crossing from the left edge to the right.
          final at = _light.value * 3 - 1;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [pal.pressed, pal.lineStrong, pal.pressed],
              stops: [
                (at - 0.35).clamp(0.0, 1.0),
                at.clamp(0.0, 1.0),
                (at + 0.35).clamp(0.0, 1.0),
              ],
            ).createShader(bounds),
            child: child,
          );
        },
      ),
    );
    final label = widget.label;
    return label == null
        ? shapes
        : Semantics(label: label, liveRegion: true, child: shapes);
  }
}

/// One placeholder shape inside a [SkeletonShimmer]: a rounded bar.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({
    super.key,
    required this.width,
    this.height = 10,
    this.radius = 5,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.pal.pressed,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
