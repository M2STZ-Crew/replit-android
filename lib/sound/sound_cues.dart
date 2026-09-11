import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The citizen app's one sound (Master Context v10 §2.8): a short "salamat!"
/// cue when a report submits successfully. The mobile app is otherwise silent
/// on inbound — alerts arrive as pushes with the phone's own tone.
///
/// The final audio is not chosen. `assets/sounds/report_sent.wav` is a
/// synthesized three-note placeholder (sa · la · mat); replace that file when
/// the recording exists — nothing else needs to change.
///
/// Residents can turn it off in Notification settings.
class SoundCues {
  SoundCues._();

  static final SoundCues instance = SoundCues._();

  static const String _prefKey = 'sound.report_sent';
  static const String _asset = 'sounds/report_sent.wav';

  AudioPlayer? _player;

  Future<bool> reportSentEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true;
  }

  Future<void> setReportSentEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Play the "report sent" cue, unless the resident turned it off. Never
  /// throws: a sound that fails to play must not look like a failed report.
  Future<void> playReportSent() async {
    try {
      if (!await reportSentEnabled()) return;
      final player = _player ??= AudioPlayer(playerId: 'report_sent');
      await player.stop();
      await player.play(AssetSource(_asset), mode: PlayerMode.lowLatency);
    } catch (_) {
      // Muted device, no audio focus, missing codec — the report still went.
    }
  }
}
