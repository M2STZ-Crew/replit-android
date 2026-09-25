import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// "T8 · Map coach marks": the one pass over the live map that points at the
/// two things a resident has to recognise — an Area, and where SOS lives.
///
/// It sits over the real map rather than a picture of one, so what it points
/// at is what is there: the screen tells it where the SOS disc and an Area
/// marker are, and the rings go round those. Anything but the Got it button
/// falls through to the scrim, which also dismisses.
class MapCoachMarks extends StatelessWidget {
  const MapCoachMarks({
    super.key,
    required this.sosLift,
    required this.onDismiss,
    this.area,
    this.sheetTop,
  });

  /// How far above the bottom edge the centre of the SOS disc sits.
  final double sosLift;

  /// Centre of an Area marker to ring, in this widget's coordinates; null
  /// when none is on screen.
  final Offset? area;

  /// Where the areas sheet begins. With no Area on screen to ring, the
  /// Areas callout sits just above the sheet, which lists them.
  final double? sheetTop;

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'A quick tour of the map',
      child: CustomMultiChildLayout(
        delegate: _CoachLayout(
          sosLift: sosLift,
          area: area,
          sheetTop: sheetTop,
          safeTop: MediaQuery.paddingOf(context).top,
        ),
        children: [
          // Scrim: Background/Scrim at the design's combined opacity.
          LayoutId(
            id: _Slot.scrim,
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: context.pal.canvas.withValues(alpha: 0.45),
              ),
            ),
          ),
          if (area != null)
            LayoutId(
              id: _Slot.areaHalo,
              child: const _Halo(diameter: _CoachLayout.halo),
            ),
          LayoutId(
            id: _Slot.areaCallout,
            child: const _Callout(
              width: 290,
              title: 'Reports group into Areas',
              body:
                  'Three neighbours reporting the same fire show up here as '
                  'one incident, not three.',
            ),
          ),
          LayoutId(
            id: _Slot.sosHalo,
            child: const _Halo(diameter: _CoachLayout.halo),
          ),
          LayoutId(
            id: _Slot.sosCallout,
            child: const _Callout(
              width: 300,
              title: 'SOS lives here',
              body:
                  'Hold it for three seconds from any screen. A tap does '
                  'nothing.',
              pointsDown: true,
            ),
          ),
          LayoutId(
            id: _Slot.gotIt,
            child: _GotIt(onTap: onDismiss),
          ),
        ],
      ),
    );
  }
}

enum _Slot { scrim, areaHalo, areaCallout, sosHalo, sosCallout, gotIt }

/// Rings on the targets, each callout beside its ring: SOS's above the disc,
/// the Area's below its marker — or above it, where below would run into
/// SOS's.
class _CoachLayout extends MultiChildLayoutDelegate {
  _CoachLayout({
    required this.sosLift,
    required this.area,
    required this.sheetTop,
    required this.safeTop,
  });

  final double sosLift;
  final Offset? area;
  final double? sheetTop;
  final double safeTop;

  static const double halo = 96;
  static const double _gap = 8;
  static const double _margin = 24;

  @override
  void performLayout(Size size) {
    layoutChild(_Slot.scrim, BoxConstraints.tight(size));
    positionChild(_Slot.scrim, Offset.zero);

    const ring = BoxConstraints.tightFor(width: halo, height: halo);
    final card = BoxConstraints(
      maxWidth: math.max(0, size.width - 2 * _margin),
    );
    const radius = Offset(halo / 2, halo / 2);

    // SOS: the ring round the disc, the callout's pointer just above it.
    final sos = Offset(size.width / 2, size.height - sosLift);
    layoutChild(_Slot.sosHalo, ring);
    positionChild(_Slot.sosHalo, sos - radius);
    final sosCard = layoutChild(_Slot.sosCallout, card);
    final sosTop = sos.dy - halo / 2 - _gap / 2 - sosCard.height;
    positionChild(
      _Slot.sosCallout,
      Offset((size.width - sosCard.width) / 2, sosTop),
    );

    // Got it, top right.
    final gotIt = layoutChild(_Slot.gotIt, const BoxConstraints());
    final gotItTop = safeTop + 48;
    positionChild(_Slot.gotIt, Offset(size.width - 18 - gotIt.width, gotItTop));

    // The Area.
    final areaCard = layoutChild(_Slot.areaCallout, card);
    final ceiling = gotItTop + gotIt.height + _gap;
    final floor = sosTop - _gap;
    double top;
    final target = area;
    if (target != null && hasChild(_Slot.areaHalo)) {
      layoutChild(_Slot.areaHalo, ring);
      positionChild(_Slot.areaHalo, target - radius);
      final below = target.dy + halo / 2 + _gap;
      top = below + areaCard.height <= floor
          ? below
          : target.dy - halo / 2 - _gap - areaCard.height;
    } else {
      top = math.min(sheetTop ?? floor, floor) - _gap - areaCard.height;
    }
    top = top.clamp(ceiling, math.max(ceiling, floor - areaCard.height));
    positionChild(_Slot.areaCallout, Offset(_margin, top));
  }

  @override
  bool shouldRelayout(_CoachLayout old) =>
      old.sosLift != sosLift ||
      old.area != area ||
      old.sheetTop != sheetTop ||
      old.safeTop != safeTop;
}

/// The ring drawn around whatever a mark is pointing at.
class _Halo extends StatelessWidget {
  const _Halo({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: context.pal.accent.withValues(alpha: 0.9),
            width: 2,
          ),
          boxShadow: [
            // Outside the ring only, so what it rings stays clear.
            BoxShadow(
              color: context.pal.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: 2,
              blurStyle: BlurStyle.outer,
            ),
          ],
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.width,
    required this.title,
    required this.body,
    this.pointsDown = false,
  });

  /// The card's width in the frame; narrower screens get what they have.
  final double width;
  final String title;
  final String body;

  /// A pointer under the card, for the mark that sits above its target.
  final bool pointsDown;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.pal.surfaceSolid,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: context.pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: context.type.rowTitleLg),
          const SizedBox(height: 4),
          Text(body, style: context.type.bodySm),
        ],
      ),
    );
    if (!pointsDown) return card;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        CustomPaint(
          size: const Size(18, 10),
          painter: _PointerPainter(
            fill: context.pal.surfaceSolid,
            edge: context.pal.line,
          ),
        ),
      ],
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.fill != fill || old.edge != edge;
}

class _GotIt extends StatelessWidget {
  const _GotIt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: context.pal.surfaceSolid,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: context.pal.line),
          ),
          child: Text('Got it', style: context.type.rowTitleLg),
        ),
      ),
    );
  }
}
