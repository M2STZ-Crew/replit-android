import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';

/// Whether the resident's own email and mobile number show in full.
///
/// Like a wallet app's hidden balance: masked until the eye is tapped, so a
/// glance over a shoulder at the Profile tab does not read either one off the
/// screen. The choice is the resident's and stays on this phone, like the
/// theme; nothing about it is sent anywhere.
abstract final class ContactMask {
  static const String _key = 'contact_hidden_v1';

  /// The dots that stand for what is hidden. Always the same number, so the
  /// mask does not give away how long the hidden part is.
  static const String dots = '••••';

  /// True while the email and mobile number are masked. Masked is the default.
  static final ValueNotifier<bool> hidden = ValueNotifier(true);

  /// Read the saved choice. Called once, before the first frame.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hidden.value = prefs.getBool(_key) ?? true;
    } catch (_) {
      // No storage: they stay masked.
    }
  }

  static Future<void> set(bool value) async {
    hidden.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {
      // The change still holds for this session.
    }
  }

  static Future<void> toggle() => set(!hidden.value);

  /// For tests: back to masked, without touching storage.
  @visibleForTesting
  static void reset() => hidden.value = true;

  /// `maria.reyes@gmail.com` → `ma••••@gmail.com`: the first two letters of
  /// the name, the domain in full. Anything without an @ keeps its first two
  /// characters.
  static String email(String raw) {
    final at = raw.indexOf('@');
    final name = at < 0 ? raw : raw.substring(0, at);
    final domain = at < 0 ? '' : raw.substring(at);
    final keep = name.length <= 2
        ? name.characters.take(1)
        : name.characters.take(2);
    return '$keep$dots$domain';
  }

  /// `+639171234567` → `09•• ••• ••67`: the 09 every Philippine mobile number
  /// starts with and its last two digits. A number in another shape keeps its
  /// first two and last two characters.
  static String mobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final String? national = switch (digits) {
      _ when digits.startsWith('63') && digits.length == 12 =>
        '0${digits.substring(2)}',
      _ when digits.startsWith('09') && digits.length == 11 => digits,
      _ when digits.startsWith('9') && digits.length == 10 => '0$digits',
      _ => null,
    };
    if (national != null) {
      return '${national.substring(0, 2)}•• ••• ••${national.substring(9)}';
    }
    final text = raw.trim();
    if (text.length <= 4) return dots;
    return '${text.substring(0, 2)}$dots${text.substring(text.length - 2)}';
  }
}

/// The eye that shows or hides the email and mobile number, as a wallet app's
/// does for a balance. The slashed eye while they are hidden.
class ContactMaskToggle extends StatelessWidget {
  const ContactMaskToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ContactMask.hidden,
      builder: (context, hidden, _) => Semantics(
        // Its own node: the row it sits in reads as one heading otherwise.
        container: true,
        button: true,
        label: hidden ? t('Show email and mobile') : t('Hide email and mobile'),
        excludeSemantics: true,
        child: InkResponse(
          onTap: ContactMask.toggle,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 32,
            child: Icon(
              hidden ? AppIcons.visibilityOff : AppIcons.visibility,
              key: const ValueKey('contact-mask-toggle'),
              size: 18,
              color: context.pal.accent,
            ),
          ),
        ),
      ),
    );
  }
}
