// Draws assets/tutorial/practice_photo.png: the LIT tutorial's practice
// photo for a phone whose camera will not start (Practice.samplePhoto). A
// drawing, never a real fire, so it cannot be taken for one.
//
// From the project root:
//   flutter test tool/tutorial/render_practice_photo_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draw the practice photo', () async {
    const size = Size(720, 960);
    final recorder = ui.PictureRecorder();
    _paintScene(Canvas(recorder, Offset.zero & size), size);
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      'assets/tutorial/practice_photo.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// A house at dusk, smoke from a lit window: the drawing the v1.12.37
/// tutorial showed in its practice camera.
void _paintScene(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2B3A55), Color(0xFF6B4E5E)],
      ).createShader(Offset.zero & size),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, h * 0.72, w, h * 0.28),
    Paint()..color = const Color(0xFF3A3F3A),
  );
  final house = Rect.fromLTWH(w * 0.28, h * 0.42, w * 0.44, h * 0.32);
  canvas.drawRect(house, Paint()..color = const Color(0xFFB8A48C));
  canvas.drawPath(
    Path()
      ..moveTo(house.left - w * 0.04, house.top)
      ..lineTo(house.center.dx, h * 0.26)
      ..lineTo(house.right + w * 0.04, house.top)
      ..close(),
    Paint()..color = const Color(0xFF7A3B2E),
  );
  final window = Rect.fromLTWH(
    house.left + house.width * 0.15,
    house.top + house.height * 0.2,
    house.width * 0.28,
    house.height * 0.3,
  );
  canvas.drawRect(window, Paint()..color = const Color(0xFFFF9A3C));
  final smoke = Paint()..color = const Color(0x99808890);
  for (var i = 0; i < 4; i++) {
    canvas.drawCircle(
      Offset(window.center.dx + i * w * 0.03, window.top - i * h * 0.06),
      w * (0.04 + i * 0.015),
      smoke,
    );
  }
  canvas.drawRect(
    Rect.fromLTWH(
      house.right - house.width * 0.3,
      house.bottom - house.height * 0.45,
      house.width * 0.18,
      house.height * 0.45,
    ),
    Paint()..color = const Color(0xFF5A4636),
  );
}
