import 'dart:async';

import 'package:flutter/material.dart';

import '../api/account_freeze.dart';
import '../api/api_client.dart';
import '../api/sign_in_limits.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../api/web_only.dart';
import '../i18n/i18n.dart';
import '../store_build.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/coordinator_kit.dart';
import '../widgets/design.dart';
import 'login_screen.dart';
import '../widgets/no_emoji.dart';

/// Profile > Delete my account (v1.12.44, Google Play's rule; v1.12.45: frozen
/// for 30 days first). What happens and when, the password, then the account
/// is frozen (POST /auth/me/delete) and this phone signed out. Within the 30
/// days, signing in offers Restore my account; after them it is deleted for
/// good. The residents' site (reportwhatslit-app.vercel.app/delete-account)
/// does the same without the app.
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
    DateTime? goes;
    try {
      goes = await _api.deleteAccount(password: _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          _ when slowDownMessage(e) != null => slowDownMessage(e)!,
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
    // Frozen: this phone forgets the account until it is restored.
    // Bounded, as signing out is (WebOnly.cleanupFor): a background
    // scheduler that never answers must not keep the person here.
    try {
      await PushService.instance.unregister().timeout(WebOnly.cleanupFor);
    } catch (_) {
      // The server stopped this phone's alerts already.
    }
    await Session.instance.clear();
    final day = AccountFreeze.day(goes?.toUtc().toIso8601String());
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          notice: day == null
              ? t(
                  'Your account is frozen and will be deleted in 30 days. To '
                  'keep it, sign in before then and choose Restore my account.',
                )
              : t(
                  'Your account is frozen and will be deleted on {date}. To '
                  'keep it, sign in before then and choose Restore my account.',
                  {'date': day},
                ),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget step(String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 12),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pal.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.rowTitle),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: context.type.body.copyWith(color: pal.textSoft),
                ),
              ],
            ),
          ),
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
              t(
                'Your account is frozen for 30 days first, then deleted for '
                'good. You can restore it any time in those 30 days.',
              ),
              style: context.type.cardTitle,
            ),
            const SizedBox(height: 18),
            SectionHeader(t('What happens')),
            const SizedBox(height: 12),
            step(
              t('Right away'),
              t(
                'You are signed out on every phone, and RepLiT stops sending '
                'you alerts.',
              ),
            ),
            step(
              t('For 30 days'),
              t(
                'Your account is kept, frozen. To keep it, sign in and choose '
                'Restore my account.',
              ),
            ),
            step(
              t('After 30 days'),
              t(
                'Your sign-in and profile (name, email, mobile number, '
                'birthday, gender, language and last location), your alerts '
                'and any National ID photos are deleted for good.',
              ),
            ),
            step(
              t('What stays'),
              t(
                'The reports you sent stay in the barangay\'s incident records, '
                'without your name.',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              inputFormatters: const [NoEmojiFormatter()],
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
                  'I understand that my account is frozen now and deleted for '
                  'good after 30 days unless I restore it.',
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
