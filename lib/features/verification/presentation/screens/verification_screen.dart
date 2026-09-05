import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/verification_provider.dart';

/// Progressive verification (Section 2.1): phone 40%, National ID 50%, email 10%.
///
/// Framed as credibility rather than compliance — the percentage is shown to
/// dispatchers when they assess a report, so the user should understand what
/// they gain, not feel audited.
///
/// The hand-off does not cover this screen, so it is aligned to it rather than
/// copied from it: the same glass panels, coral accent and uppercase headings
/// as the SOS flow it feeds.
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(verificationProvider);
    final percent = user?.verifiedPercent ?? 0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            const ScreenHeader(
              eyebrow: 'Credibility',
              title: 'Verify your account',
            ),
            const SizedBox(height: 26),
            _ScoreHeader(
              percent: percent,
              badge: user?.badge ?? VerificationBadge.yellow,
            ),
            const SizedBox(height: 20),
            if (state.errorMessage != null)
              _Banner(
                text: state.errorMessage!,
                color: AppColors.live,
                icon: Icons.error_outline_rounded,
                onDismiss: () =>
                    ref.read(verificationProvider.notifier).clearMessages(),
              ),
            if (state.infoMessage != null)
              _Banner(
                text: state.infoMessage!,
                color: AppColors.info,
                icon: Icons.info_outline_rounded,
                onDismiss: () =>
                    ref.read(verificationProvider.notifier).clearMessages(),
              ),
            const Eyebrow('Three ways to raise it', color: AppColors.accent),
            const SizedBox(height: 12),
            _PhoneTile(done: user?.phoneVerified ?? false, state: state),
            const SizedBox(height: 10),
            _EmailTile(
              done: user?.emailVerified ?? false,
              hasEmail: (user?.email?.isNotEmpty ?? false),
              busy: state.busy,
            ),
            const SizedBox(height: 10),
            _IdTile(done: user?.idVerified ?? false, state: state),
            const SizedBox(height: 24),
            Panel(
              radius: AppRadius.control,
              color: AppColors.surfaceDim,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your level is shown to Fire Volunteer coordinators when '
                      'they review your reports. It never slows an incident '
                      'down — it helps them weigh unverified sources.',
                      style: AppText.meta.copyWith(height: 16 / 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.percent, required this.badge});

  final int percent;
  final String badge;

  Color get _color => switch (badge) {
    VerificationBadge.greenCheck || VerificationBadge.green => AppColors.ok,
    VerificationBadge.lightGreen => AppColors.statusPending,
    _ => AppColors.statusPending,
  };

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(20),
      color: _color.withValues(alpha: 0.08),
      border: _color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: AppText.numeral.copyWith(fontSize: 40, color: _color),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  VerificationBadge.label(badge).toUpperCase(),
                  style: AppText.tag.copyWith(fontSize: 10, color: _color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: AppColors.lineStrong,
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneTile extends ConsumerStatefulWidget {
  const _PhoneTile({required this.done, required this.state});

  final bool done;
  final VerificationState state;

  @override
  ConsumerState<_PhoneTile> createState() => _PhoneTileState();
}

class _PhoneTileState extends ConsumerState<_PhoneTile> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(verificationProvider.notifier);
    final state = widget.state;
    final done = widget.done || state.phoneStep == PhoneStep.verified;

    return _StepTile(
      title: 'Phone number',
      weight: VerificationBadge.phonePercent,
      done: done,
      subtitle: done
          ? 'Verified by SMS'
          : 'Required. We text you a 6-digit code.',
      child: done
          ? null
          : switch (state.phoneStep) {
              PhoneStep.enterNumber => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _phone,
                    enabled: !state.busy,
                    keyboardType: TextInputType.phone,
                    style: _fieldStyle,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: '0917 123 4567',
                      prefixIcon: Icon(Icons.phone_outlined,
                          size: 18, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    'Send code',
                    height: 46,
                    busy: state.busy,
                    onPressed: state.busy
                        ? null
                        : () => notifier.sendPhoneCode(_phone.text),
                  ),
                ],
              ),
              PhoneStep.enterCode => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Code sent to ${state.phoneE164 ?? 'your phone'}',
                    style: AppText.meta,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _code,
                    enabled: !state.busy,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: _fieldStyle.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '••••••',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    'Verify',
                    height: 46,
                    busy: state.busy,
                    onPressed: state.busy
                        ? null
                        : () => notifier.submitPhoneCode(_code.text),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: state.busy ? null : notifier.changeNumber,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Eyebrow('Use a different number',
                            color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              ),
              PhoneStep.verified => null,
            },
    );
  }
}

class _EmailTile extends ConsumerWidget {
  const _EmailTile({
    required this.done,
    required this.hasEmail,
    required this.busy,
  });

