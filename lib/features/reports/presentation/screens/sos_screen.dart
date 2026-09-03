import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/sos_provider.dart';

/// The citizen report flow: hold SOS, capture evidence, submit.
///
/// The three-second hold (Section 3.3) is deliberate friction — a single tap on
/// a big red button in a pocket would flood dispatchers with false alarms.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: AppConstants.sosHoldDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        ref.read(sosProvider.notifier).acquireLocation();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _startHold() {
    if (ref.read(sosProvider).isBusy) return;
    _hold.forward();
  }

  void _cancelHold() {
    if (!_hold.isCompleted) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sosProvider);

    ref.listen<SosState>(sosProvider, (previous, next) {
      // Reset the ring whenever we leave the capture flow, so a second report
      // starts from an empty circle rather than a full one.
      if (next.stage == SosStage.idle || next.stage == SosStage.failed) {
        _hold.value = 0;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Report a fire')),
      body: SafeArea(
        child: switch (state.stage) {
          SosStage.submitted => _SubmittedView(state: state),
          _ => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessage != null) ...[
                    _ErrorBanner(
                      message: state.errorMessage!,
                      onDismiss: () =>
                          ref.read(sosProvider.notifier).dismissError(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _HoldButton(
                    controller: _hold,
                    state: state,
                    onHoldStart: _startHold,
                    onHoldEnd: _cancelHold,
                  ),
                  const SizedBox(height: 24),
                  if (state.position != null) _CapturePanel(state: state),
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.controller,
    required this.state,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final AnimationController controller;
  final SosState state;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final locating = state.stage == SosStage.locating;
    final held = state.position != null;

    return Column(
      children: [
        Semantics(
          button: true,
          label: 'SOS. Press and hold for three seconds to report a fire.',
          child: GestureDetector(
            onTapDown: (_) => onHoldStart(),
            onTapUp: (_) => onHoldEnd(),
            onTapCancel: onHoldEnd,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 210,
                        height: 210,
                        child: CircularProgressIndicator(
                          value: locating ? null : controller.value,
                          strokeWidth: 8,
                          backgroundColor: Colors.black12,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primaryDark,
                          ),
                        ),
                      ),
                      Container(
                        width: 172,
                        height: 172,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: held ? AppColors.success : AppColors.primary,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          held ? 'LOCATED' : 'SOS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          switch (state.stage) {
            SosStage.locating => 'Getting your location…',
            SosStage.ready ||
            SosStage.submitting =>
              'Location captured to ±${state.position!.accuracy.round()} m',
            _ => 'Press and hold for 3 seconds',
          },
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _CapturePanel extends ConsumerWidget {
  const _CapturePanel({required this.state});

  final SosState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sosProvider.notifier);
    final submitting = state.stage == SosStage.submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('Photo of the fire', required: true),
        const SizedBox(height: 8),
        if (state.photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              state.photo!,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (state.photo != null) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: submitting
                    ? null
                    : () => notifier.capturePhoto(fromCamera: true),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(state.photo == null ? 'Take photo' : 'Retake'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: submitting
                    ? null
                    : () => notifier.capturePhoto(fromCamera: false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SectionLabel('Who should respond?', required: true),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final agency in AgencyType.all)
              FilterChip(
                label: Text(AgencyType.label(agency)),
                selected: state.agencies.contains(agency),
                onSelected:
                    submitting ? null : (_) => notifier.toggleAgency(agency),
              ),
          ],
        ),
        const SizedBox(height: 22),
        _SectionLabel('Anything else? (optional)'),
        const SizedBox(height: 8),
        TextField(
          enabled: !submitting,
          maxLines: 3,
          maxLength: AppConstants.maxNotesLength,
          decoration: const InputDecoration(
            hintText: 'Landmark, number of floors, people trapped…',
          ),
          onChanged: notifier.setNotes,
        ),
        const SizedBox(height: 8),
        if (submitting) ...[
          LinearProgressIndicator(
            value: state.uploadProgress > 0 ? state.uploadProgress : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Sending report… ${(state.uploadProgress * 100).round()}%',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: state.canSubmit ? notifier.submit : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppColors.primary,
          ),
          child: Text(submitting ? 'Sending…' : 'Send report'),
        ),
        if (!state.canSubmit && !submitting) ...[
          const SizedBox(height: 8),
          Text(
            state.photo == null
                ? 'A photo is required before you can send.'
                : 'Choose at least one agency to respond.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _SubmittedView extends ConsumerWidget {
  const _SubmittedView({required this.state});

  final SosState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 72, color: AppColors.success),
          const SizedBox(height: 20),
          Text(
            'Report sent',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Your report joined ${result.areaDesignation}. A Fire Volunteer '
            'will review it, and neighbours within 300 m have been alerted.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (result.gpsDiscrepancyFlag) ...[
            const SizedBox(height: 16),
            _Notice(
              icon: Icons.info_outline,
              color: AppColors.warning,
              // Not the citizen's fault and not a rejection — the report was
              // accepted, it just gets a closer look.
              text: "The photo's location differs from your phone's. A "
                  'dispatcher will double-check it.',
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => ref.read(sosProvider.notifier).reset(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: Theme.of(context).textTheme.titleSmall),
        if (required)
          const Text(' *', style: TextStyle(color: AppColors.primary)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
