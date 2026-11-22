import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'design.dart';

/// The grab handle of a [DraggableScrollableSheet], frozen at the top of it.
///
/// The pill used to be the first row of the sheet's list, so it scrolled away
/// with the rows (the 5 November issue list, 1.9). Laid out above the list
/// instead — `Column(children: [SheetGrip(...), Expanded(child: list)])` — it
/// stays at the top centre of the sheet however far the list scrolls, and the
/// list is clipped below it rather than passing behind it.
///
/// A vertical drag on the grip still moves the sheet, as a drag on the list
/// does: the sheet follows the finger, and a flick sends it to its nearest end
/// in the flick's direction. With [snapSizes] a slow release settles on the
/// nearest stop — its ends and those sizes — as `snap: true` does for a drag
/// on the list; pass an empty list for a sheet that snaps only to its ends.
class SheetGrip extends StatelessWidget {
  const SheetGrip({
    super.key,
    required this.sheet,
    required this.minSize,
    required this.maxSize,
    this.snapSizes,
    this.onTap,
    this.semanticsLabel,
    this.padding = const EdgeInsets.fromLTRB(24, 10, 24, 16),
    this.child,
  });

  /// The sheet this grip moves. It must be the sheet's own `controller`.
  final DraggableScrollableController sheet;

  /// The sheet's `minChildSize` and `maxChildSize`: where a flick ends.
  final double minSize;
  final double maxSize;

  /// Where a slow release settles, besides the ends, when the sheet snaps;
  /// null when it does not.
  final List<double>? snapSizes;

  /// A tap on the grip (folding or opening the sheet, say).
  final VoidCallback? onTap;

  /// What a screen reader calls the grip when it has an [onTap].
  final String? semanticsLabel;

  /// Space around the handle: the top inset, and the gap to the first row.
  final EdgeInsets padding;

  /// Anything frozen with the handle, under it (a sheet's title, say).
  final Widget? child;

  /// Above this speed (logical px/s) a release is a flick.
  static const double flickVelocity = 600;

  static const Duration _settle = Duration(milliseconds: 240);

  void _drag(DragUpdateDetails d) {
    if (!sheet.isAttached) return;
    final next = sheet.size - sheet.pixelsToSize(d.primaryDelta ?? 0);
    // The sheet clamps to its own min and max; 0..1 is jumpTo's contract.
    sheet.jumpTo(next.clamp(0.0, 1.0));
  }

