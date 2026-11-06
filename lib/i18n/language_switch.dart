import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'i18n.dart';

/// "English | Tagalog": the resident's language, in onboarding and on
/// Profile. Each option is written in its own language, so someone who reads
/// only one of them can always find it.
///
/// Changing it repaints every screen at once (LanguageScope) and tells the
/// server, so alerts from then on come in the same language.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, this.api});

  final ApiClient? api;

  /// Choose [language] here and on the server. The server half is
  /// best-effort: signed out, or offline, the phone's choice still stands and
  /// is sent again with the next sign-in (PushService.syncForUser).
  static Future<void> choose(AppLanguage language, {ApiClient? api}) async {
    await LanguageChoice.set(language);
    // Saved to the account below; until then this phone's choice stands.
    await LanguageChoice.markUnsaved(true);
    if (!Session.instance.isAuthenticated) return;
    try {
      await (api ?? ApiClient()).setLanguage(language.code);
      await LanguageChoice.markUnsaved(false);
    } catch (_) {
      // Sent again later.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageChoice.current,
      builder: (context, chosen, _) => Semantics(
        label: t('Language'),
        container: true,
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.pal.glass,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: context.pal.line),
          ),
          child: Row(
            children: [
              for (final language in AppLanguage.values)
                Expanded(
                  child: _Segment(
                    label: language.label,
                    selected: language == chosen,
                    onTap: () => unawaited(choose(language, api: api)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.of(context).state,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? pal.accent.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(AppRadius.control - 3),
            border: selected ? Border.all(color: pal.accent, width: 1.5) : null,
          ),
          child: Text(
            label,
            style: context.type.label.copyWith(
              color: selected ? pal.onBackground : pal.textSoft,
            ),
          ),
        ),
      ),
    );
  }
}
