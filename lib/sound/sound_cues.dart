import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's sounds.
///
/// - A short "salamat!" cue when a report submits successfully (Master Context
///   v10 §2.8). `assets/sounds/report_sent.wav` is a synthesized three-note
///   placeholder (sa · la · mat); replace that file when the recording
///   exists. Residents can turn it off in Notification settings.
/// - The fire alarm (v1.12.6), for a push saying there is a fire that arrives
///   while the app is open. With the app closed the phone plays the same
///   sound itself, from the "Fire alerts" notification channel
///   (android/.../res/raw/fire_alarm.wav — keep the two files the same).
class SoundCues {
  SoundCues._();

  static final SoundCues instance = SoundCues._();

  static const String _prefKey = 'sound.report_sent';
  static const String _asset = 'sounds/report_sent.wav';
  static const String _fireAsset = 'sounds/fire_alarm.wav';

  /// Played as a notification, not as media: it follows the phone's
  /// notification volume and stays quiet when the phone is on silent, as the
  /// closed-app notification does.
  static final AudioContext _asNotification = AudioContext(
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationEvent,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  AudioPlayer? _player;
  AudioPlayer? _firePlayer;

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

  /// Ring the fire alarm. Never throws: a sound that fails to play must not
  /// stop the alert from showing.
  Future<void> playFireAlarm() async {
    try {
      final player = _firePlayer ??= AudioPlayer(playerId: 'fire_alarm');
      await player.stop();
      await player.play(AssetSource(_fireAsset), ctx: _asNotification);
    } catch (_) {
      // No audio focus, missing codec — the banner still shows.
    }
  }
}
