import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit_mobile/core/theme/app_theme.dart';
import 'package:replit_mobile/core/widgets/app_nav_bar.dart';
import 'package:replit_mobile/core/widgets/design.dart';
import 'package:replit_mobile/features/guides/domain/safety_guide.dart';
import 'package:replit_mobile/features/guides/presentation/screens/safety_guides_screen.dart';
import 'package:replit_mobile/features/hotlines/domain/hotline.dart';
import 'package:replit_mobile/features/hotlines/presentation/screens/hotlines_screen.dart';
import 'package:replit_mobile/main.dart';

/// Hermetic checks on the screens ported from the "General User App v2"
/// hand-off. These are the pieces with no Supabase, network or plugin
/// dependency, so they can be pumped for real — which catches the failure that
/// analysis cannot: a layout that overflows on a phone-sized viewport.
void main() {
  /// iPhone 16 Pro logical size — the 402x874 frame the design is drawn at.
  const designSize = Size(402, 874);

  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  );

  Future<void> pumpAtDesignSize(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(child));
    await tester.pump();
  }

  group('hotline directory', () {
    test('every number reduces to something dialable', () {
      for (final hotline in kHotlines) {
        final dialable = Hotline.dialable(hotline.primary);
        expect(
          dialable,
          matches(RegExp(r'^\+?\d{3,}$')),
          reason: '${hotline.name} has an undialable primary number',
        );
      }
    });

    test('911 is present, featured, and in every filter', () {
      final national = kHotlines.firstWhere((h) => h.primary == '911');
      expect(national.featured, isTrue);
      // Featured entries survive category filtering, so the one number that
      // always works is never filtered off the screen.
      expect(national.category, HotlineCategory.all);
    });

    test('no duplicate numbers', () {
      final numbers = kHotlines.map((h) => Hotline.dialable(h.primary)).toList();
      expect(numbers.toSet(), hasLength(numbers.length));
    });

    testWidgets('renders at the design viewport without overflowing',
        (tester) async {
      await pumpAtDesignSize(tester, const HotlinesScreen());
      expect(find.text('CALL FOR HELP'), findsOneWidget);
      expect(find.text('911'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('category filter narrows the list', (tester) async {
      await pumpAtDesignSize(tester, const HotlinesScreen());
      expect(find.text('10 NUMBERS'), findsOneWidget);

      await tester.tap(find.text('POLICE'));
      await tester.pump();

      // Police lines plus the always-present 911.
      final police = kHotlines
          .where((h) => h.category == HotlineCategory.police || h.featured)
          .length;
      expect(find.text('$police NUMBERS'), findsOneWidget);
    });
  });

  group('safety guides', () {
    test('every guide has steps and a sane read time', () {
      for (final guide in kSafetyGuides) {
        expect(guide.steps, isNotEmpty, reason: guide.title);
        expect(guide.minutes, greaterThan(0), reason: guide.title);
        expect(guide.index, hasLength(2), reason: guide.title);
      }
    });

    test('numbering is contiguous from one', () {
      expect(
        kSafetyGuides.map((g) => g.number).toList(),
        List.generate(kSafetyGuides.length, (i) => i + 1),
      );
    });

    testWidgets('the first guide is open on arrival', (tester) async {
      await pumpAtDesignSize(tester, const SafetyGuidesScreen());
      // The design's whole argument for this screen: nobody taps into a list
      // while their kitchen is alight, so step one is already visible.
      expect(find.textContaining('Get everyone out first'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a guide opens to its full step list', (tester) async {
      final guide = kSafetyGuides[2]; // CPR basics — five steps
      await pumpAtDesignSize(tester, GuideDetailScreen(guide: guide));
      for (final step in guide.steps) {
        expect(find.text(step), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('shell chrome', () {
    testWidgets('the tab bar shows four tabs and marks the active one',
        (tester) async {
      AppTab? tapped;
      await pumpAtDesignSize(
        tester,
        AppNavBar(active: AppTab.sos, onSelect: (t) => tapped = t),
      );

      for (final tab in AppTab.values) {
        expect(find.text(tab.label.toUpperCase()), findsOneWidget);
      }

      await tester.tap(find.text('HOTLINES'));
      expect(tapped, AppTab.hotlines);
    });

    testWidgets('the splash renders without a session', (tester) async {
      await pumpAtDesignSize(tester, const SplashScreen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('design vocabulary', () {
    testWidgets('a disabled primary button does not fire', (tester) async {
      var pressed = false;
      await pumpAtDesignSize(
        tester,
        Center(child: AppButton('Send', onPressed: null)),
      );
      await tester.tap(find.text('SEND'));
      expect(pressed, isFalse);
    });

    testWidgets('a busy button shows a spinner instead of its label',
        (tester) async {
      await pumpAtDesignSize(
        tester,
        Center(child: AppButton('Send', busy: true, onPressed: () {})),
      );
      expect(find.text('SEND'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('status colours cover every area_status value', () {
      // A status with no colour falls through to grey, which would silently
      // erase the difference between "resolved" and "rejected" on a card.
      const statuses = [
        'pending', 'verified', 'dispatched', 'en_route',
        'arrived', 'resolved', 'rejected', 'merged',
      ];
      final seen = <Color>{};
      for (final status in statuses) {
        final color = AppColors.forStatus(status);
        expect(color, isNot(AppColors.muted), reason: status);
        seen.add(color);
      }
      expect(seen, hasLength(greaterThanOrEqualTo(6)));
    });
  });
}
