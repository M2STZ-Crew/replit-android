import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/security/developer_mode.dart';
import 'package:replit/theme.dart';

/// A release build will not run while Android's Developer options are on
/// (the 5 November issue list, 2.1): they are where a fake-GPS app is
/// switched on, and every report needs a real location.
void main() {
  late bool on;
  late int asked;

  setUp(() {
    on = true;
    asked = 0;
    DeveloperMode.enforcedOverride = true;
    DeveloperMode.probeOverride = () async {
      asked++;
      return on;
    };
  });

  tearDown(() {
    DeveloperMode.enforcedOverride = null;
    DeveloperMode.probeOverride = null;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => DeveloperModeGate(child: child!),
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Report a fire'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('with them on, the app is covered and cannot be used', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('TURN OFF DEVELOPER OPTIONS'), findsOneWidget);
    expect(find.text('OPEN DEVELOPER OPTIONS'), findsOneWidget);
    expect(find.text('In an emergency, call 911'), findsOneWidget);
    // The app is still there underneath, but out of reach.
    expect(
      find.byWidgetPredicate(
        (w) => w is AbsorbPointer && w.absorbing,
        description: 'an absorbing AbsorbPointer',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('turned off, "I\'ve turned them off" lets them in', (
    tester,
  ) async {
    await pump(tester);
    // Not yet: it says so.
    await tester.tap(find.text("I'VE TURNED THEM OFF"));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('developer-mode-still-on')),
      findsOneWidget,
    );

    on = false;
    await tester.tap(find.text("I'VE TURNED THEM OFF"));
    await tester.pump();
    expect(find.text('TURN OFF DEVELOPER OPTIONS'), findsNothing);
    expect(find.text('Report a fire'), findsOneWidget);
  });

  testWidgets('it looks again each time the app comes back', (tester) async {
    on = false;
    await pump(tester);
    expect(find.text('TURN OFF DEVELOPER OPTIONS'), findsNothing);

    on = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('TURN OFF DEVELOPER OPTIONS'), findsOneWidget);
  });

  testWidgets('a debug build never asks', (tester) async {
    DeveloperMode.enforcedOverride = false;
    await pump(tester);
    expect(asked, 0);
    expect(find.text('Report a fire'), findsOneWidget);
  });

  test('under flutter test the real build is not enforced', () {
    DeveloperMode.enforcedOverride = null;
    expect(DeveloperMode.enforced, isFalse);
  });
}
