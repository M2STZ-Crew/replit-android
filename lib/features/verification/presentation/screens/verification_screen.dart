import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/verification_provider.dart';

/// Progressive verification (Section 2.1): phone 40%, National ID 50%, email 10%.
///
/// Framed as credibility rather than compliance — the percentage is shown to
/// dispatchers when they assess a report, so the user should understand what
/// they gain, not feel audited.
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(verificationProvider);
    final percent = user?.verifiedPercent ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ScoreHeader(percent: percent, badge: user?.badge ?? VerificationBadge.yellow),
          const SizedBox(height: 20),
          if (state.errorMessage != null)
            _Banner(
              text: state.errorMessage!,
              color: AppColors.error,
              icon: Icons.error_outline,
              onDismiss: () => ref.read(verificationProvider.notifier).clearMessages(),
            ),
          if (state.infoMessage != null)
            _Banner(
              text: state.infoMessage!,
              color: AppColors.info,
              icon: Icons.info_outline,
              onDismiss: () => ref.read(verificationProvider.notifier).clearMessages(),
            ),
          const SizedBox(height: 4),
          _PhoneTile(
            done: user?.phoneVerified ?? false,
            state: state,
          ),
          const SizedBox(height: 12),
          _EmailTile(
            done: user?.emailVerified ?? false,
            hasEmail: (user?.email?.isNotEmpty ?? false),
            busy: state.busy,
          ),
          const SizedBox(height: 12),
          _IdTile(done: user?.idVerified ?? false),
          const SizedBox(height: 24),
          Text(
            'Your verification level is shown to Fire Volunteer dispatchers when '
            'they review your reports. It never changes how quickly an incident '
            'is handled — it helps them judge unverified sources.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.percent, required this.badge});

  final int percent;
  final String badge;

  Color get _color => switch (badge) {
        VerificationBadge.greenCheck || VerificationBadge.green => AppColors.success,
        VerificationBadge.lightGreen => AppColors.secondary,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _color,
                    ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  VerificationBadge.label(badge),
                  style: TextStyle(color: _color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: Colors.black12,
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '0917 123 4567',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () => notifier.sendPhoneCode(_phone.text),
                      child: Text(state.busy ? 'Sending…' : 'Send code'),
                    ),
                  ],
                ),
              PhoneStep.enterCode => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Code sent to ${state.phoneE164 ?? 'your phone'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _code,
                      enabled: !state.busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '6-digit code',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () => notifier.submitPhoneCode(_code.text),
                      child: Text(state.busy ? 'Checking…' : 'Verify'),
                    ),
                    TextButton(
                      onPressed: state.busy ? null : notifier.changeNumber,
                      child: const Text('Use a different number'),
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
          : FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () => ref.read(verificationProvider.notifier).sendEmailLink(),
              child: Text(busy ? 'Sending…' : 'Send confirmation email'),
            ),
    );
  }
}

class _IdTile extends StatelessWidget {
  const _IdTile({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return _StepTile(
      title: 'National ID',
      weight: VerificationBadge.nationalIdPercent,
      done: done,
      subtitle: done
          ? 'Approved'
          : 'Upload coming soon — an Admin reviews each submission.',
      child: null,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done ? AppColors.success : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.success : Colors.black26,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                '+$weight%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: done ? AppColors.success : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          if (child != null) ...[
            const SizedBox(height: 14),
            child!,
          ],
        ],
      ),
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
