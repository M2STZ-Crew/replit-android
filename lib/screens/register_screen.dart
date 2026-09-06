import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'role_gate.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiClient _api = ApiClient();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  DateTime? _dob;
  String? _gender;
  bool _agree = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_two(d.month)}/${_two(d.day)}/${d.year}';
  String _isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (first.isEmpty || last.isEmpty) {
      return _error('Please enter your first and last name.');
    }
    if (!email.contains('@') || !email.contains('.')) {
      return _error('Please enter a valid email address.');
    }
    if (password.length < 8) {
      return _error('Password must be at least 8 characters.');
    }
    if (password != _confirm.text) {
      return _error('Passwords do not match.');
    }
    if (!_agree) {
      return _error('Please accept the Terms and Agreements.');
    }

    setState(() => _loading = true);
    try {
      await _api.signup(
        email: email,
        password: password,
        fullName: '$first $last',
        mobile: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        dateOfBirth: _dob == null ? null : _isoDate(_dob!),
        gender: _gender,
      );
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
      SnackBar(content: Text(message), backgroundColor: AppColors.gradientEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  // Flexible so the caption gives way rather than pushing the
                  // step bars off the screen at a large font scale.
                  const Flexible(
                    child: Eyebrow('Step 1 · account', color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('WHO ARE YOU?', style: AppText.display),
              const SizedBox(height: 10),
              const Text(
                'Responders see your name the moment you send an alert. Your '
                'number and ID come later and raise how fast a report is '
                'trusted.',
                style: AppText.body,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: _group(
                      'FIRST NAME',
                      _input(_firstName, 'First Name'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _group('LAST NAME', _input(_lastName, 'Last Name')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _group('DATE OF BIRTH', _dobField())),
                  const SizedBox(width: 16),
                  Expanded(child: _group('GENDER', _genderField())),
                ],
              ),
              const SizedBox(height: 16),
              _group(
                'EMAIL',
                _input(
                  _email,
                  'Enter your email',
                  keyboard: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 16),
              _group(
                'MOBILE NUMBER',
                _input(_mobile, 'Mobile number', keyboard: TextInputType.phone),
              ),
              const SizedBox(height: 16),
              _group(
                'PASSWORD',
                _input(
                  _password,
                  'Password',
                  obscure: _obscure1,
                  suffix: _eye(
                    () => setState(() => _obscure1 = !_obscure1),
                    _obscure1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _group(
                'CONFIRM PASSWORD',
                _input(
                  _confirm,
                  'Confirm Password',
                  obscure: _obscure2,
                  suffix: _eye(
                    () => setState(() => _obscure2 = !_obscure2),
                    _obscure2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _agree,
                      onChanged: (v) => setState(() => _agree = v ?? false),
                      side: const BorderSide(color: AppColors.label, width: 2),
                      activeColor: AppColors.accent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'I agree to the ',
                            style: TextStyle(
                              color: AppColors.label,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          TextSpan(
                            text: 'Terms and Agreements',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' and acknowledge the privacy policy regarding sensitive emergency data.',
                            style: TextStyle(
                              color: AppColors.label,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _signUpButton(),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            color: AppColors.label,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: 'Log in.',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(String label, Widget field) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Eyebrow(label, color: AppColors.label),
      const SizedBox(height: 9),
      field,
    ],
  );

  BoxDecoration _box() => BoxDecoration(
    color: AppColors.inputBg,
    borderRadius: BorderRadius.circular(AppRadius.control),
    border: Border.all(color: AppColors.line),
  );

  Widget _input(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.onBackground,
      ),
      decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
    );
  }

  Widget _eye(VoidCallback onTap, bool obscured) => IconButton(
    icon: Icon(
      obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: AppColors.darkText,
      size: 20,
    ),
    onPressed: onTap,
  );

  Widget _dobField() => GestureDetector(
    onTap: _pickDob,
    child: Container(
      height: 47,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _box(),
      child: Text(
        _dob == null ? 'mm/dd/yyyy' : _fmtDate(_dob!),
        style: TextStyle(
          color: _dob == null ? AppColors.darkText : Colors.white,
          fontSize: 16,
        ),
      ),
    ),
  );

  Widget _genderField() => Container(
    height: 47,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: _box(),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: _gender,
        hint: const Text(
          'Select',
          style: TextStyle(color: AppColors.darkText, fontSize: 16),
        ),
        dropdownColor: AppColors.surface,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        items: const [
          DropdownMenuItem(value: 'Male', child: Text('Male')),
          DropdownMenuItem(value: 'Female', child: Text('Female')),
          DropdownMenuItem(value: 'Other', child: Text('Other')),
          DropdownMenuItem(
            value: 'Prefer not to say',
            child: Text('Prefer not to say'),
          ),
        ],
        onChanged: (v) => setState(() => _gender = v),
      ),
    ),
  );

  Widget _signUpButton() => AppButton(
    'Create account',
    height: 54,
    busy: _loading,
    onPressed: _loading ? null : _submit,
  );
}
