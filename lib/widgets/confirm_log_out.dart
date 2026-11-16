import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../theme.dart';
import 'motion.dart';

/// Asks before logging out (v1.12.47, 17 November 2026: "if the user press
/// logout it make it having a confirmation"). True when they choose Log out.
///
/// Every Log out button asks: a resident's Profile, a responder's and a
/// coordinator's, the staff menu, and the phone-number step. A phone that is
/// logged out gets no fire alerts, so the dialog says so. Being signed out by
/// the app (another phone, a frozen account) does not ask.
Future<bool> confirmLogOut(BuildContext context) async {
  final go = await showAppDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t('Log out?')),
      content: Text(
        t(
          'This phone gets no fire alerts until you sign in again with your '
          'email or mobile number and your password.',
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('log-out-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('Cancel')),
        ),
        TextButton(
          key: const ValueKey('log-out-confirm'),
          style: TextButton.styleFrom(foregroundColor: context.pal.live),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t('Log out')),
        ),
      ],
    ),
  );
  return go == true;
}
