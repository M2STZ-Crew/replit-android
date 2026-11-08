import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's sounds: the alert recordings (v1.12.9: the recordings chosen for
/// the pilot), for a push that arrives while the app is open. The push names
/// its sound in `sound_category` — fire, police, medical, barangay, citizen,
/// or a stage of an incident the resident reported: verified, on_route,
/// on_scene, fire_out, rejected (v1.12.33; it played the general one). With
/// the app closed the phone plays the same recording
/// itself, from that sound's notification channel
/// (android/.../res/raw/`sound_<category>.mp3` — keep them the same as
/// assets/sounds/; test/sound_files_test.dart checks).
///
/// v1.12.23: sending a report plays nothing. Reported is the one stage with no
/// sound — the first a resident hears is when the incident is verified — and
/// the cue that played on sending (v10 §2.8's "salamat!", by then a recording
/// in the same voice as the stages) went, with its two switches.
class SoundCues {
  SoundCues._();

  static final SoundCues instance = SoundCues._();

  static const String _fireKey = 'sound.fire_alarm';
  static const String _fireVolumeKey = 'sound.fire_alarm_volume';
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
    'rejected',
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

  AudioPlayer? _firePlayer;

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
