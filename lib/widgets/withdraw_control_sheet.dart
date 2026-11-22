import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import 'coordinator_kit.dart';
import 'design.dart';

/// Asks before Under control is withdrawn (v1.12.60): true only on Withdraw.
Future<bool> confirmWithdrawUnderControl(
  BuildContext context, {
  required String fire,
}) async {
  final yes = await showFrameSheet<bool>(
    context,
    builder: (sheet) => SheetFrame(
      children: [
        SheetTitles(
          eyebrow: fire,
          title: t('Withdraw Under control?'),
          body: t(
            "Everyone sees the fire's alarm level again, and its crews and coordinators are told without a sound.",
          ),
        ),
        const SizedBox(height: 20),
        AppButton.danger(
          t('Withdraw'),
          onPressed: () => Navigator.of(sheet).pop(true),
        ),
        const SizedBox(height: 10),
        AppButton.secondary(
          t('Cancel'),
          onPressed: () => Navigator.of(sheet).pop(false),
        ),
      ],
    ),
  );
  return yes == true;
}
