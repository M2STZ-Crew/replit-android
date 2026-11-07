import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../models/phone_numbers.dart';
import '../models/ph_mobile.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/email_link_sheet.dart';
import '../widgets/phone_code_sheet.dart';
import 'role_gate.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';

/// "03 Sign up" from the REPLIT-OVERHAUL Figma.
///
/// First name, last name, email, mobile number, password. The names and the
/// email are required; email first (WHAT'S NEXT, 2.2), as it is how everyone
/// signs in while mobile numbers wait for an SMS provider. Until then the
/// mobile number is optional (7 November): a number given is kept as an
/// unchecked contact number, and no code is texted. The email is checked
/// instead: the moment the account exists, a link is emailed to it, to open
/// in Gmail, and a sheet over this form waits for it ([showEmailLinkSheet]);
/// "Later" is allowed, and Profile asks again. With [PhoneNumbers.open]
/// the number is required again, and proving it is theirs is part of signing
/// up: the moment the account exists, a code is texted to it and a sheet over
/// this form takes it back ([showPhoneCodeSheet]); closing the sheet is
/// allowed, and RoleGate asks again. Birthday and gender stay in
/// Edit Profile. The password field keeps a show/hide eye the frame does not
/// draw: with the confirm field gone, it is the only way to check what you
/// typed.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _agree = false;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String tidy(TextEditingController c) =>
        c.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final first = tidy(_first);
    final last = tidy(_last);
    final mobile = _mobile.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (first.isEmpty) return _error(t('Please enter your first name.'));
    if (last.isEmpty) return _error(t('Please enter your last name.'));
    // Required once SMS is settled; until then optional, but a number given
    // has to be one.
    if ((PhoneNumbers.open || mobile.isNotEmpty) &&
        !looksLikePhMobile(mobile)) {
      return _error(t('Enter your mobile number, like 0917 123 4567.'));
    }
    if (!email.contains('@') || !email.contains('.')) {
      return _error(t('Please enter a valid email address.'));
    }
    if (password.length < 8) {
      return _error(t('Password must be at least 8 characters.'));
    }
    if (!_agree) {
      return _error(t('Please agree to sharing your location and reports.'));
    }

    setState(() => _loading = true);
    try {
      await _api.signup(
        email: email,
        password: password,
        fullName: '$first $last',
        mobile: mobile.isEmpty ? null : mobile,
      );
      await Session.instance.persist();
      unawaited(PushService.instance.syncForUser());
      if (!mounted) return;
      setState(() => _loading = false);
      // Verified or not, the account exists now; RoleGate decides what next.
      if (PhoneNumbers.open) {
        await showPhoneCodeSheet(context, phone: mobile, api: _api);
      } else {
        await showEmailLinkSheet(context, email: email, api: _api);
      }
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const RoleGate()));
    } on ApiException catch (e) {
      _error(e.message);
    } catch (_) {
      _error(
        t('Could not reach the server. Check the API URL in api_config.dart.'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.pal.live),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          content: [
            const Align(alignment: Alignment.centerLeft, child: BackWell()),
            const SizedBox(height: 28),
            Text(t('CREATE YOUR ACCOUNT'), style: context.type.display),
            const SizedBox(height: 8),
            Text(
              PhoneNumbers.open
                  ? t(
                      'We will text a code to your mobile number to check it '
                      'is yours. You sign in with it from then on.',
                    )
                  : t(
                      'You sign in with your email. We will email you a link '
                      'to confirm it.',
                    ),
              style: context.type.body,
            ),
            const SizedBox(height: 46),
            LabeledField(
              label: t('First name'),
              builder: (focus) => TextField(
                controller: _first,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                style: context.type.input,
                decoration: InputDecoration(hintText: t('As on your ID')),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: t('Last name'),
              builder: (focus) => TextField(
                controller: _last,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                style: context.type.input,
                decoration: InputDecoration(hintText: t('As on your ID')),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: t('Email address'),
              builder: (focus) => TextField(
                controller: _email,
                focusNode: focus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                style: context.type.input,
                decoration: InputDecoration(hintText: t('you@email.com')),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              // Optional until SMS is settled ([PhoneNumbers]).
              label: PhoneNumbers.open
                  ? t('Mobile number')
                  : t('Mobile number (optional)'),
              builder: (focus) => TextField(
                controller: _mobile,
                focusNode: focus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: const [PhMobileFormatter()],
                style: context.type.input,
                decoration: const InputDecoration(hintText: kPhMobileHint),
              ),
            ),
            if (!PhoneNumbers.open) ...[
              const SizedBox(height: 6),
              Text(
                t('Checking it by SMS is coming soon.'),
                style: context.type.caption,
              ),
            ],
            const SizedBox(height: 14),
            LabeledField(
              label: t('Password'),
              builder: (focus) => TextField(
                controller: _password,
                focusNode: focus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                style: context.type.input,
                decoration: InputDecoration(
                  hintText: t('At least 8 characters'),
                  suffixIcon: IconButton(
                    iconSize: 18,
                    color: context.pal.muted,
                    tooltip: _obscure ? t('Show password') : t('Hide password'),
                    icon: Icon(
                      _obscure ? AppIcons.visibility : AppIcons.visibilityOff,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            _terms(),
            const SizedBox(height: 40),
            Eyebrow(t('Your trust level, up to 100%')),
            const SizedBox(height: 10),
            // The trust weights the server scores (§2.3), shown so the
            // later steps have a reason. Informational, not buttons —
            // there is nothing to verify until the account exists.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Weight('+40%', 'Mobile', soon: !PhoneNumbers.open),
                ),
                SizedBox(width: 8),
                Expanded(child: _Weight('+50%', t('National ID'))),
                SizedBox(width: 8),
                Expanded(child: _Weight('+10%', 'Email')),
              ],
            ),
          ],
          footer: AppButton(
            t('Create account'),
            height: 54,
            busy: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ),
      ),
    );
  }

  Widget _terms() {
    return Semantics(
      checked: _agree,
      child: GestureDetector(
        onTap: () => setState(() => _agree = !_agree),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _agree ? context.pal.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: _agree
                    ? null
                    : Border.all(color: context.pal.lineStrong, width: 1.5),
              ),
              child: _agree
                  ? const Icon(
                      AppIcons.check,
                      size: 13,
                      color: AppColors.accentText,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t(
                  'I agree that my location and reports may be shared with '
                  'responders and their agencies during an emergency.',
                ),
                style: context.type.caption.copyWith(color: context.pal.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One verification weight: "+40%" over "MOBILE".
class _Weight extends StatelessWidget {
  const _Weight(this.value, this.label, {this.soon = false});

  final String value;
  final String label;

  /// Not open yet: drawn faint ([PhoneNumbers]).
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Opacity(opacity: soon ? 0.45 : 1, child: _panel(context));
  }

  Widget _panel(BuildContext context) {
    return Panel(
      radius: AppRadius.chip,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: context.type.cardTitleSm.copyWith(color: context.pal.accent),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: context.type.eyebrow.copyWith(
              letterSpacing: 0.5,
              color: context.pal.muted,
            ),
          ),
        ],
      ),
    );
  }
}
