import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/phone_gate.dart';
import '../api/session.dart';
import '../models/ph_mobile.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'login_screen.dart';

Color _safeGreen = AppColors.ok;

/// Phone verification by SMS code, sent through Semaphore. Two steps on one
/// screen: the number (POST /verification/phone/request), then the code
/// (POST /verification/phone/verify).
///
/// Two ways in:
/// - From Verification, as one channel of the trust level (+40%). Back
///   returns there.
/// - As the gate ([gate]): a resident account cannot use RepLiT until its
///   number is verified — the server refuses it everywhere else. There is no
///   Back. There is a way to call 911, because being unverified must never
///   stand between someone and help, and a way to sign out.
///
/// The server owns every rule — code length, expiry, attempts, the wait
/// between texts, the daily limit — and says which one applied. This screen
/// only reads what it was told: the countdown on "Send again" comes from the
/// server's own number, not a guess.
class PhoneVerifyScreen extends StatefulWidget {
  const PhoneVerifyScreen({
    super.key,
    this.gate = false,
    this.initialPhone,
    this.onVerified,
    this.api,
  });

  /// Shown as the gate rather than from Verification.
  final bool gate;

  /// The number the resident gave when they signed up, to start from.
  final String? initialPhone;

  /// Called once the number is verified. Without it the screen pops `true`.
  final VoidCallback? onVerified;
  final ApiClient? api;

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final TextEditingController _phone = TextEditingController(
    text: localPhMobile(widget.initialPhone),
  );
  final TextEditingController _code = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _sentTo;
  String? _error;
  String? _info;

  int _resendIn = 0;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    if (widget.gate) PhoneGate.opened();
  }

  @override
  void dispose() {
    if (widget.gate) PhoneGate.closed();
    _countdown?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (!looksLikePhMobile(_phone.text)) {
      setState(() => _error = 'Enter a mobile number like 0917 123 4567.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final r = await _api.requestPhoneOtp(_phone.text.trim());
      if (!mounted) return;
      if (r['sent'] == false) {
        // Already verified on this account: nothing to send, nothing to wait for.
        _done();
        return;
      }
      _code.clear();
      setState(() {
        _codeSent = true;
        _sentTo = localPhMobile(r['phone'] as String?);
        _info = r['message'] as String?;
      });
      _startCountdown((r['resend_after_seconds'] as num?)?.toInt() ?? 60);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = phoneErrorText(e));
      final wait = (e.details?['retry_after_seconds'] as num?)?.toInt();
      if (e.code == 'phone_code_cooldown' && wait != null) {
        // A code is already on its way: let them type it.
        setState(() {
          _codeSent = true;
          _sentTo ??= localPhMobile(_phone.text);
        });
        _startCountdown(wait);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the code. Check your signal.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from the text message.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.verifyPhoneOtp(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your number is verified.'),
          backgroundColor: _safeGreen,
        ),
      );
      _done();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = phoneErrorText(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check the code. Check your signal.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done() {
    final onVerified = widget.onVerified;
    if (onVerified != null) {
      onVerified();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _call911() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '911'));
    } catch (_) {
      // No dialer (a tablet): the number is on the button.
    }
  }

  Future<void> _signOut() async {
    try {
      await _api.logout();
    } catch (_) {}
    await Session.instance.clear();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.gate,
      child: Scaffold(
        backgroundColor: context.pal.background,
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
                    color: context.pal.accentTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.smartphone,
                    color: context.pal.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verify your number',
                  style: TextStyle(
                    color: context.pal.onBackground,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Enter the code we sent to ${_sentTo ?? 'your phone'}.'
                      : widget.gate
                      ? 'We will send a 6-digit code to your phone by text. '
                            'You need to do this once before you can use RepLiT.'
                      : 'We will send a 6-digit code to your phone by text. '
                            'It adds 40% to your trust level.',
                  style: TextStyle(
                    color: context.pal.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_codeSent) _phoneField() else _codeField(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: context.pal.live, fontSize: 13),
                  ),
                ],
                if (_info != null && _error == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _info!,
                    style: TextStyle(color: _safeGreen, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  _codeSent ? 'Verify code' : 'Send code',
                  busy: _busy,
                  onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _busy || _resendIn > 0 ? null : _sendCode,
                      child: Text(
                        _resendIn > 0
                            ? 'Send again in $_resendIn s'
                            : 'Send the code again',
                        style: TextStyle(
                          color: _resendIn > 0
                              ? context.pal.muted
                              : context.pal.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _codeSent = false;
                              _error = null;
                              _info = null;
                            }),
                      child: Text(
                        'Use a different number',
                        style: TextStyle(color: context.pal.muted),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _privacyNote(),
                if (widget.gate) ..._gateExits(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        if (!widget.gate) ...[const BackWell(), const SizedBox(width: 16)],
        Text('Mobile number'.toUpperCase(), style: context.type.screenTitle),
      ],
    );
  }

  Widget _phoneField() {
    return TextField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      style: _fieldStyle(context),
      inputFormatters: const [PhMobileFormatter()],
      decoration: InputDecoration(
        hintText: kPhMobileHint,
        prefixIcon: Icon(
          Icons.phone_outlined,
          size: 18,
          color: context.pal.muted,
        ),
      ),
    );
  }

  Widget _codeField() {
    return TextField(
      controller: _code,
      keyboardType: TextInputType.number,
      autofocus: true,
      maxLength: 8,
      textAlign: TextAlign.center,
      autofillHints: const [AutofillHints.oneTimeCode],
      style: _fieldStyle(
        context,
      ).copyWith(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 6),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(hintText: '••••••', counterText: ''),
    );
  }

  Widget _privacyNote() {
    return Panel(
      radius: AppRadius.control,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: context.pal.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We use your number to check that you are a real person, and to '
              'contact you about your reports. We never ask for this code by '
              'call or chat. Do not share it.',
              style: context.type.meta.copyWith(
                height: 16 / 11,
                color: context.pal.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Help first, then the way out: nobody is stuck behind this screen.
  List<Widget> _gateExits() => [
    const SizedBox(height: 24),
    Panel(
      radius: AppRadius.card,
      color: context.pal.live.withValues(alpha: 0.10),
      border: context.pal.live.withValues(alpha: 0.4),
      onTap: _call911,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.phone_in_talk_rounded, color: context.pal.live),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Emergency now? Call 911',
              style: context.type.rowTitleLg,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.pal.live),
        ],
      ),
    ),
    const SizedBox(height: 8),
    Center(
      child: TextButton(
        onPressed: _busy ? null : _signOut,
        child: Text('Sign out', style: TextStyle(color: context.pal.muted)),
      ),
    ),
  ];
}

TextStyle _fieldStyle(BuildContext context) => TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: context.pal.onBackground,
);
