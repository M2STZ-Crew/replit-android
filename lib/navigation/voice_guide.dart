import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speaks navigation instructions (PRD v12 §4.9.3) with the phone's own
/// text-to-speech: free, offline, nothing to download.
///
/// On Android it asks for navigation-guidance audio, so music or a call
/// ducks under it rather than stopping, and the fire alarm and notification
/// sounds keep their own streams. A new instruction cuts off the last one: a
/// stale "in 300 metres" is worse than silence. Whether to speak is the
/// person's choice, remembered ([enabled]); it never throws — a voice that
/// fails must not stop the directions.
class VoiceGuide {
  VoiceGuide({FlutterTts? tts}) : _tts = tts;

  static const String _prefKey = 'nav.voice';

  FlutterTts? _tts;
  bool _ready = false;

  /// Speaking, or muted.
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}
  }

  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    if (!on) await stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, on);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (!enabled.value || text.isEmpty) return;
    try {
      final tts = _tts ??= FlutterTts();
      if (!_ready) {
        _ready = true;
        if (defaultTargetPlatform == TargetPlatform.android) {
          await tts.setAudioAttributesForNavigation();
        }
        await tts.setLanguage('en-US');
        await tts.setSpeechRate(0.5);
      }
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      // No speech engine, or none for English: the banner still shows it.
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
