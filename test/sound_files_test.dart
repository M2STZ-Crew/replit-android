import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/i18n/i18n.dart';
import 'package:replit/sound/sound_cues.dart';

/// The recordings as files: what an open app plays (assets/sounds, through
/// SoundCues) and what a closed one plays (res/raw, through the channel the
/// push names). The two must hold the same recording for every sound.
void main() {
  const raw = 'android/app/src/main/res/raw';
  const assets = 'assets/sounds';

  List<int> bytes(String path) => File(path).readAsBytesSync();

  test('every sound has one recording, in the app and for the phone', () {
    for (final sound in SoundCues.categories) {
      final inApp = '$assets/sound_$sound.mp3';
      final forPhone = '$raw/sound_$sound.mp3';
      expect(File(inApp).existsSync(), isTrue, reason: inApp);
      expect(File(forPhone).existsSync(), isTrue, reason: forPhone);
      expect(
        listEquals(bytes(inApp), bytes(forPhone)),
        isTrue,
        reason: '$forPhone must be the same file as $inApp',
      );
    }
  });

  test('the update has one recording per language, in the app and for '
      'the phone', () {
    expect(SoundCues.updateSounds.keys.toSet(), AppLanguage.values.toSet());
    for (final name in SoundCues.updateSounds.values) {
      final inApp = '$assets/$name.mp3';
      final forPhone = '$raw/$name.mp3';
      expect(File(inApp).existsSync(), isTrue, reason: inApp);
      expect(
        listEquals(bytes(inApp), bytes(forPhone)),
        isTrue,
        reason: '$forPhone must be the same file as $inApp',
      );
    }
    expect(
      listEquals(
        bytes('$assets/update_en.mp3'),
        bytes('$assets/update_tl.mp3'),
      ),
      isFalse,
      reason: 'English and Tagalog are two recordings',
    );
  });

  test('the stages of an incident are the five the server names', () {
    // app/services/incident_notify.py _REPORTER_SOUNDS: verified, en route,
    // arrived, resolved, rejected. Reported has none.
    expect(
      SoundCues.categories.containsAll({
        'verified',
        'on_route',
        'on_scene',
        'fire_out',
        'rejected',
      }),
      isTrue,
    );
    expect(SoundCues.categories.contains('reported'), isFalse);
  });

  test('res/raw keeps its list: a new file renumbers the channels', () {
    // A channel made before v1.12.23 holds its recording by resource number,
    // and the numbers follow this list alphabetically (MainActivity.kt). A
    // change here moves what those channels play: give them new ids first.
    final names = [
      for (final f in Directory(raw).listSync()) f.uri.pathSegments.last,
    ]..sort();
    expect(names, [
      'keep.xml',
      'sound_barangay.mp3',
      'sound_citizen.mp3',
      'sound_fire.mp3',
      'sound_fire_out.mp3',
      'sound_medical.mp3',
      'sound_on_route.mp3',
      'sound_on_scene.mp3',
      'sound_police.mp3',
      'sound_rejected.mp3',
      'sound_verified.mp3',
      // v1.12.38, after every older file: nothing above moves.
      'update_en.mp3',
      'update_tl.mp3',
    ]);
  });

  test('each stage of an incident has a recording of its own', () {
    // 9 November: "the phase is en route but the sound is on scene". From
    // 28 Oct sound_on_route.mp3 was a copy of sound_on_scene.mp3, which an
    // exception here let through. The En route recording replaced it, Rejected
    // got its own, and no two stages may share a file again.
    const stages = ['verified', 'on_route', 'on_scene', 'fire_out', 'rejected'];
    final copies = <String>[];
    for (var i = 0; i < stages.length; i++) {
      for (var j = i + 1; j < stages.length; j++) {
        final a = stages[i], b = stages[j];
        if (!listEquals(
          bytes('$assets/sound_$a.mp3'),
          bytes('$assets/sound_$b.mp3'),
        )) {
          continue;
        }
        copies.add('sound_$a.mp3 = sound_$b.mp3');
      }
    }
    expect(copies, isEmpty, reason: 'two stages would sound the same');
  });
}
