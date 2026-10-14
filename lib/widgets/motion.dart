import 'package:flutter/material.dart';

import '../theme.dart';

/// The design's motion (REPLIT (MAIN) 03 · Visual properties · Motion).
///
/// Every duration on screen comes from here, so the one rule that matters —
/// the phone's "remove animations" setting — is honoured in one place. Under
/// reduced motion nothing moves: presses and sheets snap, decorative fades
/// stop, and a state change is at most a 150 ms cross-fade. Spinners and
/// progress rings keep turning, because they report state rather than
/// decorate it.
@immutable
class Motion {
  const Motion._(this.reduced);

  /// Whether the system asked for reduced motion (Android: Settings ›
  /// Accessibility › Remove animations).
  final bool reduced;

  static Motion of(BuildContext context) =>
      Motion._(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// Press feedback: 100 ms, ease-out.
  Duration get press =>
      reduced ? Duration.zero : const Duration(milliseconds: 100);

  /// A state change — a chip, a switch, a status word: 200 ms. Under reduced
  /// motion it stays a cross-fade, shortened to 150 ms.
  Duration get state => Duration(milliseconds: reduced ? 150 : 200);

  /// A decorative fade (a scroll fade appearing, the selected-tab pill):
  /// 150 ms, and none at all under reduced motion.
  Duration get fade =>
      reduced ? Duration.zero : const Duration(milliseconds: 150);

  /// Sheets and dialogs: 280 ms in, 200 ms out — exit faster than enter.
  Duration get sheetIn =>
      reduced ? Duration.zero : const Duration(milliseconds: 280);
  Duration get sheetOut =>
      reduced ? Duration.zero : const Duration(milliseconds: 200);

  /// Standard easing, cubic-bezier(0.2, 0, 0, 1).
  static const Curve standard = Easing.standard;

  /// Entering (sheets in): decelerate. Leaving: accelerate.
  static const Curve enter = Easing.standardDecelerate;
  static const Curve exit = Easing.standardAccelerate;

  /// The sheet and dialog timing as an [AnimationStyle], for
  /// showModalBottomSheet and showDialog.
  AnimationStyle get sheet => AnimationStyle(
    duration: sheetIn,
    reverseDuration: sheetOut,
    curve: enter,
    reverseCurve: exit,
  );
}

/// Shrinks its child a little while a finger is down on it — press feedback
/// you can feel before the tap lands (100 ms, ease-out).
///
/// It listens to raw pointers rather than claiming the gesture, so the
/// button inside still gets its tap and its ripple. Under reduced motion it
/// draws its child unchanged; the pressed overlay still shows.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    if (!widget.enabled || motion.reduced) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: motion.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// [showModalBottomSheet] with the design's sheet timing — 280 ms in,
/// decelerating; 200 ms out, accelerating; a snap under reduced motion —
/// over the scrim (color/surface/scrim, black at 64 %).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  backgroundColor: backgroundColor,
  shape: shape,
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  isDismissible: isDismissible,
  enableDrag: enableDrag,
  useRootNavigator: useRootNavigator,
  constraints: constraints,
  barrierColor: AppColors.scrim,
  sheetAnimationStyle: Motion.of(context).sheet,
);

/// [showDialog] with the same timing and scrim as [showAppSheet].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) => showDialog<T>(
  context: context,
  builder: builder,
  barrierDismissible: barrierDismissible,
  useRootNavigator: useRootNavigator,
  barrierColor: AppColors.scrim,
  animationStyle: Motion.of(context).sheet,
);
