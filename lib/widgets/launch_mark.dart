import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design.dart';

/// The flame-and-pin mark as the phone's own launch screen draws it, so the
/// splash that follows can put it in the same place at the same size and the
/// hand-off doesn't show.
///
/// The size: 80 wide on the design's 402-wide phone (the Figma's 100, a fifth
/// smaller), following the narrower side of the screen from there, within 64
/// and 100, in the image's own 410:576 proportions. iOS's launch screen uses
/// the same rule (ios/Runner/Base.lproj/LaunchScreen.storyboard). Android's
/// launch screens are drawn before the app runs, from sizes made in advance
/// for screens 320, 340, … 500 dp wide (android/…/res/values-sw*dp/
/// dimens.xml), so on Android the side is first rounded down to that 20 dp
/// step.
///
/// The place: the middle of the whole display, which is where both phones'
/// launch screens put it. Android 14 and older lay the app out above the
/// navigation bar, so there the middle of the display is a little below the
/// middle of the app; see [centreIn].
abstract final class LaunchMark {
  /// The mark's width on the design's phone, and the phone's width.
  static const double designWidth = 80;
  static const double designScreen = 402;

  /// assets/design/logo-mark.png is 410×576.
  static const double aspect = 410 / 576;

  /// The size the launch screens draw the mark at, on a screen whose
  /// narrower side is [side] logical pixels.
  static Size sizeFor(double side, {TargetPlatform? platform}) {
    final android =
        (platform ?? defaultTargetPlatform) == TargetPlatform.android;
    final from = android ? androidStep(side) : side;
    final width = (designWidth * from / designScreen).clamp(64.0, 100.0);
    return Size(width, width / aspect);
  }

  /// The screen width an Android launch screen was made for: [side] rounded
  /// down to 340, 360, … 500, or 320 below that. Android picks the
  /// values-swNNNdp folder the same way: the largest NNN not over the screen.
  static double androidStep(double side) {
    if (side < 340) return 320;
    if (side >= 500) return 500;
    return 340 + ((side - 340) ~/ 20) * 20;
  }

  /// Where the mark's centre goes in a view of [view] logical size.
  ///
  /// The middle of the display when the app's view is the display less a
  /// navigation bar along the bottom (Android 14 and older); the middle of
  /// the view otherwise, which covers edge-to-edge Android, iPhones, and a
  /// window in split screen.
  static Offset centreIn(BuildContext context, Size view) {
    final display = View.of(context).display;
    final full = display.size / display.devicePixelRatio;
    final below = full.height - view.height;
    if ((full.width - view.width).abs() < 1 && below > 0 && below <= 64) {
      return Offset(view.width / 2, full.height / 2);
    }
    return Offset(view.width / 2, view.height / 2);
  }

  /// Decode the mark before the app's first frame. Otherwise that frame has
  /// no mark yet, and as the phone's launch screen fades out over it the mark
  /// blinks. Called from main(); gives up after a second rather than hold the
  /// app back.
  static Future<void> precache() async {
    final done = Completer<void>();
    final stream = const AssetImage(
      Art.logoMark,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void finish() {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      (_, _) => finish(),
      onError: (_, _) => finish(),
    );
    stream.addListener(listener);
    await done.future.timeout(const Duration(seconds: 1), onTimeout: () {});
  }

  /// The mark itself, at the size the launch screens draw it on this screen.
  static Widget image(BuildContext context, {String? semanticLabel}) {
    final size = sizeFor(MediaQuery.sizeOf(context).shortestSide);
    return Image.asset(
      Art.logoMark,
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
    );
  }
}
