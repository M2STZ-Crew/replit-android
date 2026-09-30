import 'package:flutter/material.dart';

/// A sheet over a map that the resident can drag down out of the way.
///
/// Dragged down — or its [header] tapped — it folds away to just the header
/// (the grab handle and the section title), so the map behind it is clear.
/// Dragged up, or the header tapped again, it opens back out. The whole sheet
/// takes the drag, not only the handle, and a tap on a row still lands: a
/// touch only becomes a drag once it moves.
///
/// [frame] draws the sheet itself — its glass, corners and padding — around
/// the header and body, so the frame's own padding is part of what drags.
class DragDownSheet extends StatefulWidget {
  const DragDownSheet({
    super.key,
    required this.header,
    required this.body,
    required this.frame,
    this.onChanged,
  });

  /// What stays showing when the sheet is folded down.
  final Widget header;

  /// What folds away.
  final Widget body;
  final Widget Function(BuildContext context, Widget content) frame;

  /// Told whenever the sheet settles open (true) or folded (false).
  final ValueChanged<bool>? onChanged;

  @override
  State<DragDownSheet> createState() => DragDownSheetState();
}

class DragDownSheetState extends State<DragDownSheet>
    with SingleTickerProviderStateMixin {
  /// 1 is open, 0 is folded down to the header.
  late final AnimationController _openness = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  final GlobalKey _bodyKey = GlobalKey();
  bool _open = true;

  /// Whether the sheet is (or is settling) open.
  bool get isOpen => _open;

  @override
  void dispose() {
    _openness.dispose();
    super.dispose();
  }

  /// The body's full height. The fold clips it rather than squeezing it, so
  /// this is the same folded or open.
  double get _travel => _bodyKey.currentContext?.size?.height ?? 0;

  void _drag(DragUpdateDetails d) {
    final travel = _travel;
    if (travel <= 0) return;
    _openness.value -= (d.primaryDelta ?? 0) / travel;
  }

  void _release(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    // A flick decides by its direction; a slow drag by how far it got.
    _settle(velocity.abs() > 400 ? velocity < 0 : _openness.value > 0.5);
  }

  /// Fold the sheet away, or open it back out.
  void toggle() => _settle(!_open);

  void _settle(bool open) {
    _openness.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);
    if (open == _open) return;
    setState(() => _open = open);
    widget.onChanged?.call(open);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _drag,
      onVerticalDragEnd: _release,
      child: widget.frame(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: _open ? 'Hide the list' : 'Show the list',
              onTap: toggle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: toggle,
                child: widget.header,
              ),
            ),
            // Folded, the rows are clipped away, out of reach of a tap and
            // of a screen reader alike.
            ExcludeSemantics(
              excluding: !_open,
              child: SizeTransition(
                sizeFactor: _openness,
                // Keep the top of the rows attached to the title as it folds.
                alignment: Alignment.topCenter,
                child: KeyedSubtree(key: _bodyKey, child: widget.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
