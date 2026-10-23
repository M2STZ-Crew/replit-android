import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/api/push_service.dart';

/// The banner a push shows while the app is open ("Help is on the way",
/// OPEN) goes away by itself after 10 s, tapped or not (24 Oct 2026).
void main() {
  Future<GlobalKey<ScaffoldMessengerState>> pump(WidgetTester tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: key,
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    return key;
  }

  Future<void> show(
    WidgetTester tester,
    GlobalKey<ScaffoldMessengerState> key, {
    VoidCallback? onOpen,
    bool fire = false,
  }) async {
    key.currentState!.showSnackBar(
      PushService.inAppBanner(
        title: 'Help is on the way',
        body:
            'Responders are on the way to the fire you reported. Open RepLiT '
            'to see them.',
        fire: fire,
        onOpen: onOpen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750)); // slides in
  }

  testWidgets('with OPEN untapped, it is gone after 10 s', (tester) async {
    final key = await pump(tester);
    var opened = 0;
    await show(tester, key, onOpen: () => opened++);
    expect(find.text('Help is on the way'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    expect(
      find.text('Help is on the way'),
      findsOneWidget,
      reason: 'still up before 10 s',
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 750)); // slides out
    expect(find.text('Help is on the way'), findsNothing);
    expect(opened, 0);
  });

  testWidgets('a new fire goes away after 10 s too', (tester) async {
    final key = await pump(tester);
    await show(tester, key, fire: true, onOpen: () {});
    await tester.pump(PushService.bannerFor);
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('Help is on the way'), findsNothing);
  });

  testWidgets('OPEN still opens it', (tester) async {
    final key = await pump(tester);
    var opened = 0;
    await show(tester, key, onOpen: () => opened++);
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    expect(opened, 1);
  });
}
