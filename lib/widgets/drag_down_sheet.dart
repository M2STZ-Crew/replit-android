import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

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
    this.subject = 'the list',
    this.autoFoldAfter,
    this.moving = false,
  });

  /// What stays showing when the sheet is folded down.
  final Widget header;

  /// What folds away.
  final Widget body;
  final Widget Function(BuildContext context, Widget content) frame;

  /// Told whenever the sheet settles open (true) or folded (false).
  final ValueChanged<bool>? onChanged;

  /// What folds away, for a screen reader: "Hide the list", "Show the list".
  final String subject;

  /// Fold away by itself this long after it opens or is last touched
  /// (12 Nov 2026: "the slider drawer in map route navigation
  /// automatically lowers when the driver is moving or after 3 seconds (can
  /// be swiped up again)"). Null: it stays as it is left.
  final Duration? autoFoldAfter;

  /// The vehicle is moving: with [autoFoldAfter], an open sheet folds away
  /// as the movement starts.
  final bool moving;

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
  Timer? _foldTimer;

  @override
  void initState() {
    super.initState();
    _armFold();
  }

  @override
  void didUpdateWidget(DragDownSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (widget.autoFoldAfter != old.autoFoldAfter) _armFold();
    if (widget.autoFoldAfter != null && widget.moving && !old.moving && _open) {
      _settle(false);
    }
  }

  /// Start (again) the wait before the sheet folds itself away.
  void _armFold() {
    _foldTimer?.cancel();
    final after = widget.autoFoldAfter;
    if (after == null || !_open) return;
    _foldTimer = Timer(after, () {
      if (mounted && _open) _settle(false);
    });
  }

  /// Whether the sheet is (or is settling) open.
  bool get isOpen => _open;

  @override
  void dispose() {
    _foldTimer?.cancel();
    _openness.dispose();
    super.dispose();
  }

  /// The body's full height. The fold clips it rather than squeezing it, so
  /// this is the same folded or open.
  double get _travel => _bodyKey.currentContext?.size?.height ?? 0;

  void _drag(DragUpdateDetails d) {
    _foldTimer?.cancel();
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
    final changed = open != _open;
    if (changed) setState(() => _open = open);
    // Open again — by a drag, a tap, or as it was — the wait starts over.
    if (open) {
      _armFold();
    } else {
      _foldTimer?.cancel();
    }
    if (changed) widget.onChanged?.call(open);
  }

  @override
  Widget build(BuildContext context) {
    // A finger on the sheet holds it open; lifted, the wait starts over.
    return Listener(
      onPointerDown: (_) => _foldTimer?.cancel(),
      onPointerUp: (_) => _armFold(),
      child: GestureDetector(
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
                label: _open
                    ? t('Hide {what}', {'what': t(widget.subject)})
                    : t('Show {what}', {'what': t(widget.subject)}),
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
      ),
    );
  }
}
