import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/email_gate.dart';
import '../api/session.dart';
import '../i18n/i18n.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/confirm_log_out.dart';
import '../widgets/design.dart';
import '../widgets/email_link_sheet.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Confirm your email (v1.12.49, 18 Nov 2026: "an illegitimate email can still
/// sign up, because of the Later button").
///
/// A resident whose email is not confirmed sees only this until the emailed
/// link is opened; the server refuses everything else (403
/// `email_not_verified`). It looks for the confirmation on its own (back from
/// Gmail, and every few seconds), so a link opened on a computer counts too.
/// Nobody is stuck: 911 is a tap away, "Wrong email? Start over" goes back to
/// Sign up (the account made with the wrong address goes by itself a day
/// after sign-up), and Log out goes to Sign in.
class EmailGateScreen extends StatefulWidget {
  const EmailGateScreen({
    super.key,
    required this.email,
    this.api,
    this.onConfirmed,
  });

  final String? email;
  final ApiClient? api;

  /// Confirmed, and Continue tapped.
  final VoidCallback? onConfirmed;

  @override
  State<EmailGateScreen> createState() => _EmailGateScreenState();
}

class _EmailGateScreenState extends State<EmailGateScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  @override
  void initState() {
    super.initState();
    EmailGate.opened();
  }

  @override
  void dispose() {
    EmailGate.closed();
    super.dispose();
  }

  Future<void> _signOutTo(Widget screen) async {
    try {
      await _api.logout();
    } catch (_) {
      // Signed out on this phone regardless.
    }
    await Session.instance.clear();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _logOut() async {
    if (!await confirmLogOut(context) || !mounted) return;
    await _signOutTo(const LoginScreen());
  }

  Future<void> _call911() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '911'));
    } catch (_) {
      // No dialer (a tablet): the number is on the button.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: pal.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: EmailLinkSheet(
                  email: widget.email,
                  api: _api,
                  sendNow: false,
                  handle: false,
                  onContinue: widget.onConfirmed,
                  onStartOver: () => _signOutTo(const RegisterScreen()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Panel(
                      radius: AppRadius.card,
                      color: pal.live.withValues(alpha: 0.10),
                      border: pal.live.withValues(alpha: 0.4),
                      onTap: _call911,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(AppIcons.phoneInTalk, color: pal.live),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t('Emergency now? Call 911'),
                              style: context.type.rowTitleLg,
                            ),
                          ),
                          Icon(AppIcons.chevronRight, color: pal.live),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        key: const ValueKey('email-gate-log-out'),
                        onPressed: _logOut,
                        child: Text(
                          t('Log out'),
                          style: TextStyle(color: pal.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
