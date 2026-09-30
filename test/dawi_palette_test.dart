import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';

/// The citizen palette follows the REPLIT x DAWI colour sheet.
void main() {
  const dark = AppPalette.dark;

  test('cards are solid SURFACE/grey-500 on BACKGROUND/grey-400 edges', () {
    expect(dark.background, const Color(0xFF131313));
    expect(dark.glass, const Color(0xFF1D1D1D));
    expect(dark.line, const Color(0xFF424242));
    expect(dark.lineStrong, const Color(0xFF4A4A4A));
  });

  test('police is violet, medical teal, barangay amber, water blue', () {
    expect(dark.police, const Color(0xFF8B5CF6));
    expect(dark.medical, const Color(0xFF14B8A6));
    expect(dark.barangay, const Color(0xFFFFB020));
    expect(dark.water, const Color(0xFF5B93F5));
    expect(dark.forAgency('police'), dark.police);
    expect(dark.forAgency('fire_volunteer'), const Color(0xFFFF9066));
  });

  test("each accent's well is its 900 shade, with a white glyph", () {
    expect(dark.wellFor(dark.accent), const Color(0xFF6B3C2B));
    expect(dark.wellFor(dark.police), const Color(0xFF3A2767));
    expect(dark.wellFor(dark.medical), const Color(0xFF084D46));
    expect(dark.wellFor(dark.barangay), const Color(0xFF6B4A0D));
    expect(dark.wellFor(dark.ok), const Color(0xFF0E5327));
    expect(dark.glyphOn(dark.police), Colors.white);
    // A tint without a 900 still gets a solid, dark well.
    expect(dark.wellFor(dark.live).a, 1);
  });

  test('the light theme keeps its washes and tinted glyphs', () {
    const light = AppPalette.light;
    expect(light.wellFor(light.police).a, closeTo(0.16, 0.01));
    expect(light.glyphOn(light.police), light.police);
  });
}
