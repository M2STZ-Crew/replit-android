import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';

/// Keeps the app readable on a tablet, and lets a map or a camera fill it.
///
/// Every frame in the hand-off is drawn at 402 px, a phone. Stretched across
/// an iPad that layout falls apart in the way phone-first layouts always do:
/// a line of body text runs 900 px wide, a 54px button spans the room, and a
/// card's contents drift to opposite edges. So on anything wider than a phone
/// a screen keeps its column and centres it, with the ground filling the
/// rest. Below the threshold (every phone, and a small tablet in portrait)
/// this is a pass-through and costs nothing.
///
/// v1.12.43 (13 November 2026: "the responsiveness for tablets ... we want
/// to make it responsive to all devices"; answered: maps full, the rest
/// centred): the column was the whole app's, so a map sat in a 600 px strip
/// between dark sides. Now each screen has its own frame (every pushed page,
/// through [FramedPageTransitions]); a map or a camera says [FullBleed] and
/// fills the tablet; a tab with a bar keeps its content in a
/// [ReadingColumn] while its ground and bar run edge to edge.
class ResponsiveFrame extends StatefulWidget {
  const ResponsiveFrame({super.key, required this.child});

  final Widget child;

  /// The widest a reading screen's column is ever drawn. A little over the
  /// design's 402 px, so a tablet gains some room without the line lengths
  /// going long.
  static const double maxWidth = 600;

  /// Below this the frame does nothing: phones, and a 7" tablet in portrait,
  /// which are close enough to the drawn layout to leave alone.
  static const double threshold = maxWidth + 40;

  @override
  State<ResponsiveFrame> createState() => _ResponsiveFrameState();
}

class _ResponsiveFrameState extends State<ResponsiveFrame> {
  final _Claims _claims = _Claims();

  @override
  void dispose() {
    _claims.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FrameScope(
      claims: _claims,
      child: _Frame(
        claims: _claims,
        ground: context.pal.background,
        child: widget.child,
      ),
    );
  }
}

/// A screen that fills a tablet: a map, a camera, or a tab whose content
/// keeps its own [ReadingColumn] under an edge-to-edge bar. Its page's
/// [ResponsiveFrame] then lays it out full width. Anywhere without a frame
/// it does nothing.
class FullBleed extends StatefulWidget {
  const FullBleed({super.key, required this.child});

  final Widget child;

  @override
  State<FullBleed> createState() => _FullBleedState();
}

class _FullBleedState extends State<FullBleed> {
  _Claims? _claims;

  /// Claims its page's frame: while the page is built, so the frame lays it
  /// out full width in the same frame.
  void _attach() {
    final claims = context.getInheritedWidgetOfExactType<_FrameScope>()?.claims;
    if (identical(claims, _claims)) return;
    _claims?.release();
    _claims = claims?..claim();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void activate() {
    super.activate();
    _attach();
  }

  /// Taken out of the page: let go now, during the build, so that this very
  /// frame lays the page out in its column again (dispose comes only after
  /// the frame).
  @override
  void deactivate() {
    _claims?.release();
    _claims = null;
    super.deactivate();
  }

  @override
  void dispose() {
    _claims?.release();
    _claims = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A reading screen's content on a tablet: the design's column, centred at
/// the top, while the screen's ground and bars around it run edge to edge.
/// A pass-through on a phone.
class ReadingColumn extends StatelessWidget {
  const ReadingColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedWidth || box.maxWidth < ResponsiveFrame.threshold) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveFrame.maxWidth,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// A [SafeArea] whose content keeps the reading column on a tablet: a tab's
/// body, under its edge-to-edge bar.
class ReadingSafeArea extends StatelessWidget {
  const ReadingSafeArea({
    super.key,
    this.top = true,
    this.bottom = true,
    required this.child,
  });

  final bool top;
  final bool bottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ReadingColumn(
      child: SafeArea(top: top, bottom: bottom, child: child),
    );
  }
}

/// Every pushed page in its [ResponsiveFrame], moving with the page as the
/// platform's own transition moves it.
class FramedPageTransitions extends PageTransitionsBuilder {
  const FramedPageTransitions(this.inner);

  /// The platform's transition, which does the moving.
  final PageTransitionsBuilder inner;

  /// [theme]'s transitions, each with the frame.
  static PageTransitionsTheme around(PageTransitionsTheme theme) =>
      PageTransitionsTheme(
        builders: {
          for (final entry in theme.builders.entries)
            entry.key: entry.value is FramedPageTransitions
                ? entry.value
                : FramedPageTransitions(entry.value),
        },
      );

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return inner.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      ResponsiveFrame(child: child),
    );
  }
}

/// How many [FullBleed]s a page holds just now.
class _Claims extends ChangeNotifier {
  int _count = 0;

  bool get any => _count > 0;

  void claim() {
    _count++;
    if (_count == 1) notifyListeners();
  }

  void release() {
    _count--;
    if (_count == 0) notifyListeners();
  }
}

class _FrameScope extends InheritedWidget {
  const _FrameScope({required this.claims, required super.child});

  final _Claims claims;

  @override
  bool updateShouldNotify(_FrameScope old) => !identical(old.claims, claims);
}

class _Frame extends SingleChildRenderObjectWidget {
  const _Frame({required this.claims, required this.ground, super.child});

  final _Claims claims;
  final Color ground;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFrame(claims, ground);

  @override
  void updateRenderObject(BuildContext context, _RenderFrame renderObject) {
    renderObject
      ..claims = claims
      ..ground = ground;
  }
}

/// The page full width when its screen claims it ([FullBleed]) or the
/// screen is a phone's; otherwise the column, centred on the ground. A
/// [FullBleed] claims while the page is being built, before this lays it
/// out, so a map's first frame is already full width.
class _RenderFrame extends RenderShiftedBox {
  _RenderFrame(this._claims, this._ground) : super(null) {
    _claims.addListener(markNeedsLayout);
  }

  _Claims _claims;
  set claims(_Claims value) {
    if (identical(value, _claims)) return;
    _claims.removeListener(markNeedsLayout);
    _claims = value..addListener(markNeedsLayout);
    markNeedsLayout();
  }

  Color _ground;
  set ground(Color value) {
    if (value == _ground) return;
    _ground = value;
    markNeedsPaint();
  }

  bool _column = false;

  @override
  void dispose() {
    _claims.removeListener(markNeedsLayout);
    super.dispose();
  }

  @override
  void performLayout() {
    final child = this.child;
    _column =
        constraints.hasBoundedWidth &&
        constraints.maxWidth >= ResponsiveFrame.threshold &&
        !_claims.any;
    if (child == null) {
      size = constraints.biggest;
      return;
    }
    if (!_column) {
      child.layout(constraints, parentUsesSize: true);
      (child.parentData! as BoxParentData).offset = Offset.zero;
      size = constraints.constrain(child.size);
      return;
    }
    child.layout(
      constraints.copyWith(
        minWidth: ResponsiveFrame.maxWidth,
        maxWidth: ResponsiveFrame.maxWidth,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(constraints.maxWidth, child.size.height));
    (child.parentData! as BoxParentData).offset = Offset(
      (size.width - child.size.width) / 2,
      0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_column) {
      context.canvas.drawRect(offset & size, Paint()..color = _ground);
    }
    super.paint(context, offset);
  }
}
