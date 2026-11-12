import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../i18n/language_switch.dart';
import '../theme.dart';
import '../widgets/design.dart';
import 'lit_character.dart';
import 'lit_lessons.dart';
import 'practice.dart';

/// 01 · Welcome: Lit, what the tutorial is, the language, and Start
/// Tutorial.
///
/// The language is chosen here and nowhere else in the tutorial, for Lit's
/// voice and words and the whole app together (12 November 2026: "the
/// screen will choose if tagalog or english only in the first screen and not
/// on every step"; answered: the whole app). It is the app's own English |
/// Tagalog switch, so it is told to the account as it is from Profile.
class LitWelcomeScreen extends StatelessWidget {
  const LitWelcomeScreen({super.key, required this.practice});

  static const String routeName = '/lit-tutorial';

  final LitPractice practice;

  String _say(String en, String tl) =>
      practice.language == LitLanguage.tl ? tl : en;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      practice.changes,
      practice.narrator.talking,
      practice.narrator.muted,
      LanguageChoice.current,
    ]),
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final pal = context.pal;
    final welcome = kLitLessons.first;
    return Scaffold(
      backgroundColor: pal.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PracticeModePill(),
                    ),
                  ),
                  LitVoiceControls(practice: practice),
                  TextLink(_say('Skip', 'Laktawan'), onTap: practice.skip),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                // Lit as big as the screen's height allows: 200 on a tall
                // phone.
                builder: (context, box) => FootedScroll(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  gap: 24,
                  content: [
                    Center(
                      child: Semantics(
                        label: 'Lit',
                        image: true,
                        child: LitCharacter(
                          pose: LitPose.wave,
                          talking: practice.narrator.talking.value,
                          size: (box.maxHeight * 0.28).clamp(96.0, 200.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _say('MEET LIT', 'KILALANIN SI LIT'),
                      textAlign: TextAlign.center,
                      style: context.type.heading1,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        welcome.caption(practice.language),
                        key: const ValueKey('lit-caption'),
                        textAlign: TextAlign.center,
                        style: context.type.body.copyWith(
                          color: pal.onBackground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // In both languages: whoever reads only one of them
                    // finds it.
                    Center(child: Eyebrow('Language · Wika', color: pal.muted)),
                    const SizedBox(height: 10),
                    const LanguageSwitch(),
                    const SizedBox(height: 10),
                    Text(
                      _say(
                        'Lit and the whole app use it. You can change it '
                            'later in Profile.',
                        'Ito ang gagamitin ni Lit at ng buong app. Mapapalitan '
                            'mo ito sa Profile.',
                      ),
                      textAlign: TextAlign.center,
                      style: context.type.caption.copyWith(color: pal.label),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _say(
                        'Nothing you do here is sent.',
                        'Walang naipapadala sa ginagawa mo rito.',
                      ),
                      textAlign: TextAlign.center,
                      style: context.type.caption.copyWith(color: pal.label),
                    ),
                  ],
                  footer: AppButton(
                    'Start Tutorial',
                    height: 56,
                    onPressed: practice.start,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
