import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/design.dart';
import 'call_screen.dart';

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

const List<_Faq> _faqs = [
  _Faq(
    'How do I report an emergency?',
    'On the ALERT tab, press and hold the SOS button for 3 seconds. Take a photo '
        'of the scene, choose the responders you need (Fire, Police, Medical, '
        'Barangay), add optional notes, then tap REQUEST HELP NOW.',
  ),
  _Faq(
    'What happens after I report?',
    'Your report is localized into an incident area and sent to command for '
        'verification. Tap TRACK RESPONSE LIVE to follow the status — pending, '
        'verified, dispatched, en route, arrived, or resolved.',
  ),
  _Faq(
    'Can I add more responders later?',
    "On the live tracking screen, tick the extra units under 'Do you need more "
        "help?' and tap ADD MORE HELP. They're added to your existing incident — "
        'no new report and no second photo.',
  ),
  _Faq(
    'What is my Trust Level?',
    'Verifying your email (+10%), phone (+40%), and National ID (+50%) raises your '
        'trust level, making your reports more credible to responders. Manage it in '
        'Profile → Verification.',
  ),
  _Faq(
    "What are the 'fire near you' alerts?",
    'If someone reports a fire within 300 m of you, you receive a push alert. Tap '
        'it to confirm there is a fire (which files a corroborating report) or to '
        'ignore it. Manage alerts in Profile → Notifications.',
  ),
  _Faq(
    'How do I find a safe area?',
    'On the live tracking screen the nearest evacuation site is shown. Tap SHOW ME '
        'THE WAY for in-app directions to it.',
  ),
  _Faq(
    'Why do you need my camera and location?',
    'A live photo and GPS confirm a real incident at your location and help '
        'responders reach you quickly. Your photos are stored privately.',
  ),
];

/// Help Center — a static FAQ for citizens plus an emergency reminder.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(context),
              const SizedBox(height: 20),
              const Text(
                'Frequently asked',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              ..._faqs.map(_faqTile),
              const SizedBox(height: 20),
              _emergencyCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        const BackWell(),
        const SizedBox(width: 16),
        Text('Help Center'.toUpperCase(), style: AppText.screenTitle),
      ],
    );
  }

  Widget _faqTile(_Faq faq) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: EdgeInsets.zero,
        color: AppColors.glassDim,
        child: Theme(
          data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: AppColors.accent,
            collapsedIconColor: AppColors.muted,
            tilePadding: const EdgeInsets.symmetric(horizontal: 18),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            title: Text(
              faq.question,
              style: const TextStyle(
                fontSize: 13,
                height: 18 / 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackground,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq.answer,
                  style: AppText.meta.copyWith(
                    fontSize: 12,
                    height: 18 / 12,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emergencyCard(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(20),
      color: AppColors.accent.withValues(alpha: 0.09),
      border: AppColors.accent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('In a real emergency', color: AppColors.accent),
          const SizedBox(height: 10),
          Text(
            'Hold the SOS button, or dial a hotline directly. Do not wait if '
            'lives are at risk.',
            style: AppText.meta.copyWith(
              fontSize: 13,
              height: 19 / 13,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            'View emergency hotlines',
            height: 48,
            icon: Icons.call_rounded,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CallScreen())),
          ),
        ],
      ),
    );
  }
}
