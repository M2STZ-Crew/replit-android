import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tagalog.dart';

/// The languages a resident can read RepLiT in.
enum AppLanguage {
  en('en', 'English'),
  tl('tl', 'Tagalog');

  const AppLanguage(this.code, this.label);

  /// What the server stores (users.language) and the phone remembers.
  final String code;

  /// The language's own name, the same in either language.
  final String label;

  static AppLanguage fromCode(String? code) =>
      code == AppLanguage.tl.code ? AppLanguage.tl : AppLanguage.en;
}

/// Which language the resident's screens are in (the 5 November issue list,
/// 1.5): English, or Tagalog at CEFR B1 — the everyday Tagalog of Metro
/// Manila, in short sentences, keeping the English words people use anyway
/// (app, report, location, Settings).
///
/// Chosen in onboarding and on Profile, kept on the phone, and told to the
/// server so the alerts a resident gets are in the same language. Responder,
/// coordinator and BFP screens stay in English: their words are the
/// agencies' working terms.
abstract final class LanguageChoice {
  static const String _key = 'language_v1';
  static const String _unsavedKey = 'language_unsaved_v1';

  /// A choice made on this phone that the account does not have yet: made
  /// signed out, or offline. Sent with the next sign-in
  /// (PushService.syncForUser); until then the phone's choice stands over
  /// the account's.
  static bool unsaved = false;

  static final ValueNotifier<AppLanguage> current = ValueNotifier(
    AppLanguage.en,
  );

  static bool get tagalog => current.value == AppLanguage.tl;

  /// Read the saved choice. Called once, before the first frame.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      current.value = AppLanguage.fromCode(prefs.getString(_key));
      unsaved = prefs.getBool(_unsavedKey) ?? false;
    } catch (_) {
      // English stands.
    }
  }

  static Future<void> set(AppLanguage language) async {
    current.value = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.code);
    } catch (_) {
      // The change still holds for this session.
    }
  }

  /// Whether the account has this phone's choice yet (see [unsaved]).
  static Future<void> markUnsaved(bool value) async {
    unsaved = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_unsavedKey, value);
    } catch (_) {
      // Holds for this session.
    }
  }

  /// The account's language, from GET /auth/me (WHAT'S NEXT, 1.3): the app
  /// follows it, so a choice made in the Admin console or on another phone
  /// reaches this one. Not while this phone has a choice of its own the
  /// account does not have yet.
  static Future<void> adopt(Object? code) async {
    if (unsaved || code is! String || code.isEmpty) return;
    final language = AppLanguage.fromCode(code);
    if (language != current.value) await set(language);
  }

  /// For tests: back to English, without touching storage.
  @visibleForTesting
  static void reset() {
    current.value = AppLanguage.en;
    unsaved = false;
  }
}

/// [en] in the resident's language.
///
/// The English stays where it is used, so the code reads as before; its
/// Tagalog is [kTagalog]'s entry for exactly that English. Anything without
/// one shows in English rather than not at all. `{name}` placeholders are
/// filled from [args] after the lookup, so both languages can put them where
/// their grammar wants: `t('{n} reports', {'n': 3})`.
String t(String en, [Map<String, Object?> args = const {}]) {
  var text = LanguageChoice.tagalog ? (kTagalog[en] ?? en) : en;
  args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
  return text;
}

/// Repaints every screen when the language changes.
///
/// [t] is read while widgets build, not through an inherited widget, so a
/// change marks every element under this one for rebuilding — the open
/// screen, the routes under it and any sheet over it — and they rebuild in
/// the new language where they stand, without losing their place.
class LanguageScope extends StatefulWidget {
  const LanguageScope({super.key, required this.child});

  final Widget child;

  @override
  State<LanguageScope> createState() => _LanguageScopeState();
}

class _LanguageScopeState extends State<LanguageScope> {
  @override
  void initState() {
    super.initState();
    LanguageChoice.current.addListener(_changed);
  }

  @override
  void dispose() {
    LanguageChoice.current.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// How long ago [at] was, the way the resident's screens say it: "just now",
/// "5 min ago", "2 hours ago", "3 days ago" — in their language.
String tAgo(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return t('just now');
  if (d.inMinutes < 60) return t('{n} min ago', {'n': d.inMinutes});
  if (d.inHours < 24) {
    return d.inHours == 1
        ? t('1 hour ago')
        : t('{n} hours ago', {'n': d.inHours});
  }
  return d.inDays == 1 ? t('1 day ago') : t('{n} days ago', {'n': d.inDays});
}