  final bool done;
  final bool hasEmail;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StepTile(
      title: 'Email address',
      weight: VerificationBadge.emailPercent,
      done: done,
      subtitle: done
          ? 'Confirmed'
          : hasEmail
              ? 'We send a link. Open it to confirm.'
              : 'Add an email to your account first.',
      child: done || !hasEmail
          ? null
          : AppButton.secondary(
              'Send confirmation email',
              height: 46,
              busy: busy,
              onPressed: busy
                  ? null
                  : () =>
                        ref.read(verificationProvider.notifier).sendEmailLink(),
            ),
    );
  }
}

class _IdTile extends ConsumerWidget {
  const _IdTile({required this.done, required this.state});

  final bool done;
  final VerificationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(verificationProvider.notifier);
    final channels = ref.watch(verificationStatusProvider).valueOrNull;
    final channel = channels?['national_id'];
    final awaiting = VerificationStatus.isAwaitingReview(channel?.status);
    final rejected = channel?.status == VerificationStatus.rejected;

    // Awaiting review is not "done", but it must not show an upload form
    // either — that would invite a second submission on top of the first.
    if (done || awaiting) {
      return _StepTile(
        title: 'National ID',
        weight: VerificationBadge.nationalIdPercent,
        done: done,
        subtitle: done
            ? 'Approved'
            : 'Submitted. An Admin is reviewing it — this usually takes a day.',
        child: null,
      );
    }

    return _StepTile(
      title: 'National ID',
      weight: VerificationBadge.nationalIdPercent,
      done: false,
      subtitle: rejected
          ? 'Your last submission was not accepted. You can try again.'
          : 'Photograph your ID and take a selfie. An Admin reviews both.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rejected && (channel?.reviewNotes?.isNotEmpty ?? false)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                radius: AppRadius.control,
                color: AppColors.live.withValues(alpha: 0.09),
                border: AppColors.live.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(12),
                // Telling someone their ID was refused without saying why
                // leaves them no way to fix it.
                child: Text(
                  'Reason: ${channel!.reviewNotes}',
                  style: AppText.meta.copyWith(
                    height: 16 / 11,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _PickSlot(
                  label: 'ID photo',
                  file: state.idImage,
                  enabled: !state.busy,
                  onPick: (camera) =>
                      notifier.pickIdImage(isSelfie: false, fromCamera: camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickSlot(
                  label: 'Selfie',
                  file: state.selfieImage,
                  enabled: !state.busy,
                  onPick: (camera) =>
                      notifier.pickIdImage(isSelfie: true, fromCamera: camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppButton(
            'Send for review',
            height: 46,
            busy: state.busy,
            onPressed: state.canSubmitId ? notifier.submitNationalId : null,
          ),
          if (!state.canSubmitId && !state.busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(
                child: Eyebrow('Add both an ID photo and a selfie',
                    color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One image slot. Tapping offers camera or gallery — an ID is often already
/// photographed, but a selfie usually is not.
class _PickSlot extends StatelessWidget {
  const _PickSlot({
    required this.label,
    required this.file,
    required this.enabled,
    required this.onPick,
  });

  final String label;
  final File? file;
  final bool enabled;
  final void Function(bool fromCamera) onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final camera = await showModalBottomSheet<bool>(
                context: context,
                backgroundColor: AppColors.surfaceSolid,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: SheetHandle(),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_camera_outlined,
                            color: AppColors.accent),
                        title: Text('Take $label', style: AppText.rowTitle),
                        onTap: () => Navigator.pop(ctx, true),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined,
                            color: AppColors.accent),
                        title: const Text('Choose from gallery',
                            style: AppText.rowTitle),
                        onTap: () => Navigator.pop(ctx, false),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
              if (camera != null) onPick(camera);
            },
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: file != null ? AppColors.ok : AppColors.lineStrong,
          ),
          image: file != null
              ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: file != null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      size: 20, color: AppColors.muted),
                  const SizedBox(height: 8),
                  Eyebrow(label, color: AppColors.muted),
                ],
              ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.title,
    required this.weight,
    required this.done,
    required this.subtitle,
    this.child,
  });

  final String title;
  final int weight;
  final bool done;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(18),
      color: done ? AppColors.ok.withValues(alpha: 0.07) : AppColors.surfaceDim,
      border: done ? AppColors.ok.withValues(alpha: 0.4) : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done ? AppColors.ok : AppColors.lineLight,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppText.cardTitle.copyWith(fontSize: 14),
                ),
              ),
              Text(
                '+$weight%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: done ? AppColors.ok : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(subtitle, style: AppText.meta.copyWith(height: 16 / 11)),
          ),
          if (child != null) ...[const SizedBox(height: 16), child!],
        ],
      ),
    );
  }
}

const _fieldStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: AppColors.text,
);

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  final String text;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        radius: AppRadius.control,
        color: color.withValues(alpha: 0.09),
        border: color.withValues(alpha: 0.35),
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppText.meta.copyWith(
                  fontSize: 12,
                  height: 16 / 12,
                  color: AppColors.textSoft,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              iconSize: 18,
              color: AppColors.muted,
              icon: const Icon(Icons.close_rounded),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
