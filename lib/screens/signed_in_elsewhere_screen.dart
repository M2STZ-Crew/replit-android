import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/session.dart';
import '../i18n/i18n.dart';
import '../location/responder_tracker.dart';
import '../security/developer_mode.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../widgets/staff_shell.dart' show StaffAccount;
import 'login_screen.dart';

/// One phone per account (12 November 2026: "single device only policy. if
/// the account is opened in another device it has a warning and a button will
/// lead to exit"). The newest sign-in wins: the server refuses this phone's
/// session with `signed_in_elsewhere` (backend app/services/one_device.py),
/// and every screen gives way to this one.
///
/// Exit forgets the session on this phone — without signing out on the
/// server, which would sign the newer phone out too — and closes the app; an
/// iPhone, which apps may not close, goes to the sign-in screen instead.
class SignedInElsewhereScreen extends StatelessWidget {
  const SignedInElsewhereScreen({super.key});

  Future<void> _exit(BuildContext context) async {
    final nav = Navigator.of(context);
    try {
      await ResponderTracker.instance.stop();
    } catch (_) {
      // Not sharing, or no location service: nothing to stop.
    }
    await Session.instance.clear();
    StaffAccount.current = null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await DeveloperMode.exit();
      return;
    }
    await nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: pal.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: pal.wellFor(pal.warn),
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                    ),
                    child: Icon(
                      AppIcons.smartphone,
                      size: 36,
                      color: pal.glyphOn(pal.warn),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Semantics(
                  header: true,
                  child: Text(
                    t('OPENED ON ANOTHER PHONE'),
                    textAlign: TextAlign.center,
                    style: context.type.heading2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Your RepLiT account was just signed in on another phone. '
                    'One phone can use it at a time, so it has been signed '
                    'out here.',
                  ),
                  textAlign: TextAlign.center,
                  style: context.type.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'If that was not you, sign in again and change your '
                    'password.',
                  ),
                  textAlign: TextAlign.center,
                  style: context.type.body,
                ),
                const Spacer(),
                AppButton(
                  t('Exit').toUpperCase(),
                  run: true,
                  onPressed: () => _exit(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
