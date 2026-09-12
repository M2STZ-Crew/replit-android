import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/widgets/design.dart';

/// The tab bar tints its glyphs (`Image.asset(..., color: ...)`), which keeps
/// each pixel's alpha and replaces its colour. A glyph exported from Figma
/// with the dark ground baked in is therefore painted as a solid square — how
/// all four tabs lost their icons. Every tinted glyph must be a real mask:
/// transparent around the edges, and not opaque everywhere.
void main() {
  Future<({int clear, int opaque})> coverage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final px = bytes!.buffer.asUint8List();
    var clear = 0, opaque = 0;
    for (var i = 3; i < px.length; i += 4) {
      if (px[i] < 20) clear++;
      if (px[i] > 200) opaque++;
    }
    return (clear: clear * 400 ~/ px.length, opaque: opaque * 400 ~/ px.length);
  }

  for (final icon in [
    Art.navMap,
    Art.navHotlines,
    Art.navGuides,
    Art.navProfile,
  ]) {
    testWidgets('${icon.split('/').last} is a glyph, not a filled square', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final c = await coverage(icon);
        expect(
          c.clear,
          greaterThan(40),
          reason: '$icon has no transparent ground — it will tint as a square',
        );
        expect(c.opaque, greaterThan(5), reason: '$icon has no glyph left');
        expect(c.opaque, lessThan(60), reason: '$icon is mostly solid');
      });
    });
  }
}
