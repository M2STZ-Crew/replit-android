import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';
import 'lit_lessons.dart';

/// How a resident's LIT tutorial ended.
enum LitOutcome { completed, skipped }

/// The LIT tutorial's state, kept on the phone for each Citizen account and
/// versioned, so a new tutorial is offered once to everyone, the old tour's
/// viewers too. The old tour's own flags (tour_seen_v1, map_coach_seen_v1)
/// are left as they were.
abstract final class LitTutorial {
  /// Raise to offer a new version of the tutorial to everyone again.
  static const int version = 1;

  static const String _languageKey = 'lit_tutorial_language';

  static String _key(String account) =>
      'lit_tutorial_v${version}_${account.trim().toLowerCase()}';

  /// How [account]'s tutorial ended, or null if it has not.
  static Future<LitOutcome?> outcome(String account) async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _key(account),
    );
    return LitOutcome.values.where((o) => o.name == saved).firstOrNull;
  }

  /// Offered once: until it is finished or skipped.
  static Future<bool> shouldOffer(String? account) async =>
      account != null &&
      account.trim().isNotEmpty &&
      await outcome(account) == null;

  /// Finished: completed, whatever came before.
  static Future<void> complete(String account) async =>
      (await SharedPreferences.getInstance()).setString(
        _key(account),
        LitOutcome.completed.name,
      );

  /// Skipped or dismissed. A replay skipped after finishing it stays
  /// completed.
  static Future<void> skip(String account) async {
    if (await outcome(account) != null) return;
    await (await SharedPreferences.getInstance()).setString(
      _key(account),
      LitOutcome.skipped.name,
    );
  }

  /// The narration's language: the last one chosen in the tutorial, else the
  /// app's own.
  static Future<LitLanguage> language() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _languageKey,
    );
    return LitLanguage.values.where((l) => l.name == saved).firstOrNull ??
        (LanguageChoice.tagalog ? LitLanguage.tl : LitLanguage.en);
  }

  static Future<void> setLanguage(LitLanguage language) async =>
      (await SharedPreferences.getInstance()).setString(
        _languageKey,
        language.name,
      );
}
