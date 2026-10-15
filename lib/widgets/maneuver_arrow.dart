import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_icons.dart';

/// The arrow for a turn-by-turn maneuver (PRD v12 §4.9.3, "visual arrow"):
/// straight, bear, turn, sharp turn, U-turn or roundabout, left or right.
///
/// Drawn rather than taken from the icon font: the app's font is a subset cut
/// to the icons it uses, and the turn arrows are not among them. Departure
/// and arrival use the font's navigation arrow and flag. Decorative — the
/// instruction beside it says the same in words.
class ManeuverArrow extends StatelessWidget {
  const ManeuverArrow({
    super.key,
    required this.type,
    this.modifier,
    this.size = 44,
    this.color = Colors.white,
  });

  final String type;
  final String? modifier;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (type) {
      'arrive' => Icon(AppIcons.flag, size: size * 0.8, color: color),
      'depart' => Icon(AppIcons.navigation, size: size * 0.8, color: color),
      _ => CustomPaint(
        size: Size.square(size),
        painter: _ArrowPainter(
          angle: turnAngle(modifier),
          roundabout: type.contains('roundabout') || type.contains('rotary'),
          uturn: modifier == 'uturn',
          color: color,
        ),
      ),
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    );
  }

  /// Degrees clockwise from straight ahead: right is positive.
  static double turnAngle(String? modifier) => switch (modifier) {
    'slight right' => 40,
    'right' => 90,
    'sharp right' => 135,
    'slight left' => -40,
    'left' => -90,
    'sharp left' => -135,
    _ => 0,
  };
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.angle,
    required this.roundabout,
    required this.uturn,
    required this.color,
  });

  final double angle;
  final bool roundabout;
  final bool uturn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bottom = Offset(s * 0.5, s * 0.92);

    if (uturn) {
      // Up, round to the left, and back down (traffic keeps right here).
      final r = s * 0.17;
      final path = Path()
        ..moveTo(s * 0.62, s * 0.92)
        ..lineTo(s * 0.62, s * 0.42)
        ..arcToPoint(
          Offset(s * 0.62 - 2 * r, s * 0.42),
          radius: Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(s * 0.62 - 2 * r, s * 0.66);
      canvas.drawPath(path, stroke);
      _head(canvas, Offset(s * 0.62 - 2 * r, s * 0.7), math.pi, s, stroke);
      return;
    }

    final joint = Offset(s * 0.5, s * (roundabout ? 0.62 : 0.5));
    if (roundabout) {
      final centre = Offset(s * 0.5, s * 0.44);
      canvas.drawCircle(centre, s * 0.18, stroke..strokeWidth = s * 0.08);
      stroke.strokeWidth = s * 0.1;
    }
    canvas.drawLine(bottom, joint, stroke);
    final rad = angle * math.pi / 180;
    final length = s * (roundabout ? 0.3 : 0.36);
    final start = roundabout
        ? Offset(s * 0.5, s * 0.44) +
              Offset(math.sin(rad), -math.cos(rad)) * (s * 0.18)
        : joint;
    final end = start + Offset(math.sin(rad), -math.cos(rad)) * length;
    canvas.drawLine(start, end, stroke);
    _head(canvas, end, rad, s, stroke);
  }

  /// An open arrowhead at [tip], pointing [rad] clockwise from up.
  void _head(Canvas canvas, Offset tip, double rad, double s, Paint stroke) {
    final back = s * 0.16;
    for (final side in [-0.6, 0.6]) {
      final a = rad + math.pi + side;
      canvas.drawLine(
        tip,
        tip + Offset(math.sin(a), -math.cos(a)) * back,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.angle != angle ||
      old.roundabout != roundabout ||
      old.uturn != uturn ||
      old.color != color;
}
