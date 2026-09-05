import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/design.dart';
import '../providers/auth_provider.dart';

/// "Who are you?" — sign-up, from the hand-off.
///
/// The design puts a mobile number with an inline one-time code on this screen.
/// Sign-up on the server is email + password only; phone becomes a separate
/// +40% verification step once you are in, on the Verification screen. Showing
/// an OTP box that no endpoint answers would strand people on their first
/// screen, so the number is asked for later, where it actually works.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _consent = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      context.showSnackBar(
        'Please agree to share your location during an emergency.',
        isError: true,
      );
      return;
    }
    ref.read(authProvider.notifier).signUp(
      email: _email.text.trim(),
      password: _password.text,
      fullName: Validators.sanitize(_name.text),
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
      if (next.isAuthenticated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Row(
                children: [
                  const BackWell(),
                  const SizedBox(width: 16),
                  ...List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 26,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? AppColors.accent
                              : AppColors.lineStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Eyebrow('Step 1 · account', color: AppColors.muted),
                ],
              ),

              const SizedBox(height: 34),
              const Text('WHO ARE YOU?', style: AppText.display),
              const SizedBox(height: 10),
              const SizedBox(
                width: 310,
                child: Text(
                  'Three details now. Responders see your name the moment you '
                  'send an alert; your number and ID come later and raise how '
                  'fast your reports are trusted.',
                  style: AppText.body,
                ),
              ),

              const SizedBox(height: 30),
              const Eyebrow('Full name'),
              const SizedBox(height: 9),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.fullName,
                style: _fieldStyle,
                decoration: const InputDecoration(hintText: 'Your full name'),
              ),

              const SizedBox(height: 16),
              const Eyebrow('Email', color: AppColors.accent),
              const SizedBox(height: 9),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                style: _fieldStyle,
                decoration: const InputDecoration(hintText: 'you@email.com'),
              ),

              const SizedBox(height: 16),
              const Eyebrow('Password'),
              const SizedBox(height: 9),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                style: _fieldStyle,
                decoration: InputDecoration(
                  hintText: 'At least 8 characters',
                  suffixIcon: _EyeButton(
                    obscured: _obscure,
                    onTap: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Eyebrow('Confirm password'),
              const SizedBox(height: 9),
              TextFormField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => v != _password.text
                    ? 'Passwords do not match'
                    : null,
                style: _fieldStyle,
                decoration: InputDecoration(
                  hintText: 'Type it again',
                  suffixIcon: _EyeButton(
                    obscured: _obscureConfirm,
                    onTap: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),

              const SizedBox(height: 26),
              GestureDetector(
                onTap: () => setState(() => _consent = !_consent),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: _consent
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _consent
                              ? AppColors.accent
                              : AppColors.lineStrong,
                          width: 1.5,
                        ),
                      ),
                      child: _consent
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: AppColors.onAccent)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'I agree that my location and reports may be shared '
                        'with my barangay and the responding agencies during '
                        'an emergency.',
                        style: AppText.meta.copyWith(
                          height: 16 / 11,
                          color: AppColors.label,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              AppButton(
                'Create account',
                height: 54,
                busy: auth.isLoading,
                onPressed: auth.isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _fieldStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    iconSize: 18,
    color: AppColors.muted,
    onPressed: onTap,
    icon: Icon(
      obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
    ),
  );
}