  void _release(DragEndDetails d) {
    if (!sheet.isAttached) return;
    final velocity = d.primaryVelocity ?? 0;
    final double target;
    if (velocity.abs() > flickVelocity) {
      target = velocity < 0 ? maxSize : minSize;
    } else if (snapSizes case final snaps?) {
      final stops = {minSize, ...snaps, maxSize};
      target = stops.reduce(
        (a, b) => (a - sheet.size).abs() <= (b - sheet.size).abs() ? a : b,
      );
    } else {
      return;
    }
    sheet.animateTo(target, duration: _settle, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final grip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _drag,
      onVerticalDragEnd: _release,
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: SheetHandle(
                key: SheetGrip.handleKey,
                margin: EdgeInsets.zero,
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
    if (onTap == null) return grip;
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      child: grip,
    );
  }

  /// The handle's key, for tests that check it stays put.
  static const Key handleKey = ValueKey('sheet-grip-handle');
}

/// A modal sheet's content with the grab handle and Close frozen on top.
///
/// The handle, then [children] in a scroll view that takes what is left of the
/// sheet: short content hugs the handle, long content scrolls under it instead
/// of carrying it away. [padding] is the scroll view's (the sides and the
/// bottom); the handle keeps its own [handlePadding].
///
/// v1.12.59 (22 Nov 2026; answered "All drawers + X"): in a drawer that may
/// be dismissed, Close sits at the top right for anyone who can't swipe, and
/// a pull down at the top of the list slides the drawer away ([SheetScroll]).
class FrozenHandleSheet extends StatelessWidget {
  const FrozenHandleSheet({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    this.handlePadding = const EdgeInsets.only(top: 10, bottom: 16),
    this.handleColor,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final EdgeInsets handlePadding;

  /// When the sheet's own design draws the handle in another colour.
  final Color? handleColor;

  /// How [children] line up across the sheet.
  final CrossAxisAlignment crossAxisAlignment;

  /// The Close's key, for tests.
  static const Key closeKey = ValueKey('sheet-close');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTop(padding: handlePadding, color: handleColor),
        Flexible(
          child: SheetScroll(
            padding: padding,
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// The handle and, where the drawer may be dismissed, Close. All of it takes
/// the drag, not only the 4 px pill.
class _SheetTop extends StatelessWidget {
  const _SheetTop({required this.padding, this.color});

  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    // A drawer that must be answered (the first email link) has no Close.
    final closable =
        route is ModalBottomSheetRoute &&
        route.isDismissible &&
        route.enableDrag;
    final handle = color == null
        ? const SheetHandle(key: SheetGrip.handleKey, margin: EdgeInsets.zero)
        : Container(
            key: SheetGrip.handleKey,
            width: 80,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
    return ColoredBox(
      color: Colors.transparent,
      child: closable
          ? SizedBox(
              height: kMinInteractiveDimension,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: padding.top),
                      child: handle,
                    ),
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 4,
                    child: IconButton(
                      key: FrozenHandleSheet.closeKey,
                      tooltip: t('Close'),
                      constraints: const BoxConstraints.tightFor(
                        width: kMinInteractiveDimension,
                        height: kMinInteractiveDimension,
                      ),
                      icon: Icon(
                        AppIcons.close,
                        size: 22,
                        color: context.pal.label,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: padding,
              child: Center(child: handle),
            ),
    );
  }
}

/// A drawer's scroll view that gives way at its top: pulled down there, the
/// drawer follows the finger and closes as it does from its handle; anywhere
/// else, or pulled up, the list scrolls.
///
/// A list that scrolls used to take every swipe, so a long drawer (Fire
/// codes) could not be slid down while a short one (Alarm level) could.
class SheetScroll extends StatefulWidget {
  const SheetScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<SheetScroll> createState() => _SheetScrollState();
}

class _SheetScrollState extends State<SheetScroll> {
  /// Flutter's own for a bottom sheet: a flick this fast closes it, and so
  /// does a release under half open.
  static const double _closingVelocity = 700;
  static const double _closingOpenness = 0.5;

  final ScrollController _scroll = ScrollController();

  /// The drawer being pulled, and its height as the pull began.
  BottomSheet? _sheet;
  double _height = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _atTop() =>
      !_scroll.hasClients ||
      _scroll.position.pixels <= _scroll.position.minScrollExtent + 0.5;

  void _start(DragStartDetails details) {
    BottomSheet? sheet;
    var height = 0.0;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is! BottomSheet) return true;
      sheet = widget;
      height = (element.findRenderObject() as RenderBox?)?.size.height ?? 0;
      return false;
    });
    final found = sheet;
    final openness = found?.animationController;
    if (found == null || openness == null || height <= 0) return;
    if (openness.status == AnimationStatus.reverse) return; // already leaving
    _sheet = found;
    _height = height;
    // The sheet's own: it tracks the finger from here, not the entry curve.
    found.onDragStart?.call(details);
  }

  void _update(DragUpdateDetails details) {
    final openness = _sheet?.animationController;
    if (openness == null) return;
    openness.value -= (details.primaryDelta ?? 0) / _height;
  }

  void _end(DragEndDetails details) {
    final sheet = _sheet;
    _sheet = null;
    final openness = sheet?.animationController;
    if (sheet == null || openness == null) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final flicked = velocity > _closingVelocity;
    final closing = flicked || openness.value < _closingOpenness;
    if (!closing) {
      openness.forward();
    } else if (openness.value > 0) {
      openness.fling(velocity: flicked ? -velocity / _height : -1);
    }
    sheet.onDragEnd?.call(details, isClosing: closing);
    if (closing) sheet.onClosing();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final pulls = route is ModalBottomSheetRoute && route.enableDrag;
    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (pulls) {
      final settings = MediaQuery.maybeGestureSettingsOf(context);
      // Inside the scroll view, so it is asked before the list is: it only
      // answers a pull down at the top, and every other drag scrolls.
      content = RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        gestures: {
          _PullDownRecognizer:
              GestureRecognizerFactoryWithHandlers<_PullDownRecognizer>(
                () => _PullDownRecognizer(debugOwner: this),
                (pull) => pull
                  ..atTop = _atTop
                  ..gestureSettings = settings
                  ..onlyAcceptDragOnThreshold = true
                  ..onStart = _start
                  ..onUpdate = _update
                  ..onEnd = _end,
              ),
        },
        child: content,
      );
    }
    return SingleChildScrollView(controller: _scroll, child: content);
  }
}

/// A vertical drag that only starts downward, and only with the list at its
/// top.
class _PullDownRecognizer extends VerticalDragGestureRecognizer {
  _PullDownRecognizer({super.debugOwner});

  bool Function() atTop = () => false;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved >
          computeHitSlop(pointerDeviceKind, gestureSettings) &&
      atTop();
}
