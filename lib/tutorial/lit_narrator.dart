import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays one recording at a time: the tutorial's only way to make a sound.
abstract class NarrationPlayer {
  /// Starts [asset] (under assets/), whatever was playing stopped first.
  /// Throws when the clip cannot be played.
  Future<void> play(String asset);

  Future<void> stop();

  /// True while a clip is actually playing; false once it ends, is stopped,
  /// or fails.
  Stream<bool> get playing;

  Future<void> dispose();
}

/// [NarrationPlayer] on the phone's speaker, as speech: other sound dips
/// under Lit's voice, and comes back after.
class AudioNarrationPlayer implements NarrationPlayer {
  AudioNarrationPlayer() {
    _states = _player.onPlayerStateChanged.listen(
      (state) => _playing.add(state == PlayerState.playing),
      onError: (Object _) => _playing.add(false),
    );
  }

  final AudioPlayer _player = AudioPlayer(playerId: 'lit-narration');
  final StreamController<bool> _playing = StreamController.broadcast();
  late final StreamSubscription<PlayerState> _states;

  static final AudioContext _asSpeech = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.assistanceAccessibility,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.duckOthers},
    ),
  );

  @override
  Future<void> play(String asset) async {
    await _player.stop();
    await _player.play(AssetSource(asset), ctx: _asSpeech);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Future<void> dispose() async {
    await _states.cancel();
    await _playing.close();
    await _player.dispose();
  }
}

/// The one owner of Lit's voice (§5 of the brief): a new clip, Back, Skip,
/// Finish, Replay, a language change, mute, leaving the tutorial and the app
/// going to the background all stop the clip before anything else plays.
///
/// Every request carries a number; a clip that finishes loading after a
/// newer request is stopped rather than heard, and its events are ignored,
/// so a quick tap through the lessons never restarts an old clip.
///
/// [talking] is true only while a clip is really playing: Lit's mouth moves
/// with it, and stops while a clip loads, after it ends, when muted, and when
/// it fails. A clip that fails leaves the captions and every control as they
/// were.
class LitNarrator {
  LitNarrator(this._player) {
    _events = _player.playing.listen(_onPlaying);
  }

  final NarrationPlayer _player;
  late final StreamSubscription<bool> _events;

  /// Lit's mouth: true only while a clip plays.
  final ValueNotifier<bool> talking = ValueNotifier(false);

  /// The resident turned the voice off: captions and still poses only.
  final ValueNotifier<bool> muted = ValueNotifier(false);

  /// The last clip could not be played (no audio, a missing file).
  final ValueNotifier<bool> failed = ValueNotifier(false);

  int _request = 0;
  String? _clip;
  bool _disposed = false;

  /// The clip asked for last, played or not (muted): what Replay replays.
  String? get clip => _clip;

  /// Say [clip] (null: this lesson has none), stopping whatever was playing.
  Future<void> say(String? clip) async {
    final request = ++_request;
    _clip = clip;
    talking.value = false;
    failed.value = false;
    await _stopPlayer();
    if (clip == null || muted.value || _disposed) return;
    try {
      await _player.play(clip);
      // A newer request (or mute) came while this one loaded.
      if (request != _request || muted.value || _disposed) {
        await _stopPlayer();
      }
    } catch (e) {
      if (request == _request && !_disposed) {
        talking.value = false;
        failed.value = true;
        debugPrint('Lit narration could not play $clip: $e');
      }
    }
  }

  /// Replay: the current clip again, from the start.
  Future<void> replay() => say(_clip);

  /// Stop the clip, keeping it as the one to replay.
  Future<void> stop() async {
    _request++;
    talking.value = false;
    await _stopPlayer();
  }

  /// Mute stops at once; unmuting does not start a clip by itself (Replay
  /// does).
  Future<void> setMuted(bool on) async {
    muted.value = on;
    if (on) await stop();
  }

  void _onPlaying(bool playing) {
    if (_disposed) return;
    // Only the newest request moves Lit's mouth, and never while muted.
    talking.value = playing && !muted.value && _clip != null;
  }

  Future<void> _stopPlayer() async {
    try {
      await _player.stop();
    } catch (_) {
      // Already stopped, or nothing to stop.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _request++;
    talking.value = false;
    await _stopPlayer();
    await _events.cancel();
    await _player.dispose();
    talking.dispose();
    muted.dispose();
    failed.dispose();
  }
}
