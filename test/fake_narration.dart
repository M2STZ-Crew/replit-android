import 'dart:async';

import 'package:replit/tutorial/lit_narrator.dart';

/// Lit's voice in a test: records what was asked for, and plays nothing
/// unless told to ([start], [end]), or fails when [fail] is set.
class FakeNarrationPlayer implements NarrationPlayer {
  final List<String> played = [];
  int stops = 0;
  bool fail = false;
  bool disposed = false;
  final StreamController<bool> _playing = StreamController.broadcast();

  /// What is playing now, or null.
  String? current;

  @override
  Future<void> play(String asset) async {
    if (fail) throw StateError('no audio here');
    played.add(asset);
    current = asset;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (current != null) {
      current = null;
      _playing.add(false);
    }
  }

  /// The clip really starts (the platform says it is playing).
  void start() => _playing.add(true);

  /// The clip plays to its end.
  void end() {
    current = null;
    _playing.add(false);
  }

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _playing.close();
  }
}
