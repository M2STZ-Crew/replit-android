import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../i18n/i18n.dart';
import '../store_build.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/coordinator_kit.dart';
import '../widgets/design.dart';
import 'login_screen.dart';

/// Profile > Delete my account (v1.12.44, Google Play's rule): what goes and
/// what stays, the password, then the account is gone (POST /auth/me/delete)
/// and this phone forgets it. The console's /delete-account page does the same
/// without the app.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, this.api});

  final ApiClient? api;

  static Future<void> open(BuildContext context, {ApiClient? api}) =>
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DeleteAccountScreen(api: api)));

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final TextEditingController _password = TextEditingController();
  bool _show = false;
  bool _sure = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = t('Enter your password.'));
      return;
    }
    if (!_sure) {
      setState(
        () => _error = t(
          'Tick the box to confirm. Deleting an account cannot be undone.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await _api.deleteAccount(password: _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'wrong_password' => t('The password is not right.'),
          'staff_account' => t(
            "This is a staff account. Your organization's administrator "
            'removes it.',
          ),
          _ => e.message,
        };
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = t(
          'No internet connection. Turn on mobile data or Wi-Fi, then try '
          'again.',
        );
      });
      return;
    }
    // The account is gone: this phone forgets it.
    try {
      await PushService.instance.unregister();
    } catch (_) {
      // Its registration went with the account.
    }
    await Session.instance.clear();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          notice: t(
            'Your account is deleted. The reports you sent stay in the '
            "barangay's incident records without your name.",
          ),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: pal.muted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: context.type.body)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(t('Delete my account'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              t('Deleting your account cannot be undone.'),
              style: context.type.cardTitle,
            ),
            const SizedBox(height: 16),
            SectionHeader(t('What is deleted')),
            const SizedBox(height: 10),
            point(
              t(
                'Your sign-in and profile: name, email, mobile number, '
                'birthday, gender, language and last location.',
              ),
            ),
            point(
              t("This phone's alert registration, your alerts and answers."),
            ),
            point(
              t(
                'Your verification records, and any National ID photos still '
                'held.',
              ),
            ),
            const SizedBox(height: 12),
            SectionHeader(t('What is kept')),
            const SizedBox(height: 10),
            point(
              t(
                'The reports you sent, without your name: they are part of the '
                'incident records responders and the barangay keep.',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _password,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : unawaited(_delete()),
              decoration: InputDecoration(
                labelText: t('Your password'),
                suffixIcon: IconButton(
                  tooltip: _show ? t('Hide password') : t('Show password'),
                  icon: Icon(
                    _show ? AppIcons.visibilityOff : AppIcons.visibility,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _sure,
              onChanged: (v) => setState(() => _sure = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                t(
                  'I understand that my account is deleted for good and cannot '
                  'be brought back.',
                ),
                style: context.type.body,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const ValueKey('delete-account-error'),
                style: context.type.body.copyWith(color: pal.live),
              ),
            ],
            const SizedBox(height: 18),
            AppButton.danger(
              t('Delete my account'),
              key: const ValueKey('delete-account-button'),
              icon: AppIcons.delete,
              busy: _busy,
              onPressed: _busy ? null : () => unawaited(_delete()),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextLink(
                t('Read the privacy policy'),
                onTap: () => unawaited(PolicyLinks.openPrivacy()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
