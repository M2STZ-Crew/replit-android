import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';
import 'motion.dart';

/// The Scroll fade (REPLIT (MAIN) 04 · pass 3): a 40 px gradient at an edge
/// of a scrolling list that says there is more past that edge.
///
/// Figma can only draw it at one scroll position; here it follows the real
/// one. At the top only the bottom fade shows, in the middle both, at the end
/// only the top one, and on content that fits, neither. It is decoration: it
/// takes no touches (so the row under it still answers), is hidden from
/// screen readers, and fades in and out over 150 ms — not at all when the
/// phone asks for reduced motion.
///
/// Wrap the screen's outermost vertical scroll view only — a list nested in a
/// faded page gets no fade of its own (the notifications of nested
/// scrollables are ignored). Never put it on a map. Give the list at least
/// [kScrollFadeEndPadding] of bottom padding so its last row scrolls clear.
class ScrollFade extends StatefulWidget {
  const ScrollFade({super.key, required this.child, this.surface});

  /// The scroll view.
  final Widget child;

  /// What is behind the content — the ground on a screen (the default), the
  /// card surface inside a card, glass strong on a map sheet.
  final Color? surface;

  /// The fade's depth.
  static const double extent = 40;

  @override
  State<ScrollFade> createState() => _ScrollFadeState();
}

/// The least bottom padding a faded list needs so its last item scrolls fully
/// clear of the fade.
const double kScrollFadeEndPadding = ScrollFade.extent;

class _ScrollFadeState extends State<ScrollFade> {
  bool _above = false;
  bool _below = false;

  bool _onMetrics(ScrollMetrics metrics, int depth) {
    // Only the direct scroll view: a nested list scrolling sideways or inside
    // a card must not light the page's fades.
    if (depth != 0 || metrics.axis != Axis.vertical) return false;
    // Half a pixel of slack: a list that fits can report a sliver of extent
    // from rounding, and that is not "more content".
    final above = metrics.extentBefore > 0.5;
    final below = metrics.extentAfter > 0.5;
    if (above == _above && below == _below) return false;
    // A list can report mid-layout (content that shrinks under a fling, a
    // pull-to-refresh settling); rebuilding then is not allowed, so the edge
    // catches up on the next frame instead.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (!_pending) {
        _pending = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _pending = false;
          if (mounted) setState(() {});
        });
      }
      _above = above;
      _below = below;
    } else {
      setState(() {
        _above = above;
        _below = below;
      });
    }
    return false;
  }

  bool _pending = false;

  @override
  Widget build(BuildContext context) {
    final surface = widget.surface ?? context.pal.background;
    final duration = Motion.of(context).fade;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics, n.depth),
        child: Stack(
          children: [
            widget.child,
            _Edge(
              key: const ValueKey('scroll-fade-top'),
              top: true,
              shown: _above,
              surface: surface,
              duration: duration,
            ),
            _Edge(
              key: const ValueKey('scroll-fade-bottom'),
              top: false,
              shown: _below,
              surface: surface,
              duration: duration,
            ),
          ],
        ),
      ),
    );
  }
}

class _Edge extends StatelessWidget {
  const _Edge({
    super.key,
    required this.top,
    required this.shown,
    required this.surface,
    required this.duration,
  });

  final bool top;
  final bool shown;
  final Color surface;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: ScrollFade.extent,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: duration,
            curve: Motion.standard,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // The surface at the edge, 60 % at the midpoint, clear inside.
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: [
                    surface,
                    surface.withValues(alpha: surface.a * 0.6),
                    surface.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
