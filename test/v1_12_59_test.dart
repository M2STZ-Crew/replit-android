import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/models/area_view.dart';
import 'package:replit/models/fire_code_rules.dart';
import 'package:replit/screens/coordinator/codes_tab.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/code_confirm_sheet.dart';
import 'package:replit/widgets/coordinator_kit.dart';
import 'package:replit/widgets/motion.dart';
import 'package:replit/widgets/sheet_grip.dart';

/// v1.12.59 (22 Nov 2026): drawers slide down and close, a warning before
/// every fire code, responders' codes.
const double _statusBar = 32;

const _names = [
  'On Scene / Arrived',
  'Fire Under Control',
  'Fire Out',
  'Overhauling',
  'Returning to Station',
  'Water Supply Needed',
  'Additional Units Needed',
  'Possible Casualty',
];

void main() {
  late List<String> posted;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      const json = {'content-type': 'application/json'};
      if (request.method == 'POST') {
        posted.add(request.url.path);
        return http.Response(
          jsonEncode({
            'id': 'e1',
            'pressed_at': DateTime.now().toUtc().toIso8601String(),
            'pressed_by_name': 'Ana Cruz',
          }),
          201,
          headers: json,
        );
      }
      return http.Response(
        jsonEncode([
          for (var i = 0; i < _names.length; i++)
            {
              'id': 'c${i + 1}',
              'code_number': 'FC-${i + 1}',
              'name': _names[i],
              'description': 'What pressing it tells everyone on this fire',
              'display_order': i + 1,
              'is_active': true,
            },
        ]),
        200,
        headers: json,
      );
    }),
  );

  AreaView area({int presses = 0}) => AreaView({
    'id': 'a1',
    'designation': 'Near F. Victor Street',
    'status': 'arrived',
    'fire_codes': [
      for (var i = 0; i < presses; i++)
        {
          'code_number': 'FC-1',
          'name': 'On Scene / Arrived',
          'pressed_at': DateTime.now().toUtc().toIso8601String(),
          'pressed_by_name': 'Crew $i',
        },
    ],
  });

  setUp(() {
    posted = [];
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext) show, {
    Size size = const Size(360, 780),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: _statusBar, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: 24,
    );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> Function(BuildContext) codes({
    bool Function(String?)? allowed,
    int presses = 0,
  }) =>
      (context) => showFrameSheet<void>(
        context,
        builder: (_) => FireCodesSheet(
          api: api(),
          area: area(presses: presses),
          presses: true,
          allowed: allowed,
        ),
      );

  group('a long drawer', () {
    for (final size in const [Size(360, 780), Size(412, 915)]) {
      testWidgets('stops below the status bar at $size', (tester) async {
        await open(tester, codes(), size: size);
        final top = tester.getTopLeft(find.byType(SheetFrame)).dy;
        expect(top, greaterThanOrEqualTo(_statusBar));
        expect(
          size.height - top,
          lessThanOrEqualTo(size.height * kSheetMaxHeight + 0.5),
        );
        expect(
          tester.getTopLeft(find.byKey(SheetGrip.handleKey)).dy,
          greaterThan(_statusBar),
        );
      });
    }

    testWidgets('a pull down at the top of its list closes it', (tester) async {
      await open(tester, codes());
      await tester.flingFrom(
        const Offset(180, 400),
        const Offset(0, 300),
        1800,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SheetFrame), findsNothing);
      expect(find.text('open'), findsOneWidget, reason: 'back where it opened');
    });

    testWidgets('it follows the finger, and a small pull springs back', (
      tester,
    ) async {
      await open(tester, codes());
      final top = tester.getTopLeft(find.byType(SheetFrame)).dy;
      final finger = await tester.startGesture(const Offset(180, 400));
      await finger.moveBy(const Offset(0, 30));
      await finger.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byType(SheetFrame)).dy,
        greaterThan(top + 60),
      );
      await finger.up();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(SheetFrame)).dy,
        moreOrLessEquals(top, epsilon: 1),
      );
    });

    testWidgets('it still scrolls, and down again scrolls back first', (
      tester,
    ) async {
      await open(tester, codes(presses: 4));
      final row = find.text(_names[1]);
      final before = tester.getTopLeft(row).dy;
      await tester.dragFrom(const Offset(180, 500), const Offset(0, -250));
      await tester.pumpAndSettle();
      final scrolled = tester.getTopLeft(row).dy;
      expect(scrolled, lessThan(before - 100), reason: 'up scrolls the list');

      await tester.dragFrom(const Offset(180, 400), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(find.byType(SheetFrame), findsOneWidget, reason: 'not at the top');
      expect(tester.getTopLeft(row).dy, greaterThan(scrolled));
    });

    testWidgets('its handle closes it', (tester) async {
      await open(tester, codes());
      await tester.flingFrom(
        tester.getCenter(find.byKey(SheetGrip.handleKey)),
        const Offset(0, 300),
        1800,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SheetFrame), findsNothing);
    });

    testWidgets('Close closes it, for anyone who cannot swipe', (tester) async {
      await open(tester, codes());
      final close = find.byKey(FrozenHandleSheet.closeKey);
      expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(SheetFrame), findsNothing);
    });
  });

  testWidgets('a drawer that must be answered has no Close and stays', (
    tester,
  ) async {
    await open(
      tester,
      (context) => showAppSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => FrozenHandleSheet(
          children: [for (var i = 0; i < 60; i++) Text('Line $i')],
        ),
      ),
    );
    expect(find.byKey(FrozenHandleSheet.closeKey), findsNothing);
    await tester.flingFrom(const Offset(180, 300), const Offset(0, 300), 1800);
    await tester.pumpAndSettle();
    expect(find.byType(FrozenHandleSheet), findsOneWidget);
  });

  group('the fire code warning', () {
    Future<void> tapWater(WidgetTester tester) async {
      await tester.ensureVisible(find.text(_names[5]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_names[5]));
      await tester.pumpAndSettle();
    }

    testWidgets('a tap sends nothing until Send', (tester) async {
      await open(tester, codes());
      await tapWater(tester);
      expect(posted, isEmpty);
      expect(find.byType(CodeConfirmSheet), findsOneWidget);
      expect(
        find.textContaining('Fire Volunteer and BFP coordinators with a sound'),
        findsOneWidget,
      );
      await tester.pump(CodeConfirmSheet.armAfter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SEND FC-6'));
      await tester.pumpAndSettle();
      expect(posted, ['/fire-codes/c6/press']);
      expect(find.textContaining('FC-6 recorded at'), findsOneWidget);
      expect(find.textContaining('Ana Cruz'), findsOneWidget);
    });

    testWidgets('Cancel sends nothing', (tester) async {
      await open(tester, codes());
      await tapWater(tester);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(posted, isEmpty);
      expect(find.byType(FireCodesSheet), findsOneWidget);
    });

    testWidgets('a swipe away sends nothing', (tester) async {
      await open(tester, codes());
      await tapWater(tester);
      await tester.fling(
        find.byKey(SheetGrip.handleKey).last,
        const Offset(0, 300),
        1800,
      );
      await tester.pumpAndSettle();
      expect(posted, isEmpty);
      expect(find.byType(CodeConfirmSheet), findsNothing);
    });

    testWidgets("a double tap's second tap cannot land on Send", (
      tester,
    ) async {
      late BuildContext screen;
      await open(tester, (context) async => screen = context);
      final answer = confirmFireCode(
        screen,
        number: 'FC-8',
        name: 'Possible Casualty',
        fire: 'Near F. Victor Street',
      );
      // The sheet has just arrived (280 ms): the moment a double tap lands.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('SEND FC-8'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(CodeConfirmSheet), findsOneWidget);
      await tester.pump(CodeConfirmSheet.armAfter);
      await tester.pump();
      expect(find.byType(CodeConfirmSheet), findsOneWidget);
      await tester.tap(find.text('SEND FC-8'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets('at a large type size the buttons stack and fit', (
      tester,
    ) async {
      await open(
        tester,
        (context) => confirmFireCode(
          context,
          number: 'FC-6',
          name: 'Water Supply Needed',
          fire: 'Near F. Victor Street',
        ),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('CANCEL')).dy,
        greaterThan(tester.getTopLeft(find.text('SEND FC-6')).dy),
      );
      await tester.pump(CodeConfirmSheet.armAfter);
    });

    testWidgets('a code this responder may not press only reads', (
      tester,
    ) async {
      await open(tester, codes(allowed: (code) => code == 'FC-7'));
      await tester.ensureVisible(find.text(_names[1]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_names[1]));
      await tester.pumpAndSettle();
      expect(find.byType(CodeConfirmSheet), findsNothing);
    });

    testWidgets('every press is there, not only the latest five', (
      tester,
    ) async {
      await open(tester, codes(presses: 7));
      expect(find.textContaining('Crew 6'), findsNothing);
      await tester.ensureVisible(find.text('SHOW ALL 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHOW ALL 7'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Crew 6'), findsOneWidget);
    });
  });

  group('which codes a responder may press', () {
    final all = [for (var i = 1; i <= 8; i++) 'FC-$i'];
    List<String> may({
      required bool fireCrew,
      bool going = false,
      bool finished = false,
    }) => [
      for (final code in all)
        if (responderMayPress(
          code,
          fireCrew: fireCrew,
          going: going,
          finished: finished,
        ))
          code,
    ];

    test('a fire crew on it: every code', () {
      expect(may(fireCrew: true, going: true), all);
    });
    test('another crew on it: more units and a casualty', () {
      expect(may(fireCrew: false, going: true), ['FC-7', 'FC-8']);
    });
    test('nobody who is not on it', () {
      expect(may(fireCrew: true), isEmpty);
      expect(may(fireCrew: false), isEmpty);
    });
    test('after fire out, a fire crew overhauls and returns', () {
      expect(may(fireCrew: true, finished: true), ['FC-4', 'FC-5']);
      expect(may(fireCrew: false, finished: true), isEmpty);
    });
  });
}
