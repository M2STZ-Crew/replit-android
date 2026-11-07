import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../i18n/i18n.dart';
import '../models/verification_state.dart';
import '../theme.dart';
import 'design.dart';

/// Confirming the email with a link (+10%), in a sheet.
///
/// The last step of a resident's sign-up while SMS is unavailable
/// (7 November: "instead of OTP, they will confirm it via email in Gmail"),
/// and Profile > Verify next to the email. At sign-up the link is sent as the
/// sheet opens; from Profile it waits for Send the link ([sendNow]).
///
/// Then it watches for the confirmation: when the app comes back from Gmail,
/// and every few seconds while it is open, so a link opened on a computer
/// counts too. Resolves true once the email is confirmed. Closing it early is
/// allowed: the account exists by then, and Profile asks again.
Future<bool> showEmailLinkSheet(
  BuildContext context, {
  required String? email,
  ApiClient? api,
  bool sendNow = true,
}) async {
  final confirmed = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.pal.surfaceSolid,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (_) => EmailLinkSheet(email: email, api: api, sendNow: sendNow),
  );
  return confirmed == true;
}

/// An address Gmail holds: the sheet says Gmail and opens it.
bool isGmailAddress(String? email) {
  final at = (email ?? '').trim().toLowerCase().split('@');
  return at.length == 2 &&
      const {'gmail.com', 'googlemail.com'}.contains(at[1]);
}

const MethodChannel _device = MethodChannel('replit/device');

/// Opens Gmail ([gmail]) or the phone's email app at the inbox; false when
/// neither opens. Android starts it by intent (MainActivity, "openMailApp"),
/// an iPhone by Gmail's address, then Mail's.
Future<bool> openMailApp({required bool gmail}) async {
  if (kIsWeb) return false;
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final opened = await _device.invokeMethod<bool>('openMailApp', {
          'gmail': gmail,
        });
        return opened ?? false;
      case TargetPlatform.iOS:
        for (final app in [if (gmail) 'googlegmail://', 'message://']) {
          final opened = await launchUrl(
            Uri.parse(app),
            mode: LaunchMode.externalApplication,
          );
          if (opened) return true;
        }
        return false;
      default:
        return false;
    }
  } catch (_) {
    // An older Android side, no email app, or a test.
    return false;
  }
}

class EmailLinkSheet extends StatefulWidget {
  const EmailLinkSheet({
    super.key,
    required this.email,
    this.api,
    this.sendNow = true,
  });

  /// The account's email, as shown; null while it is not known.
  final String? email;
  final ApiClient? api;

  /// Send the link as the sheet opens (sign-up), or wait for Send the link
  /// (Profile).
  final bool sendNow;

  /// How often an open sheet asks whether the link was opened.
  static const checkEvery = Duration(seconds: 5);

  @override
  State<EmailLinkSheet> createState() => _EmailLinkSheetState();
}

enum _Step { ask, sending, sent, confirmed }

