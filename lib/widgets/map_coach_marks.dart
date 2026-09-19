import 'package:flutter/material.dart';

import '../theme.dart';

/// "T8 · Map coach marks": the one pass over the live map that points at the
/// two things a resident has to recognise — an Area, and where SOS lives.
///
/// It sits over the real map rather than a picture of one, so what it points
/// at is what is there. Anything but the Got it button falls through to the
/// scrim, which also dismisses.
class MapCoachMarks extends StatelessWidget {
  const MapCoachMarks({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Semantics(
      container: true,
      label: 'A quick tour of the map',
      child: Stack(
        children: [
          // Scrim: Background/Scrim at the design's combined opacity.
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: context.pal.canvas.withValues(alpha: 0.45),
              ),
            ),
          ),
          // The Area, up where the map draws its incidents.
          Positioned(
            left: 48,
            top: media.padding.top + 48,
            child: const _Halo(diameter: 96),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: media.padding.top + 160,
            child: const _Callout(
              title: 'Reports group into Areas',
              body:
                  'Three neighbours reporting the same fire show up here as '
                  'one incident, not three.',
            ),
          ),
          // The SOS disc, over the middle of the tab bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 48,
            child: const Center(child: _Halo(diameter: 96)),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: media.padding.bottom + 152,
            child: const _Callout(
              title: 'SOS lives here',
              body:
                  'Hold it for three seconds from any screen. A tap does '
                  'nothing.',
              pointsDown: true,
            ),
          ),
          Positioned(
            right: 18,
            top: media.padding.top + 48,
            child: _GotIt(onTap: onDismiss),
          ),
        ],
      ),
    );
  }
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
            BoxShadow(
              color: context.pal.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.title,
    required this.body,
    this.pointsDown = false,
  });

  final String title;
  final String body;

  /// A pointer under the card, for the mark that sits above its target.
  final bool pointsDown;

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
