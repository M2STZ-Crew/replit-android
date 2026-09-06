import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'register_screen.dart';
import 'role_gate.dart';

/// "Welcome back" — the sign-in screen from the hand-off.
///
/// The design signs in with a mobile number. Authentication here is email +
/// password and there is no phone-login endpoint, so the field stays email.
/// Everything else is the design, including the line that matters most at 2am:
/// hotlines work while you are locked out.
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
  bool _keepActive = true;
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
      if (_keepActive) await Session.instance.persist();
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
              style: _fieldStyle,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Image.asset(Art.mark, width: 44, height: 44),
            const SizedBox(height: 52),
            const Text('WELCOME BACK', style: AppText.display),
            const SizedBox(height: 10),
            const SizedBox(
              width: 300,
              child: Text(
                'Sign in so responders know who is reporting and where to find '
                'you.',
                style: AppText.body,
              ),
            ),
            const SizedBox(height: 38),

            const Eyebrow('Email', color: AppColors.accent),
            const SizedBox(height: 9),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              style: _fieldStyle,
              decoration: const InputDecoration(hintText: 'you@email.com'),
            ),

            const SizedBox(height: 18),
            const Eyebrow('Password'),
            const SizedBox(height: 9),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              style: _fieldStyle,
              decoration: InputDecoration(
                hintText: 'Your password',
                suffixIcon: IconButton(
                  iconSize: 18,
                  color: AppColors.muted,
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),

            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () => setState(() => _keepActive = !_keepActive),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _keepActive
                                ? AppColors.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _keepActive
                                  ? AppColors.accent
                                  : AppColors.lineStrong,
                              width: 1.5,
                            ),
                          ),
                          child: _keepActive
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: AppColors.accentText,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // Flexible: at a large font scale this label and
                        // "Recovery" together are wider than the row.
                        const Flexible(
                          child: Eyebrow(
                            'Keep session active',
                            color: AppColors.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _recoverDialog,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Eyebrow('Recovery', color: AppColors.accent),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            AppButton(
              'Log in',
              height: 54,
              busy: _loading,
              onPressed: _loading ? null : _submit,
            ),

            const SizedBox(height: 26),
            Panel(
              radius: AppRadius.control,
              color: AppColors.glassDim,
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
                      'Locked out? You can still reach 911 and every hotline '
                      'from your phone without signing in.',
                      style: AppText.meta.copyWith(
                        height: 16 / 11,
                        color: AppColors.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            // Wrap, not Row: the two halves of this line together are wider
            // than the screen at a large system font scale, and a sign-up link
            // that has run off the edge is a dead end for a new user.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text(
                  'New to the barangay app?',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'CREATE ACCOUNT',
                      style: AppText.tag.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _fieldStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: AppColors.onBackground,
);
