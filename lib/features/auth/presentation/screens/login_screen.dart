import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/design.dart';
import '../providers/auth_provider.dart';

/// "Welcome back" — the sign-in screen from the hand-off.
///
/// The design signs in with a mobile number. Authentication here is Supabase
/// email + password, and there is no phone-login path on the server, so the
/// field is email. Everything else is the design: the mark, the coral focus
/// ring, and the line that matters most at 2am — hotlines work while you are
/// locked out.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).signIn(
      email: _email.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    ref.listen<AuthState2>(authProvider, (prev, next) {
      if (next.errorMessage != null) {
        context.showSnackBar(next.errorMessage!, isError: true);
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Image.asset(Art.mark, width: 44, height: 44),
              const SizedBox(height: 56),
              const Text('WELCOME BACK', style: AppText.display),
              const SizedBox(height: 10),
              const SizedBox(
                width: 300,
                child: Text(
                  'Sign in so responders know who is reporting and where to '
                  'find you.',
                  style: AppText.body,
                ),
              ),
              const SizedBox(height: 40),

              const Eyebrow('Email', color: AppColors.accent),
              const SizedBox(height: 9),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
                decoration: const InputDecoration(hintText: 'you@email.com'),
              ),

              const SizedBox(height: 18),
              const Eyebrow('Password'),
              const SizedBox(height: 9),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
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

              const SizedBox(height: 32),
              AppButton(
                'Log in',
                height: 54,
                busy: auth.isLoading,
                onPressed: auth.isLoading ? null : _submit,
              ),

              const SizedBox(height: 26),
              Panel(
                radius: AppRadius.control,
                color: AppColors.surfaceDim,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 18, color: AppColors.accent),
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

              const SizedBox(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'New to the barangay app?',
                    style: TextStyle(fontSize: 12, color: AppColors.faint),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
