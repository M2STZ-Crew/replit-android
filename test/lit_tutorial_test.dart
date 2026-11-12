import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/report_queue.dart';
import 'package:replit/api/session.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/location/sos_location.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/theme.dart';
import 'package:replit/tutorial/lit_lessons.dart';
import 'package:replit/tutorial/lit_tutorial_state.dart';
import 'package:replit/tutorial/practice.dart';
import 'package:replit/widgets/app_nav_bar.dart';
import 'package:replit/widgets/design.dart';

import 'fake_narration.dart';

/// 12 November 2026: the LIT tutorial on the real reporting screens ("the
/// system or the real reporting phase is in the tutorial (but it will not
/// report officially)"). Answered: from the map, SOS tapped and held, the
/// real camera and GPS, the stages played after Submit Practice Report; the
/// language chosen once, on the first screen, for the whole app; Continue and
/// Finish across the width under Lit; Replay on Profile only.
const _me = 'm.reyes@gmail.com';
var _replay = false;

/// A phone still finding itself: the fix never lands, so the camera draws no
/// map (whose tiles would come from the network).
class _Searching extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Completer<Position>().future;
}

/// The map's place in a test: the resident's real bar, SOS and all (the
/// real map draws its tiles from the network).
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () =>
            LitPractice.open(context, account: _me, replay: _replay),
        child: const Text('Tutorial'),
      ),
    ),
    bottomNavigationBar: const AppNavBar(active: AppTab.map),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = _me;
    GeolocatorPlatform.instance = _Searching();
    SosLocation.instance.reset();
    _replay = false;
    // No camera in a test: the practice's drawing stands in for the photo.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/camera'),
          (call) async => call.method == 'availableCameras' ? <Object>[] : null,
        );
  });
  tearDown(() {
    LanguageChoice.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/camera'),
          null,
        );
  });

  LitLesson lesson(String name) =>
      kLitLessons.firstWhere((l) => l.name == name);

  group('the lessons and their files', () {
    test('eight lessons in a real report\'s order; SOS tapped, held and the '
        'photo are 02', () {
      expect(kLitLessonCount, 8);
      expect(
        [for (final l in kLitLessons) l.id],
        [
          '01', '02', '02', '02', '03', '04', '05', '06', '07', '08', //
        ],
      );
      expect(
        [for (final l in kLitLessons) l.name],
        [
          'welcome',
          'tap_sos',
          'hold_sos',
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
      for (final l in kLitLessons.where((l) => !l.part)) {
        if (kMissingClips.containsKey(l.id)) {
          expect(l.clip, isNull, reason: l.id);
          continue;
        }
        expect(l.clip, startsWith('${l.id}_'), reason: l.id);
        for (final language in LitLanguage.values) {
          final clip = l.clipAsset(language)!;
          expect(clip, 'tutorial/voice/${language.name}/${l.clip}.mp3');
          expect(File('assets/$clip').lengthSync(), greaterThan(10000));
        }
      }
      // 02's parts are new words for the real screens; 03 says the location
      // may be elsewhere. All are captioned without a clip.
      expect(kMissingClips.keys, ['02', '03']);
      for (final part in kLitLessons.where((l) => l.id == '02')) {
        expect(part.clip, isNull, reason: part.name);
      }
    });

    test('every caption is there in English and Tagalog', () {
      for (final l in kLitLessons) {
        expect(l.captionEn.trim(), isNotEmpty);
        expect(l.captionTl.trim(), isNotEmpty);
        expect(l.captionTl, isNot(l.captionEn));
        expect(l.captionEn, isNot(contains('Report Incident')));
      }
      expect(lesson('tap_sos').captionEn, contains('tap SOS'));
      expect(lesson('hold_sos').captionEn, contains('hold the SOS button'));
      expect(lesson('hold_sos').captionEn, contains('two seconds'));
      expect(lesson('photo').captionEn, contains('never sent'));
    });

    test('each lit control is one a real screen marks', () {
      final screens = {
        LitTargets.sosDisc: 'lib/widgets/app_nav_bar.dart',
        LitTargets.sosDial: 'lib/screens/home_screen.dart',
        LitTargets.shutter: 'lib/screens/camera_capture_screen.dart',
        LitTargets.location: 'lib/screens/sos_report_screen.dart',
        LitTargets.medical: 'lib/screens/sos_report_screen.dart',
        LitTargets.form: 'lib/screens/sos_report_screen.dart',
        LitTargets.send: 'lib/screens/sos_report_screen.dart',
        LitTargets.updates: 'lib/screens/report_status_screen.dart',
      };
      const names = {
        LitTargets.sosDisc: 'sosDisc',
        LitTargets.sosDial: 'sosDial',
        LitTargets.shutter: 'shutter',
        LitTargets.location: 'location',
        LitTargets.medical: 'medical',
        LitTargets.form: 'form',
        LitTargets.send: 'send',
        LitTargets.updates: 'updates',
      };
      for (final l in kLitLessons.where((l) => l.target != null)) {
        final file = screens[l.target];
        expect(file, isNotNull, reason: l.name);
        expect(
          File(file!).readAsStringSync(),
          contains('LitTargets.${names[l.target]}'),
          reason: '${l.name} lights a control of $file',
        );
      }
    });

    test('the poses, the talking frames and the practice photo are in the '
        'app', () {
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
      expect(File(Practice.samplePhoto).lengthSync(), greaterThan(1000));
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- ${Practice.samplePhoto}'),
      );
    });
  });

  group('the practice report, on the real screens', () {
    late FakeNarrationPlayer voice;

    Future<void> pump(
      WidgetTester tester, {
      bool replay = false,
      Size size = const Size(402, 874),
      double scale = 1,
      bool reduced = false,
    }) async {
      voice = FakeNarrationPlayer();
      _replay = replay;
      LitPractice.playerOverride = () => voice;
      LitPractice.homeOverride = (context) =>
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const _Home(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (_) => false,
          );
      addTearDown(() async {
        // A test that failed half way leaves its practice behind: not for
        // the next one to find.
        await Practice.session?.skip();
        LitPractice.playerOverride = null;
        LitPractice.homeOverride = null;
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
          home: const _Home(),
        ),
      );
      await tester.tap(find.text('Tutorial'));
      await settle(tester);
    }

    /// Out of the practice, however far it got: nothing of it outlives the
    /// test.
    Future<void> leave(WidgetTester tester) async {
      await Practice.session?.skip();
      await tester.pump();
      await tester.pump();
    }

    String caption(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('lit-caption'))).data!;

    Rect coach(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('lit-coach')));

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.tap(find.text(text));
      await settle(tester);
    }

    late final disc = find.bySemanticsLabel('SOS — hold to report');
    // The dial's own "SOS" is read with it.
    late final dial = find.bySemanticsLabel(
      RegExp(r'^SOS\. Press and hold for two seconds to start a report\.'),
    );
    late final medical = find.bySemanticsLabel('Medical');

    Future<void> tapSos(WidgetTester tester) async {
      await tester.tap(disc);
      await settle(tester);
    }

    Future<void> holdSos(WidgetTester tester) async {
      final gesture = await tester.startGesture(tester.getCenter(dial));
      // A press, then its clock starts, then two seconds held.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2100));
      await gesture.up();
      await settle(tester);
    }

    // No camera in a test: the shutter takes the practice's drawing.
    late final shutter = find.bySemanticsLabel('Take the photo');

    Future<void> takePhoto(WidgetTester tester) async {
      // The camera says why it is a drawing.
      expect(find.textContaining('No camera found'), findsOneWidget);
      expect(
        find.textContaining('For practice, tap the shutter'),
        findsOneWidget,
      );
      await tester.tap(shutter);
      await settle(tester);
    }

    Future<void> toChooseWho(WidgetTester tester) async {
      await tapText(tester, 'START TUTORIAL');
      await tapSos(tester);
      await holdSos(tester);
      await takePhoto(tester);
      await tapText(tester, 'CONTINUE');
    }

    /// Through every lesson to Finish, by the real gestures on the real
    /// screens.
    Future<void> walkThrough(WidgetTester tester) async {
      await tapText(tester, 'START TUTORIAL');
      expect(caption(tester), lesson('tap_sos').captionEn);
      expect(find.text('STEP 2 OF 8'), findsOneWidget);
      await tapSos(tester);
      expect(caption(tester), lesson('hold_sos').captionEn);
      expect(find.text("YOU'RE COVERED"), findsOneWidget, reason: 'the SOS');
      await holdSos(tester);
      expect(caption(tester), lesson('photo').captionEn);
      expect(find.text('SHOW THEM'), findsOneWidget, reason: 'the camera');
      await takePhoto(tester);
      expect(caption(tester), lesson('check_location').captionEn);
      expect(find.text('WHAT ARE WE SENDING?'), findsOneWidget);
      // Send is the practice's.
      expect(find.text('SUBMIT PRACTICE REPORT'), findsOneWidget);
      expect(find.text('SEND REPORT'), findsNothing);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('select_organization').captionEn);
      await tester.tap(medical);
      await settle(tester, const Duration(milliseconds: 600));
      expect(caption(tester), lesson('review_details').captionEn);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('practice_submit').captionEn);
      await tapText(tester, 'SUBMIT PRACTICE REPORT');
      expect(caption(tester), contains('Nothing was sent'));
      expect(find.text('PRACTICE REPORT'), findsOneWidget, reason: 'status');
      await settle(tester, const Duration(milliseconds: 1500));
      expect(caption(tester), lesson('follow_updates').captionEn);
      // The stages play by themselves: on the way, a few seconds in.
      expect(find.text('Waiting to be accepted'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 1500));
      expect(find.text('Responders are on the way'), findsOneWidget);
      // Nothing on it leads anywhere real.
      expect(find.text('TRACK IT LIVE'), findsNothing);
      await tapText(tester, 'CONTINUE');
      expect(caption(tester), lesson('finish').captionEn);
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
    }

    testWidgets('teaches on the real screens, and reports nothing', (
      tester,
    ) async {
      final queued = ReportQueue.instance.pending.value;
      await pump(tester);
      expect(find.text('PRACTICE MODE'), findsOneWidget);
      expect(caption(tester), lesson('welcome').captionEn);
      await walkThrough(tester);

      expect(find.byKey(const ValueKey('lit-coach')), findsNothing);
      expect(find.text('Tutorial'), findsOneWidget, reason: 'home again');
      expect(Practice.active, isFalse);
      expect(await LitTutorial.outcome(_me), LitOutcome.completed);
      // Nothing reported, queued or remembered as a report.
      expect(ReportQueue.instance.pending.value, same(queued));
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
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(voice.disposed, isTrue, reason: 'nothing left playing');
    });

    testWidgets('the language is chosen once, on the welcome, for the whole '
        'app', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('Tagalog'));
      await settle(tester);
      expect(LanguageChoice.current.value, AppLanguage.tl);
      expect(caption(tester), lesson('welcome').captionTl);
      expect(voice.played.last, 'tutorial/voice/tl/01_welcome.mp3');

      await tapText(tester, 'START TUTORIAL');
      expect(caption(tester), lesson('tap_sos').captionTl);
      expect(find.text('HAKBANG 2 SA 8'), findsOneWidget);
      // No language switch on the lessons.
      expect(find.bySemanticsLabel('English'), findsNothing);
      expect(find.bySemanticsLabel('Tagalog'), findsNothing);
      await leave(tester);
    });

    testWidgets('Back on the form chooses again', (tester) async {
      await pump(tester);
      await toChooseWho(tester);
      await tester.tap(medical);
      await settle(tester, const Duration(milliseconds: 600));
      expect(caption(tester), lesson('review_details').captionEn);
      bool ticked() =>
          tester.getSemantics(medical).flagsCollection.isChecked ==
          CheckedState.isTrue;
      expect(ticked(), isTrue);

      await tapText(tester, 'Back');
      expect(caption(tester), lesson('select_organization').captionEn);
      expect(ticked(), isFalse, reason: 'chosen again, in its lesson');
      await leave(tester);
    });

    testWidgets('the phone\'s Back is the tutorial\'s: the camera goes back '
        'to the SOS screen', (tester) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await tapSos(tester);
      await holdSos(tester);
      expect(caption(tester), lesson('photo').captionEn);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await settle(tester);
      expect(caption(tester), lesson('hold_sos').captionEn);
      expect(find.text('SHOW THEM'), findsNothing);
      expect(dial, findsOneWidget);

      // Back on the SOS screen: the map, and SOS to tap.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await settle(tester);
      expect(caption(tester), lesson('tap_sos').captionEn);
      // Back with nothing before it stays, rather than leave the app.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await settle(tester);
      expect(caption(tester), lesson('tap_sos').captionEn);
      await leave(tester);
    });

    testWidgets('Back from the updates returns to the form it was sent from', (
      tester,
    ) async {
      await pump(tester);
      await toChooseWho(tester);
      await tester.tap(medical);
      await settle(tester, const Duration(milliseconds: 600));
      await tapText(tester, 'CONTINUE');
      await tapText(tester, 'SUBMIT PRACTICE REPORT');
      await settle(tester, const Duration(milliseconds: 1500));
      expect(caption(tester), lesson('follow_updates').captionEn);

      await tapText(tester, 'Back');
      expect(caption(tester), lesson('practice_submit').captionEn);
      expect(find.text('SUBMIT PRACTICE REPORT'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a second tap does not skip a lesson', (tester) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await tapSos(tester);
      await holdSos(tester);
      await takePhoto(tester);
      // Twice, before the screen has moved on.
      await tester.tap(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'), warnIfMissed: false);
      await settle(tester);
      expect(caption(tester), lesson('select_organization').captionEn);
      await leave(tester);
    });

    testWidgets('only the lit control answers; the rest waits', (tester) async {
      await pump(tester);
      await toChooseWho(tester);
      // Police is not the one lit.
      final police = find.bySemanticsLabel('Police');
      await tester.tap(police, warnIfMissed: false);
      await settle(tester);
      expect(caption(tester), lesson('select_organization').captionEn);
      expect(
        tester.getSemantics(police).flagsCollection.isChecked,
        isNot(CheckedState.isTrue),
      );
      await leave(tester);
    });

    testWidgets('Skip leaves at once, home, and is remembered as skipped', (
      tester,
    ) async {
      await pump(tester);
      await tapText(tester, 'START TUTORIAL');
      await tapSos(tester);
      await tester.tap(find.text('Skip'));
      await settle(tester);
      expect(find.byKey(const ValueKey('lit-coach')), findsNothing);
      expect(find.text('Tutorial'), findsOneWidget, reason: 'home');
      expect(Practice.active, isFalse);
      expect(await LitTutorial.outcome(_me), LitOutcome.skipped);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(voice.disposed, isTrue);
    });

    testWidgets('Back from the welcome is a skip', (tester) async {
      await pump(tester);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await settle(tester);
      expect(find.text('START TUTORIAL'), findsNothing);
      expect(Practice.session, isNull);
      expect(await LitTutorial.outcome(_me), LitOutcome.skipped);
    });

    testWidgets('a replay skipped after finishing stays finished', (
      tester,
    ) async {
      await LitTutorial.complete(_me);
      await pump(tester, replay: true);
      await tester.tap(find.text('Skip'));
      await settle(tester);
      expect(await LitTutorial.outcome(_me), LitOutcome.completed);
    });

    testWidgets('muted: captions and still poses, no voice', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel("Turn Lit's voice off"));
      await settle(tester);
      final heard = voice.played.length;
      await toChooseWho(tester);
      expect(voice.played, hasLength(heard), reason: '04 was not played');
      expect(caption(tester), lesson('select_organization').captionEn);
      expect(find.byKey(const ValueKey('lit-talking')), findsNothing);
      await leave(tester);
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
      await leave(tester);
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
      await leave(tester);
    });

    testWidgets('a clip that will not play leaves the words and controls', (
      tester,
    ) async {
      await pump(tester);
      voice.fail = true;
      await toChooseWho(tester);
      expect(caption(tester), lesson('select_organization').captionEn);
      await tester.tap(medical);
      await settle(tester, const Duration(milliseconds: 600));
      expect(caption(tester), lesson('review_details').captionEn);
      await leave(tester);
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
      await leave(tester);
    });

    for (final (size, scale) in [
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 1.3),
      (const Size(402, 874), 1.5),
    ]) {
      testWidgets('fits a ${size.width.round()} × ${size.height.round()} '
          'phone at ${scale}x, never over what it lights', (tester) async {
        await pump(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        // At a large text size the welcome scrolls a little to its button.
        await tester.ensureVisible(find.text('START TUTORIAL'));
        await tester.pump();
        await tapText(tester, 'START TUTORIAL');
        expect(tester.takeException(), isNull);
        expect(coach(tester).contains(tester.getCenter(disc)), isFalse);

        await tapSos(tester);
        expect(tester.takeException(), isNull);
        expect(coach(tester).contains(tester.getCenter(dial)), isFalse);

        await holdSos(tester);
        expect(tester.takeException(), isNull);
        expect(coach(tester).contains(tester.getCenter(shutter)), isFalse);

        await takePhoto(tester);
        expect(tester.takeException(), isNull);
        // Lit and his words sit below the location, never over it.
        final chip = tester.getRect(find.text('FINDING YOUR LOCATION'));
        expect(coach(tester).top, greaterThan(chip.bottom));
        expect(find.text('CONTINUE'), findsOneWidget);

        await tapText(tester, 'CONTINUE');
        expect(tester.takeException(), isNull);
        expect(coach(tester).contains(tester.getCenter(medical)), isFalse);

        await tester.tap(medical);
        await settle(tester, const Duration(milliseconds: 600));
        await tapText(tester, 'CONTINUE');
        expect(tester.takeException(), isNull);
        final send = find.text('SUBMIT PRACTICE REPORT');
        expect(coach(tester).contains(tester.getCenter(send)), isFalse);

        await tapText(tester, 'SUBMIT PRACTICE REPORT');
        await settle(tester, const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
        expect(caption(tester), lesson('follow_updates').captionEn);
        // Continue and Finish across the width, under Lit.
        final next = tester.getRect(
          find.ancestor(
            of: find.text('CONTINUE'),
            matching: find.byType(AppButton),
          ),
        );
        final panel = coach(tester);
        expect(next.center.dx, closeTo(panel.center.dx, 8));
        expect(next.width, greaterThan(panel.width * 0.8));
        // His words above it, scrolling in their own room when long.
        final words = find.ancestor(
          of: find.byKey(const ValueKey('lit-caption')),
          matching: find.byType(SingleChildScrollView),
        );
        expect(tester.getRect(words.first).bottom, lessThanOrEqualTo(next.top));
        await leave(tester);
      });
    }
  });

  group('where it is offered and replayed', () {
    test('once per account, until finished or skipped', () async {
      expect(await LitTutorial.shouldOffer(_me), isTrue);
      await LitTutorial.skip(_me);
      expect(await LitTutorial.shouldOffer(_me), isFalse);
      expect(await LitTutorial.shouldOffer('j.cruz@gmail.com'), isTrue);
      await LitTutorial.complete('J.Cruz@gmail.com');
      expect(await LitTutorial.shouldOffer('j.cruz@gmail.com'), isFalse);
      expect(await LitTutorial.shouldOffer(null), isFalse);
    });

    test('to everyone again, those who finished the drawn one too', () async {
      SharedPreferences.setMockInitialValues({
        'lit_tutorial_v1_$_me': 'completed',
        'tour_seen_v1': true,
      });
      expect(await LitTutorial.shouldOffer(_me), isTrue);
      await LitTutorial.complete(_me);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lit_tutorial_v1_$_me'), 'completed');
      expect(prefs.getBool('tour_seen_v1'), isTrue);
    });

    test('the drawn practice is gone; the first sign-in offers this one', () {
      expect(File('lib/tutorial/lit_tutorial_screen.dart').existsSync(), false);
      expect(File('lib/tutorial/practice_stage.dart').existsSync(), false);
      final gate = File('lib/screens/role_gate.dart').readAsStringSync();
      expect(gate, contains('LitPractice.open(context, account: account)'));
    });

    test('Profile replays it, and Help no longer does', () {
      final profile = File(
        'lib/screens/profile_screen.dart',
      ).readAsStringSync();
      expect(profile, contains("t('Replay the tutorial')"));
      expect(profile, contains('replay: true'));
      final help = File(
        'lib/screens/help_center_screen.dart',
      ).readAsStringSync();
      expect(help, isNot(contains('Replay')));
    });
  });
}

/// Pumps past the tutorial's beats and a screen's slide, without waiting on
/// what never settles (the SOS dial breathes). In steps, so what starts on
/// the way (a screen sliding in, the lit control scrolled into view) has
/// its frames too.
Future<void> settle(
  WidgetTester tester, [
  Duration time = const Duration(milliseconds: 600),
]) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(time ~/ 4);
  }
  await tester.pump();
}
