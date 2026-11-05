import 'package:flutter/material.dart';

import '../theme.dart';
import 'design.dart';
import 'placeholder_box.dart';

/// The RepLiT wordmark, shown in every top bar.
///
/// Draws the project logo at **assets/images/logo.png** — white letters with
/// the coral signal bars and pin, made for the dark ground. On the light
/// ground it draws **assets/images/logo-light.png**, the same artwork with the
/// letters in the light theme's ink, so the wordmark never disappears into a
/// pale bar. If the logo will not load, the v2 hand-off's wordmark
/// (assets/design/wordmark.png) stands in, and if neither loads, a labelled
/// placeholder keeps the bar from collapsing.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width = 130,
    this.height = 36,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  static const String dark = 'assets/images/logo.png';
  static const String light = 'assets/images/logo-light.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      context.pal.isLight ? light : dark,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Image.asset(
        Art.wordmark,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => PlaceholderBox(
          width: width,
          height: height,
          label: 'LOGO',
          radius: radius,
        ),
      ),
    );
  }
}
