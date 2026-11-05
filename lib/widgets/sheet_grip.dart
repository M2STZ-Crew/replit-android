import 'package:flutter/material.dart';

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

/// A modal sheet's content with the grab handle frozen on top.
///
/// The handle, then [children] in a scroll view that takes what is left of the
/// sheet: short content hugs the handle, long content scrolls under it instead
/// of carrying it away. [padding] is the scroll view's (the sides and the
/// bottom); the handle keeps its own [handlePadding].
class FrozenHandleSheet extends StatelessWidget {
  const FrozenHandleSheet({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    this.handlePadding = const EdgeInsets.only(top: 10, bottom: 16),
    this.handleColor,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final EdgeInsets handlePadding;

  /// When the sheet's own design draws the handle in another colour.
  final Color? handleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: handlePadding,
          child: Center(
            child: handleColor == null
                ? const SheetHandle(
                    key: SheetGrip.handleKey,
                    margin: EdgeInsets.zero,
                  )
                : Container(
                    key: SheetGrip.handleKey,
                    width: 80,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
