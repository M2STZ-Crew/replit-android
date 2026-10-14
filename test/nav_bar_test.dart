import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/app_icons.dart';
import 'package:replit/widgets/app_nav_bar.dart';

/// The tab bar's selected state (REPLIT (MAIN) 04 · Nav tab, pass 3): one
/// destination at a time, shown by a pill with a coral edge, a bright filled
/// glyph and a bold label — and announced as selected, not only drawn.
void main() {
  Future<void> pumpBar(WidgetTester tester, AppTab active) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(bottomNavigationBar: AppNavBar(active: active)),
      ),
    );
  }

  testWidgets('every tab draws its filled glyph from the icon font', (
    tester,
  ) async {
    await pumpBar(tester, AppTab.map);
    for (final icon in [
      AppIcons.map,
      AppIcons.call,
      AppIcons.description,
      AppIcons.person,
    ]) {
      expect(find.byIcon(icon), findsOneWidget);
      expect(icon.fontFamily, 'AppSymbols');
    }
    expect(find.byType(Image), findsNothing, reason: 'no bitmap glyphs');
  });

  testWidgets('the selected tab, and only it, sits in the pill', (
    tester,
  ) async {
    await pumpBar(tester, AppTab.hotlines);
    expect(find.byKey(const ValueKey('nav-pill')), findsOneWidget);
    final pill = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('nav-pill')),
    );
    final box = pill.decoration! as BoxDecoration;
    expect((box.border! as Border).top.color, AppPalette.dark.accent);
    expect((box.border! as Border).top.width, 1.5);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nav-pill')),
        matching: find.byIcon(AppIcons.call),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a screen reader hears which tab is selected and where', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, AppTab.guides);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Guides, tab 4 of 5')),
      matchesSemantics(
        label: 'Guides, tab 4 of 5',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Map, tab 1 of 5')),
      matchesSemantics(
        label: 'Map, tab 1 of 5',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('SOS — hold to report'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('on the SOS screen no tab is selected and the disc is ringed', (
    tester,
  ) async {
    await pumpBar(tester, AppTab.sos);
    expect(find.byKey(const ValueKey('nav-pill')), findsNothing);
    final ring = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('nav-disc-ring')),
    );
    expect(ring.opacity, 1);

    await pumpBar(tester, AppTab.map);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('nav-disc-ring')))
          .opacity,
      0,
    );
  });

  testWidgets('under reduced motion the selection changes at once', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpBar(tester, AppTab.map);
    final pill = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('nav-pill')),
    );
    expect(pill.duration, Duration.zero);
  });

  testWidgets('holds at 1.5x text on a 320 px phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const Scaffold(
            bottomNavigationBar: AppNavBar(active: AppTab.profile),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
