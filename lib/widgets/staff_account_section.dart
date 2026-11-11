import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../i18n/i18n.dart';
import '../i18n/language_switch.dart';
import '../screens/change_password_screen.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'coordinator_kit.dart';
import 'design.dart';
import 'theme_picker.dart';

/// The account rows of a staff Profile, the same for coordinators and
/// responders: the language the app and their alerts come in, light mode, the
/// password, and — for a sign-in at @replit.com, which has no mailbox — the
/// personal email their password links go to. Residents have the first three
/// on their own Profile (WHAT'S NEXT, 1.2 and 1.3, and the 6 November list).
class StaffAccountSection extends StatefulWidget {
  const StaffAccountSection({super.key, required this.api, this.me});

  final ApiClient api;

  /// GET /auth/me: the sign-in, and the personal email if there is one.
  final Map<String, dynamic>? me;

  /// A sign-in at the RepLiT domain: an address with no mailbox behind it.
  static bool hasNoMailbox(Map<String, dynamic>? me) =>
      '${me?['email'] ?? ''}'.trim().toLowerCase().endsWith('@replit.com');

  @override
  State<StaffAccountSection> createState() => _StaffAccountSectionState();
}

class _StaffAccountSectionState extends State<StaffAccountSection> {
  late String? _personal = widget.me?['personal_email'] as String?;
  late bool _confirmed = widget.me?['personal_email_verified'] == true;

  Future<void> _editPersonal() async {
    final email = await showAppDialog<String>(
      context: context,
      builder: (_) => _PersonalEmailDialog(initial: _personal),
    );
    if (email == null || !mounted) return;
    try {
      await widget.api.setPersonalEmail(email);
      if (!mounted) return;
      setState(() {
        if (_personal?.toLowerCase() != email.toLowerCase()) _confirmed = false;
        _personal = email;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _confirmed
                ? t('That email is already confirmed.')
                : t('We sent a link to {email}. Open it to confirm.', {
                    'email': email,
                  }),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (e.code) {
            'not_personal' => t(
              'Use your own email: @replit.com addresses have no mailbox.',
            ),
            // In the app's words already (ApiClient).
            'disposable_email' => e.message,
            _ => t('The email could not be saved. Try again.'),
          }),
          backgroundColor: context.pal.live,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('The email could not be saved. Try again.')),
          backgroundColor: context.pal.live,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 8);
    final personal = _personal;
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
        LanguageSwitch(api: widget.api),
        gap,
        // System, Light or Dark (Figma 14T, with System).
        const ThemeRow(),
        gap,
        ListRow(
          leading: const IconPlate(AppIcons.key),
          title: t('Change password'),
          subtitle: t('Signs you out of your other phones'),
          chevron: true,
          onTap: () => ChangePasswordScreen.open(context, api: widget.api),
        ),
        if (StaffAccountSection.hasNoMailbox(widget.me)) ...[
          gap,
          ListRow(
            leading: const IconPlate(AppIcons.mail),
            title: t('Personal email'),
            subtitle: personal == null
                ? t('Add one, so a forgotten password can be reset')
                : _confirmed
                ? t('{email} · confirmed', {'email': personal})
                : t('{email} · open the link we sent', {'email': personal}),
            chevron: true,
            onTap: _editPersonal,
          ),
        ],
      ],
    );
  }
}

/// The personal email, typed: their own, where password links go.
class _PersonalEmailDialog extends StatefulWidget {
  const _PersonalEmailDialog({this.initial});

  final String? initial;

  @override
  State<_PersonalEmailDialog> createState() => _PersonalEmailDialogState();
}

class _PersonalEmailDialogState extends State<_PersonalEmailDialog> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initial ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = t('Enter an email like name@gmail.com.'));
      return;
    }
    if (email.toLowerCase().endsWith('@replit.com')) {
      setState(
        () => _error = t(
          'Use your own email: @replit.com addresses have no mailbox.',
        ),
      );
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('PERSONAL EMAIL'), style: context.type.screenTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(
              'Your sign-in at @replit.com has no mailbox. If you forget your '
              'password, the reset link comes to this email.',
            ),
            style: context.type.body,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onSubmitted: (_) => _send(),
            style: context.type.input,
            decoration: InputDecoration(
              hintText: 'name@gmail.com',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('CANCEL'), style: TextStyle(color: context.pal.muted)),
        ),
        TextButton(
          onPressed: _send,
          child: Text(
            t('SEND LINK'),
            style: TextStyle(
              color: context.pal.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
