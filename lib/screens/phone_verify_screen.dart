import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';

const Color _safeGreen = AppColors.ok;

/// Phone OTP verification (+40%). Two steps in one screen:
///  1. Enter mobile number (E.164) → POST /verification/phone/request.
///  2. Enter the SMS code → POST /verification/phone/verify.
///
/// Note: the backend's Twilio is a trial account and PH SMS delivery is blocked,
/// so the code may not actually arrive in this build — surfaced to the user.
class PhoneVerifyScreen extends StatefulWidget {
  const PhoneVerifyScreen({super.key});

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _phone = TextEditingController(text: '+63');
  final TextEditingController _code = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _phoneValid => RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(_phone.text.trim());

  Future<void> _sendCode() async {
    if (!_phoneValid) {
      setState(() => _error = 'Enter a valid number in E.164 format, e.g. +639171234567.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final msg = await _api.requestPhoneOtp(_phone.text.trim());
      if (mounted) {
        setState(() {
          _codeSent = true;
          _info = msg;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the code. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from the SMS.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.verifyPhoneOtp(code);
      final pct = (result['verified_percent'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone verified! Trust level is now $pct%.'),
          backgroundColor: _safeGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not verify the code. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.smartphone, color: AppColors.accent, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verify your mobile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Enter the 6-digit code we sent to ${_phone.text.trim()}.'
                    : 'We will send a one-time SMS code to confirm your number (+40%).',
                style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (!_codeSent) _phoneField() else _codeField(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.live, fontSize: 13),
                ),
              ],
              if (_info != null && _error == null) ...[
                const SizedBox(height: 12),
                Text(
                  _info!,
                  style: const TextStyle(color: _safeGreen, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              _primaryButton(),
              if (_codeSent) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text(
                      'Resend code',
                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => setState(() => _codeSent = false),
                    child: const Text(
                      'Change number',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _trialNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const BackWell(),
        const SizedBox(width: 16),
        Text('Mobile Number'.toUpperCase(), style: AppText.screenTitle),
      ],
    );
  }

  Widget _phoneField() {
    return TextField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      style: _fieldStyle,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
      decoration: const InputDecoration(
        hintText: '+63 917 123 4567',
        prefixIcon: Icon(
          Icons.phone_outlined,
          size: 18,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _codeField() {
    return TextField(
      controller: _code,
      keyboardType: TextInputType.number,
      autofocus: true,
      maxLength: 10,
      textAlign: TextAlign.center,
      style: _fieldStyle.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        letterSpacing: 6,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(hintText: '••••••', counterText: ''),
    );
  }

  Widget _primaryButton() {
    return AppButton(
      _codeSent ? 'Verify code' : 'Send code',
      busy: _busy,
      onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
    );
  }

  /// Stated plainly rather than hidden: the SMS gateway is a trial account, so
  /// a Philippine number will not receive the code in this build. Someone
  /// tapping "Send code" and hearing nothing deserves to know why.
  Widget _trialNote() {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.warn.withValues(alpha: 0.08),
      border: AppColors.warn.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.warn,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'SMS runs through a trial gateway, so a Philippine number may not '
              'receive the code in this build. A paid sender is needed before '
              'release.',
              style: AppText.meta.copyWith(
                height: 16 / 11,
                color: AppColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _fieldStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: AppColors.onBackground,
);
