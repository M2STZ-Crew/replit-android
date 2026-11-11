import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../location/sos_location.dart';
import '../screens/camera_capture_screen.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'motion.dart';

/// Report a fire from a staff account (PRD v14 §4.6.3; Figma C23 / R20,
/// "Report a fire — staff report (same flow as residents)"). A Coordinator
/// or Responder who comes upon a fire reports it the way a resident does —
/// photo, who should respond, anything else — and the report counts as fully
/// trusted (v1.12.27). On the Queue and Duty headers, in the coral the SOS
/// button wears.
class ReportFireButton extends StatelessWidget {
  const ReportFireButton({super.key});

  Future<void> _open(BuildContext context) async {
    HapticFeedback.mediumImpact();
    // Start the location now: the report wants a fix by the time the photo
    // is taken.
    unawaited(SosLocation.instance.warmUp());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CameraCaptureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      button: true,
      label: t('Report a fire'),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('report-fire'),
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: () => _open(context),
            child: AnimatedContainer(
              duration: Motion.of(context).state,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: pal.accentGradient,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.localFireDepartment,
                    size: 18,
                    color: pal.accentText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t('REPORT A FIRE'),
                    style: context.type.action.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
