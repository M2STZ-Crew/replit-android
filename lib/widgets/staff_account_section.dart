import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../i18n/i18n.dart';
import '../i18n/language_switch.dart';
import '../screens/change_password_screen.dart';
import '../theme_choice.dart';
import 'app_icons.dart';
import 'coordinator_kit.dart';

/// The account rows of a staff Profile, the same for coordinators and
/// responders: the language the app and their alerts come in, light mode, and
/// the password. Residents have the same three on their own Profile
/// (WHAT'S NEXT, 1.2 and 1.3, and the light/dark switch after it).
class StaffAccountSection extends StatelessWidget {
  const StaffAccountSection({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(t('Account')),
        const SizedBox(height: 12),
        ListRow(
          leading: const IconPlate(AppIcons.campaign),
          title: t('Language'),
          subtitle: t('Your alerts come in the same language'),
        ),
        const SizedBox(height: 8),
        LanguageSwitch(api: api),
        gap,
        ValueListenableBuilder<bool>(
          valueListenable: ThemeChoice.light,
          builder: (context, light, _) => ListRow(
            leading: const IconPlate(AppIcons.visibility),
            title: t('Light mode'),
            subtitle: t('The pale ground, for daylight'),
            trailing: Switch(value: light, onChanged: ThemeChoice.set),
            onTap: () => ThemeChoice.set(!light),
          ),
        ),
        gap,
        ListRow(
          leading: const IconPlate(AppIcons.key),
          title: t('Change password'),
          subtitle: t('Signs you out of your other phones'),
          chevron: true,
          onTap: () => ChangePasswordScreen.open(context, api: api),
        ),
      ],
    );
  }
}
