import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../theme.dart';
import 'design.dart';

/// The app's one way of showing that something is loading (12 November 2026:
/// "remove the skeleton loading totally, just make it look our default loading
/// screen in the splash as the default loading for every loading").
///
/// The splash's loader: a 34 px coral segment running along a 106 px track,
/// with what is loading said under it. A whole screen also shows the
/// flame-and-pin mark above it, as the splash does ([LoadingView]); a part of
/// a screen shows the loader alone ([LoadingInline]). Under reduced motion the
/// segment holds still in the middle of its track. A screen reader hears the
/// label once.
class LoaderBar extends StatefulWidget {
  const LoaderBar({super.key});

  /// The track's length and the segment's, from the splash.
  static const double track = 106;
  static const double fill = 34;

  @override
  State<LoaderBar> createState() => _LoaderBarState();
}

class _LoaderBarState extends State<LoaderBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _run.stop();
      _run.value = 0.5;
    } else if (!_run.isAnimating) {
      _run.repeat();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const track = LoaderBar.track;
    const fill = LoaderBar.fill;
    final pal = context.pal;
    return ClipRRect(
      key: const ValueKey('loader-bar'),
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: track,
        height: 3,
        color: pal.lineStrong,
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, _) => Stack(
            children: [
              Positioned(
                left: -fill + (track + fill) * _run.value,
                top: 0,
                bottom: 0,
                width: fill,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pal.accent,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The loader and its label, centred: the foot of the splash.
class _LoaderWithLabel extends StatelessWidget {
  const _LoaderWithLabel({required this.label, this.mark = false});

  final String? label;
  final bool mark;

  @override
  Widget build(BuildContext context) {
    final words = label ?? t('Loading');
    return Semantics(
      label: words,
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mark) ...[
              Image.asset(
                Art.logoMark,
                width: 46,
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
            ],
            const LoaderBar(),
            const SizedBox(height: 18),
            Text(
              words,
              textAlign: TextAlign.center,
              style: context.type.detail.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A whole screen, or a whole tab, while it loads: the mark, the loader and
/// what is loading, in the middle of the space, as on the splash.
///
/// [scrollable] keeps it inside a scroll view that fills the space, so a
/// pull-to-refresh around it still works; off, it simply centres itself (a
/// map's place, a camera's viewfinder). [mark] off leaves the loader alone,
/// for a space smaller than a screen.
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.label,
    this.mark = true,
    this.scrollable = true,
  });

  /// What is loading; "Loading" when null.
  final String? label;
  final bool mark;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: _LoaderWithLabel(label: label, mark: mark),
      ),
    );
    if (!scrollable) {
      return SizedBox.expand(key: const ValueKey('loading-view'), child: body);
    }
    return LayoutBuilder(
      builder: (context, box) => ListView(
        key: const ValueKey('loading-view'),
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: box.maxHeight.isFinite ? box.maxHeight : 320,
            ),
            child: body,
          ),
        ],
      ),
    );
  }
}

/// A part of a screen while it loads, inside a list or a column that is
/// already there: the loader and what is loading, with room around them.
class LoadingInline extends StatelessWidget {
  const LoadingInline({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('loading-inline'),
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(child: _LoaderWithLabel(label: label)),
    );
  }
}
