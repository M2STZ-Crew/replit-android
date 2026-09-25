import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/screens/onboarding_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/map_coach_marks.dart';

/// "GENERAL USER — ONBOARDING" (T1–T8): the tour says only what the system
/// actually does, the practice step sends nothing, and neither is shown twice.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  // The demo dial on step 1 loops for as long as it is on screen, so the tree
  // never settles: pump the page transition by hand instead.
  Future<void> next(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets('the tour walks every step, at ${scale}x', (tester) async {
      var finished = false;
      await pump(
        tester,
        OnboardingScreen(onFinish: () => finished = true),
        scale: scale,
      );

      expect(find.text("Hi, I'm Lit."), findsOneWidget);
      await next(tester, 'Show me around');

      expect(find.text('Hold SOS for three seconds'), findsOneWidget);
      expect(
        find.textContaining('A tap sends nothing'),
        findsOneWidget,
        reason: 'the hold is the whole point of the step',
      );
      await next(tester, 'Next');

      expect(
        find.text('Pick who should come, then take one photo'),
        findsOneWidget,
      );
      expect(
        find.text('Required — there is no skip'),
        findsOneWidget,
        reason: 'the server rejects a report with no photo',
      );
      await next(tester, 'Next');

      expect(find.text('Reports near each other become one'), findsOneWidget);
      expect(find.text('3 reports'), findsOneWidget);
      await next(tester, 'Next');

      expect(find.text('You may be asked to confirm'), findsOneWidget);
      expect(find.text('300 m around you'), findsOneWidget);
      await next(tester, 'Next');

      expect(find.text('Practice — nothing is sent'), findsOneWidget);
      await next(tester, "I've got it");

      expect(find.text("You're ready"), findsOneWidget);
      expect(find.text('Hold SOS for three seconds'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await next(tester, 'Open the map');
      expect(finished, isTrue);
      expect(await Tour.seen(), isTrue, reason: 'it is not shown again');
    });
  }

  testWidgets('practice sends nothing, and says so when it completes', (
    tester,
  ) async {
    await pump(tester, OnboardingScreen(onFinish: () {}));
    await next(tester, 'Show me around');
    for (var i = 0; i < 4; i++) {
      await next(tester, 'Next');
    }
    expect(find.text('Practice — nothing is sent'), findsOneWidget);
    expect(
      find.text('Keep your finger down until the ring closes.'),
      findsOneWidget,
    );

    // Hold the dial for its full three seconds.
    final dial = find.text('hold');
    expect(dial, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(dial));
    // The dial lives in a PageView, so the tap recogniser reports the press
    // only after the gesture arena's 100 ms deadline.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 4));
    await gesture.up();
    await tester.pump();

    expect(
      find.text("That's it. Nothing was sent — this was practice."),
      findsOneWidget,
    );
  });

  testWidgets('skipping the tour still counts as seen', (tester) async {
    var finished = false;
    await pump(tester, OnboardingScreen(onFinish: () => finished = true));
    await next(tester, 'Skip for now');
    expect(finished, isTrue);
    expect(await Tour.seen(), isTrue);
  });

  testWidgets('the coach marks name the two things and dismiss', (
    tester,
  ) async {
    var dismissed = false;
    await pump(
      tester,
      Scaffold(
        body: MapCoachMarks(
          sosLift: 100,
          area: const Offset(120, 320),
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    expect(find.text('Reports group into Areas'), findsOneWidget);
    expect(find.text('SOS lives here'), findsOneWidget);
    expect(
      find.textContaining('A tap does nothing'),
      findsOneWidget,
      reason: 'the same rule the SOS dial enforces',
    );
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  final rings = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_Halo',
  );

  testWidgets('the rings go round the SOS disc and the Area it is given', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: MapCoachMarks(
          sosLift: 100,
          area: const Offset(120, 320),
          onDismiss: () {},
        ),
      ),
    );
    final centres = [
      for (var i = 0; i < rings.evaluate().length; i++)
        tester.getCenter(rings.at(i)),
    ];
    expect(centres, contains(const Offset(120, 320)));
    expect(centres, contains(const Offset(201, 874 - 100)));

    // Each callout sits beside its own ring, not over the other one.
    final areaCard = tester.getRect(find.text('Reports group into Areas'));
    final sosCard = tester.getRect(find.text('SOS lives here'));
    expect(areaCard.top, greaterThan(320 + 48));
    expect(sosCard.bottom, lessThan(874 - 100 - 48));
    expect(areaCard.bottom, lessThan(sosCard.top));
  });

  testWidgets('with no Area on screen it rings only SOS and sits over the '
      'sheet', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: MapCoachMarks(sosLift: 100, sheetTop: 500, onDismiss: () {}),
      ),
    );
    expect(rings, findsOneWidget);
    expect(
      tester.getRect(find.text('Reports group into Areas')).bottom,
      lessThan(500),
    );
  });
}
