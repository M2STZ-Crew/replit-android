import 'package:flutter/material.dart';

import 'design.dart';
import 'placeholder_box.dart';

/// The RepLiT wordmark, shown in every top bar.
///
/// Draws the wordmark from the "General User App v2" hand-off
/// (assets/design/wordmark.png). A project logo dropped at
/// **assets/images/logo.png** overrides it, so the brand can still be changed
/// in one place without touching the design bundle. If neither file loads, a
/// labelled placeholder keeps the bar from collapsing.
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

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
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
