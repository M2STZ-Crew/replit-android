import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/report_queue.dart';
import 'package:replit/api/session.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/theme.dart';
import 'package:replit/tutorial/lit_lessons.dart';
import 'package:replit/tutorial/lit_tutorial_screen.dart';
import 'package:replit/tutorial/lit_tutorial_state.dart';

import 'fake_narration.dart';

/// 12 November 2026: the old seven-step tour replaced by Lit's voiced,
/// action-by-action practice report (REPLIT-LIT-TUTORIAL-REPLACEMENT-PROMPT).
void main() {
  const me = 'm.reyes@gmail.com';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = me;
  });

  group('the lessons and their files', () {
    test('eight lessons, in the real report\'s order, the photo inside 02', () {
      expect(kLitLessonCount, 8);
      expect(
        [for (final l in kLitLessons) l.id],
        [
          '01', '02', '02', '03', '04', '05', '06', '07', '08', //
        ],
      );
      expect(
        [for (final l in kLitLessons) l.name],
        [
          'welcome',
          'start_report',
          'photo',
          'check_location',
          'select_organization',
          'review_details',
          'practice_submit',
          'follow_updates',
          'finish',
        ],
      );
    });

    test('each lesson has its own clip in both languages, or says why not', () {
      for (final lesson in kLitLessons.where((l) => !l.part)) {
        if (kMissingClips.containsKey(lesson.id)) {
          expect(lesson.clip, isNull, reason: lesson.id);
          continue;
        }
        expect(lesson.clip, startsWith('${lesson.id}_'), reason: lesson.id);
        for (final language in LitLanguage.values) {
          final clip = lesson.clipAsset(language)!;
          expect(clip, 'tutorial/voice/${language.name}/${lesson.clip}.mp3');
          expect(File('assets/$clip').lengthSync(), greaterThan(10000));
        }
      }
      // 02 tells to tap a button the app does not have; 03 says the
      // location may be elsewhere. Both are captioned without a clip.
      expect(kMissingClips.keys, ['02', '03']);
    });

    test('every caption is there in English and Tagalog', () {
      for (final lesson in kLitLessons) {
        expect(lesson.captionEn.trim(), isNotEmpty);
        expect(lesson.captionTl.trim(), isNotEmpty);
        expect(lesson.captionTl, isNot(lesson.captionEn));
      }
      final hold = kLitLessons.firstWhere((l) => l.name == 'start_report');
      expect(hold.captionEn, contains('hold the SOS button'));
      expect(hold.captionEn, contains('two seconds'));
      expect(hold.captionEn, isNot(contains('Report Incident')));
    });

    test('the poses and the talking frames are in the app', () {
      for (final pose in LitPose.values) {
        expect(File(pose.asset).existsSync(), isTrue, reason: pose.asset);
      }
      final timing =
          jsonDecode(File('assets/tutorial/lit/timing.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(timing['duration_ms'], 3570);
      for (final step in timing['sequence'] as List) {
        final file = 'assets/tutorial/lit/${step['file']}';
        expect(File(file).existsSync(), isTrue, reason: file);
      }
    });
  });

  group('the practice report', () {
    late FakeNarrationPlayer voice;

    Future<void> pump(
      WidgetTester tester, {
      bool replay = false,
      Size size = const Size(402, 874),
      double scale = 1,
      bool reduced = false,
    }) async {
      voice = FakeNarrationPlayer();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced,
              ),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LitTutorialScreen(
                              account: me,
                              replay: replay,
                              player: voice,
                            ),
                          ),
                        ),
                        child: const Text('home'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await settle(tester);
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.tap(find.text(text));
      await settle(tester);
    }

    Future<void> holdDial(WidgetTester tester) async {
      final dial = find.bySemanticsLabel(
        'SOS. Press and hold for two seconds to start a report.',
      );
      final gesture = await tester.startGesture(tester.getCenter(dial));
      // The first frame starts the dial's clock; the next one fills it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2100));
      await gesture.up();
      await settle(tester);
    }

    String caption(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('lit-caption'))).data!;

    LitLesson lesson(String name) =>
        kLitLessons.firstWhere((l) => l.name == name);

    /// Through every lesson to Finish, by the real gestures.
    Future<void> walkThrough(WidgetTester tester) async {
      await tapText(tester, 'START TUTORIAL');
      expect(caption(tester), lesson('start_report').captionEn);
      await holdDial(tester);
      expect(caption(tester), lesson('photo').captionEn);
      await tester.tap(find.bySemanticsLabel('Take the photo').last);
      await settle(tester);
      expect(caption(tester), lesson('check_location').captionEn);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('select_organization').captionEn);
      await tester.tap(find.bySemanticsLabel('Medical'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(caption(tester), lesson('review_details').captionEn);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('practice_submit').captionEn);
      await tester.tap(find.text('SUBMIT PRACTICE REPORT'));
      await settle(tester);
      expect(caption(tester), contains('Nothing was sent'));
      await settle(tester, const Duration(milliseconds: 1500));
      expect(caption(tester), lesson('follow_updates').captionEn);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('finish').captionEn);
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
      // Its last clean-up runs after the route has gone.
      await tester.pump();
    }

    testWidgets('teaches the real report, and changes nothing real', (
      tester,
    ) async {
      final before = ReportQueue.instance.pending.value;
      await pump(tester);
      expect(find.text('PRACTICE MODE'), findsOneWidget);
      expect(caption(tester), lesson('welcome').captionEn);
      await walkThrough(tester);

      expect(find.byType(LitTutorialScreen), findsNothing, reason: 'home');
      expect(await LitTutorial.outcome(me), LitOutcome.completed);
      // Nothing reported, queued or remembered as a report.
      expect(ReportQueue.instance.pending.value, same(before));
      expect(ActiveReportStore.mine, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => !k.startsWith('lit_tutorial')),
        isEmpty,
        reason: 'the tutorial keeps only its own state',
      );
    });

    testWidgets('each lesson plays its own clip; 02 and 03 have none', (
      tester,
    ) async {
      await pump(tester);
      await walkThrough(tester);
      expect(voice.played, [
        'tutorial/voice/en/01_welcome.mp3',
        'tutorial/voice/en/04_select_organization.mp3',
        'tutorial/voice/en/05_review_details.mp3',
        'tutorial/voice/en/06_practice_submit.mp3',
        'tutorial/voice/en/07_follow_updates.mp3',
        'tutorial/voice/en/08_finish.mp3',
      ]);
      // The narrator lets go of the speaker after the route has gone.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(voice.disposed, isTrue, reason: 'nothing left playing');
    });

    testWidgets('Tagalog switches the voice and the words, not the lesson', (
      tester,
    ) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await holdDial(tester);
      await tester.tap(find.bySemanticsLabel('Take the photo').last);
      await settle(tester);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('select_organization').captionEn);

      await tester.tap(find.bySemanticsLabel('Tagalog'));
      await settle(tester);
      expect(caption(tester), lesson('select_organization').captionTl);
      expect(voice.played.last, 'tutorial/voice/tl/04_select_organization.mp3');
      expect(await LitTutorial.language(), LitLanguage.tl);
      // The app's buttons keep their names.
      expect(find.text('SUBMIT PRACTICE REPORT'), findsOneWidget);
    });

    testWidgets('Back returns to the lesson as it was', (tester) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await holdDial(tester);
      await tester.tap(find.bySemanticsLabel('Take the photo').last);
      await settle(tester);
      await tapText(tester, 'CONTINUE');
      await tester.tap(find.bySemanticsLabel('Medical'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(caption(tester), lesson('review_details').captionEn);
      bool medical() =>
          tester
              .getSemantics(find.bySemanticsLabel('Medical'))
              .flagsCollection
              .isChecked ==
          CheckedState.isTrue;
      expect(medical(), isTrue);

      await tapText(tester, 'Back');
      expect(caption(tester), lesson('select_organization').captionEn);
      expect(medical(), isFalse, reason: 'chosen again, in its lesson');
    });

    testWidgets('a second tap does not skip a lesson', (tester) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await holdDial(tester);
      await tester.tap(find.bySemanticsLabel('Take the photo').last);
      await settle(tester);
      // Twice, before the screen has moved on.
      await tester.tap(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'), warnIfMissed: false);
      await settle(tester);
      expect(caption(tester), lesson('select_organization').captionEn);
    });

    testWidgets('only the lit control answers; the rest waits', (tester) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await holdDial(tester);
      await tester.tap(find.bySemanticsLabel('Take the photo').last);
      await settle(tester);
      await tapText(tester, 'CONTINUE');
      // Police is not the one lit.
      await tester.tap(find.bySemanticsLabel('Police'), warnIfMissed: false);
      await settle(tester);
      expect(caption(tester), lesson('select_organization').captionEn);
    });

    testWidgets('Skip leaves at once, and is remembered as skipped', (
      tester,
    ) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.byType(LitTutorialScreen), findsNothing);
      expect(await LitTutorial.outcome(me), LitOutcome.skipped);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(voice.disposed, isTrue);
    });

    testWidgets('a replay skipped after finishing stays finished', (
      tester,
    ) async {
      await LitTutorial.complete(me);
      await pump(tester, replay: true);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(await LitTutorial.outcome(me), LitOutcome.completed);
    });

    testWidgets('muted: captions and still poses, no voice', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel("Turn Lit's voice off"));
      await settle(tester);
      final heard = voice.played.length;
      await tapText(tester, 'START TUTORIAL');
      await holdDial(tester);
      await tester.tap(find.bySemanticsLabel('Take the photo').last);
      await settle(tester);
      await tapText(tester, 'CONTINUE');
      expect(voice.played, hasLength(heard), reason: '04 was not played');
      expect(caption(tester), lesson('select_organization').captionEn);
      expect(find.byKey(const ValueKey('lit-talking')), findsNothing);
    });

    testWidgets('Lit talks only while his voice plays', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('lit-talking')), findsNothing);
      voice.start();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('lit-talking')), findsOneWidget);
      voice.end();
      await settle(tester);
      expect(find.byKey(const ValueKey('lit-wave')), findsOneWidget);
    });

    testWidgets('with reduced motion Lit stays still, and still speaks', (
      tester,
    ) async {
      await pump(tester, reduced: true);
      voice.start();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('lit-talking')), findsNothing);
      expect(find.byKey(const ValueKey('lit-wave')), findsOneWidget);
      expect(voice.played, ['tutorial/voice/en/01_welcome.mp3']);
    });

    testWidgets('a clip that will not play leaves the words and controls', (
      tester,
    ) async {
      await pump(tester);
      voice.fail = true;
      await tapText(tester, 'START TUTORIAL');
      await holdDial(tester);
      await tester.tap(find.bySemanticsLabel('Take the photo').last);
      await settle(tester);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('select_organization').captionEn);
      await tester.tap(find.bySemanticsLabel('Medical'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(caption(tester), lesson('review_details').captionEn);
    });

    testWidgets('going to the background stops Lit; Replay brings him back', (
      tester,
    ) async {
      await pump(tester);
      voice.start();
      await tester.pump();
      final stops = voice.stops;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(voice.stops, greaterThan(stops));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      final played = voice.played.length;
      expect(voice.played, hasLength(played), reason: 'no surprise replay');
      await tester.tap(find.bySemanticsLabel('Hear Lit again'));
      await settle(tester);
      expect(voice.played, hasLength(played + 1));
      expect(voice.played.last, 'tutorial/voice/en/01_welcome.mp3');
    });

    for (final (size, scale) in [
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 1.3),
      (const Size(402, 874), 1.5),
    ]) {
      testWidgets('fits a ${size.width.round()} × ${size.height.round()} '
          'phone at ${scale}x', (tester) async {
        await pump(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        // At a large text size the welcome scrolls a little to its button.
        await tester.ensureVisible(find.text('START TUTORIAL'));
        await tester.pump();
        await tester.tap(find.text('START TUTORIAL'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await holdDial(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.bySemanticsLabel('Take the photo').last);
        await settle(tester);
        expect(tester.takeException(), isNull);
        // Lit and his words sit below the lit control, never over it.
        final chip = tester.getRect(find.text('LOCATION LOCKED'));
        final words = tester.getRect(find.byKey(const ValueKey('lit-caption')));
        expect(chip.bottom, lessThan(words.top));
      });
    }
  });

  group('when it is offered', () {
    test('once per account, until finished or skipped', () async {
      expect(await LitTutorial.shouldOffer(me), isTrue);
      await LitTutorial.skip(me);
      expect(await LitTutorial.shouldOffer(me), isFalse);
      expect(await LitTutorial.shouldOffer('j.cruz@gmail.com'), isTrue);
      await LitTutorial.complete('J.Cruz@gmail.com');
      expect(await LitTutorial.shouldOffer('j.cruz@gmail.com'), isFalse);
      expect(await LitTutorial.shouldOffer(null), isFalse);
    });

    test(
      'to those who saw the old tour too, whose flags are left alone',
      () async {
        SharedPreferences.setMockInitialValues({
          'tour_seen_v1': true,
          'map_coach_seen_v1': true,
        });
        expect(await LitTutorial.shouldOffer(me), isTrue);
        await LitTutorial.complete(me);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('tour_seen_v1'), isTrue);
        expect(prefs.getBool('map_coach_seen_v1'), isTrue);
      },
    );

    test('the old tour is gone from the app', () {
      expect(File('lib/screens/onboarding_screen.dart').existsSync(), isFalse);
      expect(File('lib/widgets/map_coach_marks.dart').existsSync(), isFalse);
      final gate = File('lib/screens/role_gate.dart').readAsStringSync();
      expect(gate, contains('LitTutorialScreen.open'));
      expect(gate, isNot(contains('OnboardingScreen')));
    });

    test('Help replays it', () {
      final help = File(
        'lib/screens/help_center_screen.dart',
      ).readAsStringSync();
      expect(help, contains('replay: true'));
    });
  });
}

/// Pumps past the tutorial's beats without waiting on a spinner.
Future<void> settle(
  WidgetTester tester, [
  Duration time = const Duration(milliseconds: 100),
]) async {
  await tester.pump();
  await tester.pump(time);
  await tester.pump();
}
