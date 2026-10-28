import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's sounds.
///
/// - A short "salamat!" cue when a report submits successfully (Master Context
///   v10 §2.8). `assets/sounds/report_sent.wav` is a synthesized three-note
///   placeholder (sa · la · mat); replace that file when the recording
///   exists. Residents can turn it off in Notification settings.
/// - The alert sounds (v1.12.9: the recordings chosen for the pilot), for a
///   push that arrives while the app is open. The push names its sound in
///   `sound_category` — fire, police, medical, barangay, or citizen. With the
///   app closed the phone plays the same recording itself, from that sound's
///   notification channel (android/.../res/raw/`sound_<category>.mp3` — keep
///   them the same as assets/sounds/).
class SoundCues {
  SoundCues._();

  static final SoundCues instance = SoundCues._();

  static const String _prefKey = 'sound.report_sent';
  static const String _fireKey = 'sound.fire_alarm';
  static const String _fireVolumeKey = 'sound.fire_alarm_volume';
  static const String _asset = 'sounds/report_sent.wav';
  static const Set<String> categories = {
     'fire',
      'police',
      'medical',
      'barangay',
      'citizen',
      'verified',
      'on_route',
      'on_scene',
      'fire_out',
  };

  /// The staff member's own agency's sound: fire for Fire Volunteers and BFP.
  static String categoryForAgency(String? agency) => switch (agency) {
    'police' => 'police',
    'medical' => 'medical',
    'barangay' => 'barangay',
    _ => 'fire',
  };

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

  /// Whether alert sounds play in the app (the coordinator's Profile).
  /// With the app closed, the phone's notification channels decide.
  Future<bool> fireAlarmEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fireKey) ?? true;
  }

  Future<void> setFireAlarmEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fireKey, value);
  }

  /// The in-app alarm's volume, 0–1, on top of the phone's notification
  /// volume. Zero mutes only this.
  Future<double> fireAlarmVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(_fireVolumeKey) ?? 1).clamp(0, 1).toDouble();
  }

  Future<void> setFireAlarmVolume(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fireVolumeKey, value.clamp(0, 1).toDouble());
  }

  /// Play one category's recording, unless alert sounds are turned off or at
  /// zero. An unknown category plays nothing. Never throws: a sound that
  /// fails to play must not stop the alert from showing.
  Future<void> playAlert(String? category) async {
    if (!categories.contains(category)) return;
    try {
      if (!await fireAlarmEnabled()) return;
      final volume = await fireAlarmVolume();
      if (volume <= 0) return;
      final player = _firePlayer ??= AudioPlayer(playerId: 'alert');
      await player.stop();
      await player.setVolume(volume);
      await player.play(
        AssetSource('sounds/sound_$category.mp3'),
        ctx: _asNotification,
      );
    } catch (_) {
      // No audio focus, missing codec — the banner still shows.
    }
  }
}
