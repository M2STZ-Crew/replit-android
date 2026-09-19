import 'package:flutter/material.dart';

import '../theme.dart';

/// Keeps the app readable on a tablet.
///
/// Every frame in the hand-off is drawn at 402 px — a phone. Stretched across
/// an iPad that layout falls apart in the way phone-first layouts always do:
/// a line of body text runs 900 px wide, a 54px button spans the room, and a
/// card's contents drift to opposite edges.
///
/// So on anything wider than a phone the app keeps its column and centres it,
/// with the ground filling the rest. Nothing in the design moves; it simply
/// stops being stretched. Below the threshold — every phone, and a small
/// tablet in portrait — this is a pass-through and costs nothing.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});

  final Widget child;

  /// The widest the app's column is ever drawn. A little over the design's
  /// 402 px, so a tablet gains some room without the line lengths going long.
  static const double maxWidth = 600;

  /// Below this the frame does nothing: phones, and a 7" tablet in portrait,
  /// which are close enough to the drawn layout to leave alone.
  static const double threshold = maxWidth + 40;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth < threshold) {
          return child;
        }
        return ColoredBox(
          color: context.pal.background,
          child: Center(
            child: SizedBox(width: maxWidth, child: child),
          ),
        );
      },
    );
  }
}
