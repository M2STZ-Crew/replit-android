import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';

/// The citizen palette follows the REPLIT x DAWI colour sheet, as REPLIT
/// (MAIN) pass 4 refined it (03 · Semantic colour tokens).
void main() {
  const dark = AppPalette.dark;

  test('cards are solid surface/default on the translucent hairline', () {
    expect(dark.background, const Color(0xFF131313));
    expect(dark.glass, const Color(0xFF1D1D1D));
    // color/border/subtle: the PRD hairline, rgba(72,72,71,.35).
    expect(dark.line, const Color(0x59484847));
    // color/border/default: a control's edge, 3 : 1 on a card.
    expect(dark.lineStrong, const Color(0xFF686868));
  });

  test('text steps down from primary to muted, never below 4.5 : 1', () {
    expect(dark.onBackground, const Color(0xFFF3F3F3));
    expect(dark.textSoft, const Color(0xFFC9C9C9));
    expect(dark.label, const Color(0xFFA1A1A1));
    expect(dark.muted, const Color(0xFF8A8A8A));
    expect(dark.faint, dark.muted, reason: 'grey-600 is retired for text');
  });

  test('police is violet, medical teal, barangay amber, water blue', () {
    // violet-300: violet-500 measures 3.98 : 1 on a card.
    expect(dark.police, const Color(0xFFB192F9));
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
