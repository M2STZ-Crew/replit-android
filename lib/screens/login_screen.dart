import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'register_screen.dart';
import 'role_gate.dart';

/// "02 Sign in" from the REPLIT-OVERHAUL Figma.
///
/// Email + password, as the backend authenticates. The overhaul dropped v2's
/// "Keep session active" box: a reporter who is signed out at 2am is a
/// reporter who cannot send, so the session is always kept. The line that
/// matters most stays — hotlines work while you are locked out.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.login(email: email, password: password);
      await Session.instance.persist();
      unawaited(PushService.instance.syncForUser());
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const RoleGate()));
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(
        'Could not reach the server. Check the API URL in api_config.dart.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.live),
    );
  }

  Future<void> _recoverDialog() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('RESET PASSWORD', style: AppText.screenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your account email and we'll send a reset link.",
              style: AppText.body,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: AppText.input,
              decoration: const InputDecoration(hintText: 'you@email.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: const Text(
              'SEND LINK',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    if (!email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email address.');
      return;
    }
    try {
      final message = await _api.requestPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      _showError('Could not send the reset email. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // The sign-up line sits at the foot, as in the frame, and the page
        // still scrolls when the keyboard or a large font scale takes the room.
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          content: [
            const SizedBox(height: 120),
            const Text('WELCOME BACK', style: AppText.display),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 306,
                child: Text(
                  'Sign in so responders know who is reporting and '
                  'where to find you.',
                  style: AppText.body,
                ),
              ),
            ),
            const SizedBox(height: 42),
            LabeledField(
              label: 'Email address',
              builder: (focus) => TextField(
                controller: _emailCtrl,
                focusNode: focus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                style: AppText.input,
                decoration: const InputDecoration(hintText: 'you@email.com'),
              ),
            ),
            const SizedBox(height: 15),
            LabeledField(
              label: 'Password',
              builder: (focus) => TextField(
                controller: _passwordCtrl,
                focusNode: focus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                style: AppText.input,
                decoration: InputDecoration(
                  hintText: 'Your password',
                  suffixIcon: IconButton(
                    iconSize: 18,
                    color: AppColors.muted,
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    // The eye offers what a tap does: see it.
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
            const SizedBox(height: 11),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _recoverDialog,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Eyebrow('Forgot password?', color: AppColors.label),
                ),
              ),
            ),
            const SizedBox(height: 22),
            AppButton(
              'Sign in',
              height: 54,
              busy: _loading,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 26),
            Panel(
              radius: AppRadius.card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Locked out? Every hotline still dials without '
                      'signing in.',
                      style: AppText.caption.copyWith(color: AppColors.label),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Wrap, not Row: the two halves of this line together are wider
          // than the screen at a large system font scale, and a sign-up link
          // that has run off the edge is a dead end for a new user.
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text('New to the barangay app?', style: AppText.detail),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'CREATE ACCOUNT',
                    style: AppText.action.copyWith(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
