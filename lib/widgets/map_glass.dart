import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'map_tiles.dart';

/// The materials a panel over a map is made of (REPLIT (MAIN) 03 · pass 2).
///
///  * **Glass** — the ground at 50 % over an 18 px blur: floating map UI
///    with short bold labels only (layer chips, the place card, map
///    controls).
///  * **Glass strong** — the ground at 88 %: anything over a map that
///    carries body text or a status word (map sheets, banners, alerts).
///  * **Solid** — the ground itself, when the phone asks for more contrast.
///
/// Two rules decide which one a panel gets. On the light OpenStreetMap
/// fallback (no Mapbox token) a 50 % glass leaves tertiary text at 2.0 : 1,
/// so every overlay is drawn strong. Under the accessibility setting for more
/// contrast ([MediaQuery.highContrastOf] — Android's high-contrast text,
/// the nearest Android has to iOS "Reduce transparency") the glass becomes
/// solid ground and the blur goes.
abstract final class MapGlass {
  /// Figma's blur 18 is about a Gaussian sigma of 9.
  static final ImageFilter blur = ImageFilter.blur(sigmaX: 9, sigmaY: 9);

  /// Glass, for floating UI with short bold labels.
  static Color glass(BuildContext context) => _pick(context, strong: false);

  /// Glass strong, for anything carrying body text or status words.
  static Color strong(BuildContext context) => _pick(context, strong: true);

  /// Whether to blur at all: not when the panel is solid.
  static bool blurs(BuildContext context) =>
      !(MediaQuery.maybeHighContrastOf(context) ?? false);

  static Color _pick(BuildContext context, {required bool strong}) {
    final pal = context.pal;
    if (!blurs(context)) return pal.background;
    if (strong || !MapTiles.hasToken) return pal.glassStrong;
    return pal.glassOverlay;
  }
}
