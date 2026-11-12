import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../widgets/motion.dart';
import 'lit_lessons.dart';

/// The talking loop's frames and when each shows (assets/tutorial/lit/
/// timing.json, the supplied timing with the copies' names): a general
/// speaking loop of 3.57 s with one blink, not lip sync.
class LitTiming {
  const LitTiming({
    required this.duration,
    required this.frames,
    required this.idle,
  });

  final Duration duration;

  /// (frame asset, starts at) in order.
  final List<(String, Duration)> frames;
  final String idle;

  static const String _dir = 'assets/tutorial/lit';
  static LitTiming? _loaded;

  /// Read once; null when it cannot be (Lit then stays still).
  static Future<LitTiming?> load([AssetBundle? bundle]) async {
    if (_loaded != null) return _loaded;
    try {
      final json =
          jsonDecode(
                await (bundle ?? rootBundle).loadString('$_dir/timing.json'),
              )
              as Map<String, dynamic>;
      return _loaded = LitTiming(
        duration: Duration(milliseconds: json['duration_ms'] as int),
        idle: '$_dir/${json['idle_frame']}',
        frames: [
          for (final step in json['sequence'] as List)
            (
              '$_dir/${step['file']}',
              Duration(milliseconds: step['start_ms'] as int),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  /// The frame showing [elapsed] into the loop.
  String frameAt(Duration elapsed) {
    final at = elapsed.inMicroseconds % duration.inMicroseconds;
    var frame = frames.first.$1;
    for (final (file, start) in frames) {
      if (start.inMicroseconds > at) break;
      frame = file;
    }
    return frame;
  }

  Iterable<String> get files => {idle, for (final (f, _) in frames) f};
}

/// Lit: talking while [talking] (his voice really playing), else still in
/// [pose]. Both draw in the same square, so his size and the line his feet
/// stand on never move when one gives way to the other. With reduced motion
/// he stays still and the words carry on.
class LitCharacter extends StatefulWidget {
  const LitCharacter({
    super.key,
    required this.pose,
    required this.talking,
    this.size = 128,
  });

  final LitPose pose;
  final bool talking;
  final double size;

  @override
  State<LitCharacter> createState() => _LitCharacterState();
}

class _LitCharacterState extends State<LitCharacter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  LitTiming? _timing;
  Duration _elapsed = Duration.zero;
  String? _frame;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    LitTiming.load().then((timing) {
      if (!mounted) return;
      setState(() => _timing = timing);
      _sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Every picture ready before it is needed: no blank frame between a
    // pose and the loop.
    for (final pose in LitPose.values) {
      precacheImage(AssetImage(pose.asset), context).ignore();
    }
    LitTiming.load().then((timing) {
      if (!mounted || timing == null) return;
      for (final file in timing.files) {
        precacheImage(AssetImage(file), context).ignore();
      }
    });
  }

  @override
  void didUpdateWidget(LitCharacter old) {
    super.didUpdateWidget(old);
    _sync();
  }

  bool get _moving =>
      widget.talking && _timing != null && !Motion.of(context).reduced;

  void _sync() {
    if (!mounted) return;
    if (_moving && !_ticker.isActive) {
      _elapsed = Duration.zero;
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
      _frame = null;
    }
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    final frame = _timing!.frameAt(elapsed);
    if (frame != _frame) setState(() => _frame = frame);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final talking = _moving && _ticker.isActive;
    final asset = talking
        ? (_frame ?? _timing!.frameAt(_elapsed))
        : widget.pose.asset;
    return SizedBox.square(
      dimension: widget.size,
      child: Image.asset(
        asset,
        key: ValueKey(talking ? 'lit-talking' : 'lit-${widget.pose.name}'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}
