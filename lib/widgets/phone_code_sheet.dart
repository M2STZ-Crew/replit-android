import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../models/ph_mobile.dart';
import '../theme.dart';
import 'design.dart';

/// The last step of sign-up: text a code to the number just given, and take
/// it back, in a sheet over the form.
///
/// Resolves true once the number is verified. Closing it early is allowed —
/// the account exists by then — and RoleGate shows the full verification
/// screen instead, so nobody gets in unverified while the server requires it.
Future<bool> showPhoneCodeSheet(
  BuildContext context, {
  required String phone,
  ApiClient? api,
}) async {
  final verified = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.pal.surfaceSolid,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (_) => PhoneCodeSheet(phone: phone, api: api),
  );
  return verified == true;
}

class PhoneCodeSheet extends StatefulWidget {
  const PhoneCodeSheet({super.key, required this.phone, this.api});

  /// The number as the resident typed it; the server normalises it.
  final String phone;
  final ApiClient? api;

  @override
  State<PhoneCodeSheet> createState() => _PhoneCodeSheetState();
}

class _PhoneCodeSheetState extends State<PhoneCodeSheet> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final TextEditingController _code = TextEditingController();

  bool _sending = true;
  bool _checking = false;
  String? _error;
  int _resendIn = 0;
  Timer? _countdown;

  String get _shown => localPhMobile(widget.phone).isEmpty
      ? widget.phone
      : localPhMobile(widget.phone);

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _countdown?.cancel();
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

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await _api.requestPhoneOtp(widget.phone);
      if (!mounted) return;
      if (r['sent'] == false) {
        // Already verified on this account: nothing to type.
        Navigator.of(context).pop(true);
        return;
      }
      _startCountdown((r['resend_after_seconds'] as num?)?.toInt() ?? 60);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = phoneErrorText(e));
      final wait = (e.details?['retry_after_seconds'] as num?)?.toInt();
      if (wait != null) _startCountdown(wait);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the code. Check your signal.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from the text message.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await _api.verifyPhoneOtp(code);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = phoneErrorText(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check the code. Check your signal.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _checking;
    return Padding(
      // Above the keyboard, which opens with the code field.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.pal.label.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('ENTER THE CODE', style: context.type.screenTitle),
            const SizedBox(height: 8),
            Text(
              _sending && _resendIn == 0
                  ? 'Sending a code to $_shown…'
                  : 'We sent a 6-digit code to $_shown. It works for 5 minutes.',
              style: context.type.body,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => busy ? null : _verify(),
              style: context.type.input.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                hintText: '••••••',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: context.pal.live, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              'Verify',
              busy: _checking,
              onPressed: busy ? null : _verify,
            ),
            const SizedBox(height: 6),
            // A Wrap, not a Row: at a large font the two do not fit side by
            // side, and "Later" drops under "Send again" instead of off-screen.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: busy || _resendIn > 0 ? null : _send,
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Later',
                    style: TextStyle(color: context.pal.muted),
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
