import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'role_gate.dart';

/// "03 Sign up" from the REPLIT-OVERHAUL Figma: three fields and you are in.
///
/// v2 asked for first and last name, date of birth, gender, mobile and a
/// password twice. The overhaul keeps what `/auth/signup` needs — full name,
/// email, password — and leaves mobile, birthday and gender to Edit Profile,
/// where they always could be set. The password field keeps a show/hide eye
/// the frame does not draw: with the confirm field gone, it is the only way to
/// check what you typed.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiClient _api = ApiClient();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _agree = false;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final email = _email.text.trim();
    final password = _password.text;

    if (name.isEmpty) return _error('Please enter your full name.');
    if (!email.contains('@') || !email.contains('.')) {
      return _error('Please enter a valid email address.');
    }
    if (password.length < 8) {
      return _error('Password must be at least 8 characters.');
    }
    if (!_agree) {
      return _error('Please agree to sharing your location and reports.');
    }

    setState(() => _loading = true);
    try {
      await _api.signup(email: email, password: password, fullName: name);
      await Session.instance.persist();
      unawaited(PushService.instance.syncForUser());
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const RoleGate()));
    } on ApiException catch (e) {
      _error(e.message);
    } catch (_) {
      _error(
        'Could not reach the server. Check the API URL in api_config.dart.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.live),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          content: [
            const Align(alignment: Alignment.centerLeft, child: BackWell()),
            const SizedBox(height: 28),
            const Text('CREATE YOUR ACCOUNT', style: AppText.display),
            const SizedBox(height: 8),
            const Text(
              'Three fields and you are in. Verifying your number and '
              'ID comes later — reports work either way.',
              style: AppText.body,
            ),
            const SizedBox(height: 46),
            LabeledField(
              label: 'Full name',
              builder: (focus) => TextField(
                controller: _name,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                style: AppText.input,
                decoration: const InputDecoration(hintText: 'As on your ID'),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Email address',
              builder: (focus) => TextField(
                controller: _email,
                focusNode: focus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                style: AppText.input,
                decoration: const InputDecoration(hintText: 'you@email.com'),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Password',
              builder: (focus) => TextField(
                controller: _password,
                focusNode: focus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                style: AppText.input,
                decoration: InputDecoration(
                  hintText: 'At least 8 characters',
                  suffixIcon: IconButton(
                    iconSize: 18,
                    color: AppColors.muted,
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            _terms(),
            const SizedBox(height: 40),
            const Eyebrow('Verify later, earn up to 100%'),
            const SizedBox(height: 10),
            // The trust weights the server scores (§2.3), shown so the
            // later steps have a reason. Informational, not buttons —
            // there is nothing to verify until the account exists.
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Weight('+40%', 'Mobile')),
                SizedBox(width: 8),
                Expanded(child: _Weight('+50%', 'National ID')),
                SizedBox(width: 8),
                Expanded(child: _Weight('+10%', 'Email')),
              ],
            ),
          ],
          footer: AppButton(
            'Create account',
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
                color: _agree ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: _agree
                    ? null
                    : Border.all(color: AppColors.lineStrong, width: 1.5),
              ),
              child: _agree
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppColors.accentText,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I agree that my location and reports may be shared with '
                'Barangay 76 and responding agencies during an emergency.',
                style: AppText.caption.copyWith(color: AppColors.label),
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
  const _Weight(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.chip,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppText.cardTitleSm.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: AppText.eyebrow.copyWith(
              letterSpacing: 0.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