class _EmailLinkSheetState extends State<EmailLinkSheet>
    with WidgetsBindingObserver {
  late final ApiClient _api = widget.api ?? ApiClient();
  late _Step _step = widget.sendNow ? _Step.sending : _Step.ask;
  bool _busy = false;
  bool _checking = false;

  /// The day's links are spent: Send again stays off.
  bool _spent = false;
  String? _error;
  int _resendIn = 0;
  Timer? _countdown;
  Timer? _watch;

  bool get _gmail => isGmailAddress(widget.email);

  String get _shown {
    final email = widget.email?.trim() ?? '';
    return email.isEmpty ? t('your email') : email;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.sendNow) _send();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_step != _Step.sent) return;
    if (state == AppLifecycleState.resumed) {
      // Back from Gmail: the link was likely just opened.
      _check();
      _startWatching();
    } else {
      _watch?.cancel();
    }
  }

  void _startWatching() {
    _watch?.cancel();
    _watch = Timer.periodic(EmailLinkSheet.checkEvery, (_) => _check());
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _check() async {
    if (_checking || _step != _Step.sent) return;
    _checking = true;
    try {
      final status = VerificationState.fromJson(
        await _api.getVerificationStatus(),
      );
      if (mounted && status.isVerified(VerifyChannel.email)) _confirmed();
    } catch (_) {
      // Offline for a moment: the next check, or coming back, asks again.
    } finally {
      _checking = false;
    }
  }

  void _confirmed() {
    _watch?.cancel();
    _countdown?.cancel();
    setState(() {
      _step = _Step.confirmed;
      _error = null;
    });
  }

  Future<void> _send() async {
    final sentBefore = _step == _Step.sent;
    setState(() {
      _busy = true;
      _error = null;
      if (_step == _Step.ask) _step = _Step.sending;
    });
    try {
      final r = await _api.requestEmailLink();
      if (!mounted) return;
      if (r['sent'] == false) {
        // Already confirmed: nothing to open.
        _confirmed();
        return;
      }
      setState(() => _step = _Step.sent);
      _startCountdown((r['resend_after_seconds'] as num?)?.toInt() ?? 60);
      _startWatching();
    } on ApiException catch (e) {
      if (!mounted) return;
      final wait = (e.details?['retry_after_seconds'] as num?)?.toInt();
      switch (e.code) {
        case 'email_link_cooldown':
          // A link went out a moment ago (at sign-up, say); it still works.
          setState(() => _step = _Step.sent);
          _startCountdown(wait ?? 60);
          _startWatching();
        case 'email_link_daily_limit':
          setState(() {
            _step = _Step.sent;
            _spent = true;
            _error = t(
              'That is all the links we can send today. Use the newest email '
              'we sent, or ask for another tomorrow.',
            );
          });
          _startWatching();
        case 'disposable_email':
          // An account made with a burner address before v1.12.23: it keeps
          // working, but such an inbox earns no trust.
          setState(() {
            _step = sentBefore ? _Step.sent : _Step.ask;
            _error = t(
              "Your email is from a temporary email service, so it can't be "
              'confirmed.',
            );
          });
        default:
          setState(() {
            _step = sentBefore ? _Step.sent : _Step.ask;
            _error = e.message;
          });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = sentBefore ? _Step.sent : _Step.ask;
        _error = t('Could not send the email. Check your connection.');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openInbox() async {
    final opened = await openMailApp(gmail: _gmail);
    if (!opened && mounted) {
      setState(
        () => _error = t(
          'Open your email app and look for the email from RepLiT.',
        ),
      );
    }
  }

  String get _title => switch (_step) {
    _Step.ask => t('CONFIRM YOUR EMAIL'),
    _Step.sending || _Step.sent => t('CHECK YOUR EMAIL'),
    _Step.confirmed => t('EMAIL CONFIRMED'),
  };

  String get _body => switch (_step) {
    _Step.ask => t(
      "We'll email a link to {email}. Opening it confirms the address.",
      {'email': _shown},
    ),
    _Step.sending => t('Sending a link to {email}…', {'email': _shown}),
    _Step.sent when _gmail => t(
      'We sent a link to {email}. Open it in Gmail and tap Verify my email. '
      'It works for 24 hours.',
      {'email': _shown},
    ),
    _Step.sent => t(
      'We sent a link to {email}. Open the email and tap Verify my email. It '
      'works for 24 hours.',
      {'email': _shown},
    ),
    _Step.confirmed => t('{email} is confirmed. Thank you!', {'email': _shown}),
  };

  Widget _button() {
    final open = _gmail ? t('Open Gmail') : t('Open your email');
    return switch (_step) {
      _Step.ask => AppButton(
        t('Send the link'),
        busy: _busy,
        onPressed: _busy ? null : _send,
      ),
      _Step.sending => AppButton(open, busy: true),
      _Step.sent => AppButton(open, onPressed: _openInbox),
      _Step.confirmed => AppButton(
        t('Continue'),
        onPressed: () => Navigator.of(context).pop(true),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canResend = !_busy && !_spent && _resendIn <= 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SheetHandle()),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(_title, style: context.type.screenTitle)),
              const SizedBox(width: 12),
              Text(
                '+10%',
                style: context.type.cardTitleSm.copyWith(
                  color: _step == _Step.confirmed
                      ? context.pal.ok
                      : context.pal.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_body, style: context.type.body),
          if (_step == _Step.sent) ...[
            const SizedBox(height: 8),
            Text(
              t('Not in your inbox? Look in Spam or Promotions.'),
              style: context.type.caption,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: context.pal.live, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          _button(),
          if (_step != _Step.confirmed) ...[
            const SizedBox(height: 6),
            // A Wrap, not a Row: at a large font the two do not fit side by
            // side, and "Later" drops under "Send again" instead of off-screen.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_step == _Step.sent)
                  TextButton(
                    onPressed: canResend ? _send : null,
                    child: Text(
                      _resendIn > 0
                          ? t('Send again in {s} s', {'s': _resendIn})
                          : t('Send the link again'),
                      style: TextStyle(
                        color: canResend
                            ? context.pal.accent
                            : context.pal.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    t('Later'),
                    style: TextStyle(color: context.pal.muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
