// v1.12.53: a fire is called by its street, and a far fire has its own voice.
//
// 18 Nov 2026: "instead of area, it will be called 'Near [street]' or the
// street itself ... '[street] corner [street]' or 'near [street]'" (answered
// "Corner, else Near"; the Area number "Nowhere on screen"), and "create a
// placeholder for voice for far incidents (outside 100m). and remain the
// sound of near incident".
import 'package:flutter_test/flutter_test.dart';
import 'package:replit/alerts/inbox_watcher.dart';
import 'package:replit/i18n/fire_names.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/models/alarm.dart';
import 'package:replit/models/area_view.dart';
import 'package:replit/sound/sound_cues.dart';

const near = 'Near F. Victor Street';
const corner = 'Taft Avenue corner Gil Puyat Avenue';

void main() {
  tearDown(LanguageChoice.reset);

  group('a fire by its street', () {
    test('the name, as the server sends it, in English', () {
      expect(fireName(near), near);
      expect(fireName(corner), corner);
      expect(fireName('$near (2)'), '$near (2)');
      expect(fireName(null), '');
    });

    test('Tagalog says Malapit sa; a corner reads the same', () {
      LanguageChoice.current.value = AppLanguage.tl;
      expect(fireName(near), 'Malapit sa F. Victor Street');
      expect(fireName('$near (2)'), 'Malapit sa F. Victor Street (2)');
      expect(fireName(corner), corner);
    });

    test('inside a sentence', () {
      expect(fireAt(near), 'the fire near F. Victor Street');
      expect(fireAt(corner), 'the fire at $corner');
      expect(fireAt(null), 'the fire');
      LanguageChoice.current.value = AppLanguage.tl;
      expect(fireAt(near), 'sunog malapit sa F. Victor Street');
      expect(fireAt(corner), 'sunog sa $corner');
      expect(fireAt(''), 'sunog');
    });

    test('a fallback while the fire has no name', () {
      expect(fireNameOr(null, 'Incident'), 'Incident');
      expect(fireNameOr('  ', 'Incident'), 'Incident');
      expect(fireNameOr(near, 'Incident'), near);
    });

    test('the coordinator screens never say the Area number', () {
      expect(AreaView({'id': 'a', 'designation': near}).name, near);
      expect(AreaView({'id': 'a', 'designation': ''}).name, 'Incident');
      LanguageChoice.current.value = AppLanguage.tl;
      expect(
        AreaView({'id': 'a', 'designation': near}).name,
        'Malapit sa F. Victor Street',
      );
      expect(AreaView({'id': 'a'}).name, 'Insidente');
    });

    test('an alarm request names its fire, or "The fire"', () {
      expect(AlarmRequest({'area_designation': corner}).areaName, corner);
      expect(AlarmRequest({}).areaName, 'The fire');
      LanguageChoice.current.value = AppLanguage.tl;
      expect(AlarmRequest({}).areaName, 'Ang sunog');
    });
  });

  group('a far fire has its own voice', () {
    test('both recordings are sounds the app plays', () {
      expect(SoundCues.categories, containsAll(['far_en', 'far_tl']));
      // The 100 m alert keeps the citizen recording.
      expect(SoundCues.categories, contains('citizen'));
    });

    test('the push names the voice for the reader\'s language', () {
      expect(
        InboxWatcher.soundFor({
          'type': 'fire_verified',
          'data': {'sound_category': 'far_tl'},
        }),
        'far_tl',
      );
    });

    test('an inbox row with no sound plays the app language\'s voice', () {
      final row = {'type': 'fire_verified', 'data': <String, dynamic>{}};
      expect(InboxWatcher.soundFor(row), 'far_en');
      LanguageChoice.current.value = AppLanguage.tl;
      expect(InboxWatcher.soundFor(row), 'far_tl');
      // A fire near you is still asked about in the citizen recording.
      expect(InboxWatcher.soundFor({'type': 'fire_alert'}), 'citizen');
    });
  });
}
