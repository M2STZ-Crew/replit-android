import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/models/guide_article.dart';
import 'package:replit/models/hotline.dart';
import 'package:replit/screens/call_screen.dart';
import 'package:replit/screens/guide_detail_screen.dart';
import 'package:replit/screens/guide_screen.dart';
import 'package:replit/screens/home_screen.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/screens/national_id_screen.dart';
import 'package:replit/screens/register_screen.dart';
import 'package:replit/theme.dart';

/// Guards on the screens ported to the "General User App v2" design.
///
/// These exist because of two real bugs that shipped to a handset and that
/// `flutter analyze` cannot see:
///
///   * the SOS screen threw on build — two AnimationControllers on a
///     SingleTickerProviderStateMixin;
///   * the splash footer ran off both edges of the screen at the larger system
///     font scales people actually use.
///
/// So every screen here is pumped for real, at the design's own viewport, at
/// normal scale and again at 1.5x.
void main() {
  /// The 402x874 frame the hand-off is drawn at.
  const designSize = Size(402, 874);

  // The MediaQuery has to be *derived* from the real one, not built fresh: a
  // bare MediaQueryData carries a zero size and zero padding, which makes
  // anything reading them lay out wrongly and reports overflows that are the
  // test's fault rather than the screen's.
  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
    theme: buildAppTheme(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(child, textScale: textScale));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('screens build and fit', () {
    // 1.0 is the default; 1.5 is roughly the largest a phone's display
    // settings offer, and is where the splash footer broke.
    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('SOS screen at ${scale}x', (tester) async {
        await pump(tester, const HomeScreen(), textScale: scale);
        // Would have caught the SingleTickerProviderStateMixin crash.
        expect(tester.takeException(), isNull);
        expect(find.text('SOS'), findsWidgets);
      });

      testWidgets('hotlines at ${scale}x', (tester) async {
        await pump(tester, const CallScreen(), textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('CALL FOR HELP'), findsOneWidget);
      });

      testWidgets('guides at ${scale}x', (tester) async {
        await pump(tester, const GuideScreen(), textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('SAFETY GUIDES'), findsOneWidget);
      });

      testWidgets('login at ${scale}x', (tester) async {
        await pump(tester, const LoginScreen(), textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('WELCOME BACK'), findsOneWidget);
      });

      testWidgets('sign up at ${scale}x', (tester) async {
        await pump(tester, const RegisterScreen(), textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('WHO ARE YOU?'), findsOneWidget);
      });

      testWidgets('national ID at ${scale}x', (tester) async {
        await pump(tester, const NationalIdScreen(), textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('VERIFY YOUR IDENTITY'), findsOneWidget);
        // Camera-only, deliberately: a gallery pick is how someone submits
        // an ID that is not theirs. Nothing on this screen may offer one.
        expect(find.textContaining('gallery', findRichText: true), findsNothing);
        expect(find.textContaining('choose'), findsNothing);
        expect(find.textContaining('Choose'), findsNothing);
      });

      testWidgets('a guide article at ${scale}x', (tester) async {
        // The longest article is the one most likely to overflow.
        final longest = kGuideArticles.reduce(
          (a, b) => a.sections.length >= b.sections.length ? a : b,
        );
        await pump(
          tester,
          GuideDetailScreen(article: longest),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(longest.title.toUpperCase()), findsOneWidget);
      });
    }
  });

  group('hotline directory', () {
    test('every number reduces to something dialable', () {
      for (final hotline in kHotlines) {
        expect(
          hotline.dialNumber,
          matches(RegExp(r'^\+?\d{3,}$')),
          reason: '${hotline.name} has an undialable number',
        );
      }
    });

    test('911 is featured, so it survives every filter', () {
      final national = kHotlines.firstWhere((h) => h.dialNumber == '911');
      expect(national.featured, isTrue);
    });

    test('no two entries dial the same number', () {
      final numbers = kHotlines.map((h) => h.dialNumber).toList();
      expect(numbers.toSet(), hasLength(numbers.length));
    });
  });

  group('guide content', () {
    test('every guide has sections with points', () {
      for (final guide in kGuideArticles) {
        expect(guide.sections, isNotEmpty, reason: guide.title);
        for (final section in guide.sections) {
          expect(section.points, isNotEmpty, reason: guide.title);
        }
      }
    });

    test('both categories have at least one guide', () {
      // The GUIDES tab opens the first guide of a category inline; an empty
      // category would render a featured card with nothing in it.
      for (final category in [kCatFire, kCatHealth]) {
        expect(
          kGuideArticles.where((g) => g.category == category),
          isNotEmpty,
          reason: category,
        );
      }
    });
  });

  group('design tokens', () {
    test('every area_status has its own colour', () {
      const statuses = [
        'pending', 'verified', 'dispatched', 'en_route',
        'arrived', 'resolved', 'rejected', 'merged',
      ];
      final seen = <Color>{};
      for (final status in statuses) {
        final color = AppColors.forStatus(status);
        // Falling through to muted would silently erase the difference
        // between, say, "resolved" and "rejected" on a card.
        expect(color, isNot(AppColors.muted), reason: status);
        seen.add(color);
      }
      expect(seen, hasLength(greaterThanOrEqualTo(6)));
    });

    test('an unknown status is muted rather than throwing', () {
      expect(AppColors.forStatus(null), AppColors.muted);
      expect(AppColors.forStatus('something_new'), AppColors.muted);
    });
  });
}
