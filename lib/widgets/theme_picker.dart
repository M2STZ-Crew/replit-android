import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../theme.dart';
import '../theme_choice.dart';
import 'app_icons.dart';
import 'coordinator_kit.dart';
import 'field_ops.dart';

/// Settings' Theme row: what is picked, and the picker under it (Figma 14T,
/// "SETTINGS · THEME PICKER (overlay)"), with System added on 12 November
/// 2026 ("add 'System' to dark/light mode, detecting the phone's mode"). The
/// same row on every role's Profile.
class ThemeRow extends StatelessWidget {
  const ThemeRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePick>(
      valueListenable: ThemeChoice.pick,
      builder: (context, pick, _) => ListRow(
        leading: const IconPlate(AppIcons.visibility),
        title: t('Theme'),
        subtitle: pick == ThemePick.system
            ? t('Follows your phone, light or dark')
            : t('Light or dark screens'),
        trailing: RowValue(t(pick.label)),
        chevron: true,
        onTap: () => showThemePicker(context),
      ),
    );
  }
}

/// Opens the picker; the choice applies as it is tapped.
Future<void> showThemePicker(BuildContext context) =>
    showFrameSheet<void>(context, builder: (_) => const ThemeSheet());

class ThemeSheet extends StatelessWidget {
  const ThemeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePick>(
      valueListenable: ThemeChoice.pick,
      builder: (context, picked, _) => SheetFrame(
        children: [
          Semantics(
            header: true,
            child: Text(t('THEME'), style: context.type.heading2),
          ),
          const SizedBox(height: 8),
          Text(
            t('Light or dark screens. The map keeps its own style.'),
            style: context.type.body,
          ),
          const SizedBox(height: 16),
          for (final pick in ThemePick.values) ...[
            if (pick != ThemePick.values.first) const SizedBox(height: 8),
            ChoiceRow(
              title: t(pick.label),
              meta: pick == ThemePick.system
                  ? t('Follows your phone, light or dark')
                  : null,
              selected: pick == picked,
              onTap: () async {
                await ThemeChoice.choose(pick);
                if (context.mounted) Navigator.of(context).maybePop();
              },
            ),
          ],
        ],
      ),
    );
  }
}
