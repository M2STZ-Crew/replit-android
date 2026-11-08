import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/login_screen.dart';
import 'package:replit/theme.dart';

/// 8 November: "why the sign-in screen is scrollable? fix it". A fixed 120
/// above the title made the page a little taller than a phone with a wider
/// system font, so it scrolled. Now the room above the title gives way first
/// (FootedScroll.topRoom), and the page scrolls only when it cannot fit.
///
/// The test font draws every letter as a square, so lines wrap far more than
/// on a phone: these measure against the screen's own height, not fixed
/// sizes. With Roboto it fits a 393 × 780 screen up to a 1.2 font scale.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ApiClient api() => ApiClient(
    client: MockClient(
      (req) async => http.Response(jsonEncode({'status': 'ok'}), 200),
    ),
  );

  Future<ScrollPosition> open(
    WidgetTester tester,
    Size size, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
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
            child: LoginScreen(api: api()),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
  }

  double title(WidgetTester tester) =>
      tester.getTopLeft(find.text('WELCOME BACK')).dy;

  testWidgets('the room above the title gives way before the page scrolls', (
    tester,
  ) async {
    // Too short: no room above the title, and the page scrolls.
    var position = await open(tester, const Size(402, 600));
    expect(tester.takeException(), isNull);
    final over = position.maxScrollExtent;
    expect(over, greaterThan(0));
    expect(title(tester), 16);

    // Just tall enough, with 48 to spare: the spare goes above the title,
    // and nothing scrolls.
    position = await open(tester, Size(402, 600 + over + 48));
    expect(tester.takeException(), isNull);
    expect(position.maxScrollExtent, 0);
    expect(title(tester), 16 + 48);

    // Plenty of room: the title sits 120 down, as in the frame, and the
    // footer at the foot of the screen.
    const tall = 2000.0;
    position = await open(tester, const Size(402, tall));
    expect(position.maxScrollExtent, 0);
    expect(title(tester), 120);
    expect(
      tester.getBottomLeft(find.text('REGISTER HERE')).dy,
      inInclusiveRange(tall - 28 - 24, tall - 28),
    );
  });

  testWidgets('a very large font still scrolls, and nothing overflows', (
    tester,
  ) async {
    final position = await open(tester, const Size(402, 874), scale: 2);
    expect(tester.takeException(), isNull);
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.scrollUntilVisible(
      find.text('REGISTER HERE'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('REGISTER HERE'), findsOneWidget);
  });
}
