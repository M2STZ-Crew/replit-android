import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import 'coordinator_kit.dart';
import 'design.dart';

/// Asks before a fire code is sent; true only when Send was pressed.
///
/// v1.12.59 (22 Nov 2026: "when the firecode is pressed please make a
/// warning interface first because what if it's mistouched?"; answered
/// "Confirm sheet"): every code, every role, in the Fire codes drawer and on
/// the responder's shortcuts. It names the code, the fire and who is
/// alerted. A swipe, Close, Cancel or a tap outside sends nothing.
Future<bool> confirmFireCode(
  BuildContext context, {
  required String number,
  required String name,
  required String fire,
  bool declares = false,
}) async {
  final send = await showFrameSheet<bool>(
    context,
    builder: (_) => CodeConfirmSheet(
      number: number,
      name: name,
      fire: fire,
      declares: declares,
    ),
  );
  return send == true;
}

/// Who a code is for, as the server sends it
/// (app/services/fire_code_notify.py).
String codeAudience(String number, {bool declares = false}) => switch (number) {
  // v1.12.60: a coordinator's FC-2 is seen by everyone.
  'FC-2' when declares => t(
    'This declares the fire under control: everyone, residents too, will see it.',
  ),
  'FC-2' => t(
    'It tells command. A Fire Volunteer or BFP coordinator declares the fire under control.',
  ),
  'FC-6' => t('It alerts Fire Volunteer and BFP coordinators with a sound.'),
  'FC-7' => t(
    'It alerts the coordinators of every agency on this fire with a sound.',
  ),
  'FC-8' => t(
    'It alerts medical coordinators and the central hub with a sound.',
  ),
  _ => t("It tells this fire's crews and coordinators, without a sound."),
};

class CodeConfirmSheet extends StatefulWidget {
  const CodeConfirmSheet({
    super.key,
    required this.number,
    required this.name,
    required this.fire,
    this.declares = false,
  });

  final String number;
  final String name;
  final String fire;

  /// This press declares the fire under control (v1.12.60).
  final bool declares;

  /// Send waits this long, so the second tap of an accidental double tap
  /// cannot land on it.
  static const Duration armAfter = Duration(milliseconds: 500);

  @override
  State<CodeConfirmSheet> createState() => _CodeConfirmSheetState();
}

class _CodeConfirmSheetState extends State<CodeConfirmSheet> {
  Timer? _arming;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _arming = Timer(CodeConfirmSheet.armAfter, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  void dispose() {
    _arming?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final cancel = AppButton.secondary(
      t('Cancel'),
      onPressed: () => navigator.pop(false),
    );
    final send = AppButton(
      t('Send {code}', {'code': widget.number}),
      onPressed: _armed ? () => navigator.pop(true) : null,
    );
    // Side by side, or one above the other once the type is set large.
    final large = MediaQuery.textScalerOf(context).scale(14) > 16.5;
    return SheetFrame(
      children: [
        SheetTitles(
          eyebrow: widget.fire,
          title: t('Send {code}?', {'code': widget.number}),
          body: widget.name,
        ),
        const SizedBox(height: 16),
        InlineAlert(
          tone: AlertTone.warning,
          title: t('Check before sending'),
          body: [
            codeAudience(widget.number, declares: widget.declares),
            if (widget.number == 'FC-3') t('It does not mark the fire out.'),
            t(
              "Nothing is sent until you press Send. Once sent, it stays on the incident's record.",
            ),
          ].join(' '),
        ),
        const SizedBox(height: 20),
        if (large) ...[
          send,
          const SizedBox(height: 10),
          cancel,
        ] else
          Row(
            children: [
              Expanded(child: cancel),
              const SizedBox(width: 12),
              Expanded(child: send),
            ],
          ),
      ],
    );
  }
}
