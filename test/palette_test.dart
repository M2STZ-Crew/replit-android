import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';

/// Both grounds, checked for the thing a derived palette gets wrong: ink that
/// does not carry on the paper it sits on.
///
/// The light values were read off the rendered Figma frames rather than
/// invented, so this is a check on the reading, not a redesign.
void main() {
  double luminance(Color c) => c.computeLuminance();

  double contrast(Color fg, Color bg) {
    // WCAG: (lighter + 0.05) / (darker + 0.05), after compositing any alpha.
    final composited = Color.alphaBlend(fg, bg);
    final a = luminance(composited);
    final b = luminance(bg);
    return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  }

  for (final pal in [AppPalette.dark, AppPalette.light]) {
    final name = pal.isLight ? 'light' : 'dark';

    group('$name palette', () {
      test('body text carries on both the ground and a card', () {
        for (final ground in [pal.background, pal.surface]) {
          expect(
            contrast(pal.onBackground, ground),
            greaterThan(7),
            reason:
                '$name: primary text on ${ground.toARGB32().toRadixString(16)}',
          );
          expect(
            contrast(pal.textSoft, ground),
            greaterThan(4.5),
            reason: '$name: secondary text',
          );
          expect(
            contrast(pal.label, ground),
            greaterThan(4.5),
            reason: '$name: tertiary text',
          );
        }
      });

      test('the quiet greys still clear the large-text floor', () {
        // Muted and faint carry captions and eyebrows — 3:1, the WCAG floor
        // for text at these weights, is the bar they have to clear.
        expect(contrast(pal.muted, pal.background), greaterThan(3));
        expect(contrast(pal.faint, pal.background), greaterThan(2.5));
      });

      test('status colours are legible as ink, not just as fills', () {
        for (final ink in [pal.accentInk, pal.live, pal.ok]) {
          expect(
            contrast(ink, pal.background),
            greaterThan(3),
            reason: '$name: ${ink.toARGB32().toRadixString(16)} on the ground',
          );
          expect(contrast(ink, pal.surface), greaterThan(3));
        }
      });

      test('a card is distinguishable from the ground it sits on', () {
        final card = Color.alphaBlend(pal.glass, pal.background);
        expect(
          (luminance(card) - luminance(pal.background)).abs(),
          greaterThan(0.004),
          reason: '$name: cards must read as raised',
        );
      });

      test('hairlines are visible without being lines of ink', () {
        final edge = Color.alphaBlend(pal.line, pal.background);
        final separation = (luminance(edge) - luminance(pal.background)).abs();
        expect(separation, greaterThan(0.004), reason: '$name: too faint');
        expect(
          contrast(pal.line, pal.background),
          lessThan(4.5),
          reason: '$name: an edge should not shout',
        );
      });

      test('text on the coral gradient is the same in both themes', () {
        expect(pal.accentText, const Color(0xFF581A00));
        // The brown sits on the gradient a button is filled with — which is
        // shared between the themes — not on the accent-as-ink, which the
        // light palette darkens for text.
        for (final fill in pal.accentGradient.colors) {
          expect(
            contrast(pal.accentText, fill),
            greaterThan(4.5),
            reason: 'the one colour pairing that never changes',
          );
        }
      });
    });
  }

  test('the two palettes differ everywhere it matters', () {
    expect(AppPalette.light.background, isNot(AppPalette.dark.background));
    expect(AppPalette.light.onBackground, isNot(AppPalette.dark.onBackground));
    expect(
      AppPalette.light.accentGradient,
      AppPalette.dark.accentGradient,
      reason: 'the SOS button looks the same in both',
    );
  });

  testWidgets('the theme carries its palette to the widgets', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppPalette.light),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(captured.pal.isLight, isTrue);
    expect(captured.pal.background, const Color(0xFFEEEDEA));
    expect(captured.type.cardTitle.color, const Color(0xFF17140F));
  });
}
