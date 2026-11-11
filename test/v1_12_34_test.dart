import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/models/area_view.dart';
import 'package:replit/models/field_ops.dart';
import 'package:replit/screens/edit_profile_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/theme_choice.dart';
import 'package:replit/widgets/drag_down_sheet.dart';
import 'package:replit/widgets/fire_type_row.dart';
import 'package:replit/widgets/report_fire_button.dart';
import 'package:replit/widgets/theme_picker.dart';

/// App v1.12.34 (12 November 2026), with backend v1.12.27.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  group('what is burning', () {
    test('a subtype goes to the server in its own words', () {
      expect(fireSubtypeWire('High-tension wire'), 'high_tension_wire');
      expect(fireSubtypeWire('Entrance wire'), 'entrance_wire');
      expect(fireSubtypeWire('E-bike'), 'e_bike');
      expect(fireSubtypeWire('SUV'), 'suv');
      expect(
        const FireClassification(FireType.structural, 'Residential').toJson(),
        {'fire_type': 'structural', 'fire_subtype': 'residential'},
      );
      expect(const FireClassification(FireType.grass).toJson(), {
        'fire_type': 'grass',
        'fire_subtype': null,
      });
    });

    test('no Agricultural (PRD v14)', () {
      expect(
        FireType.values.expand((t) => t.subtypes).map((s) => s.toLowerCase()),
        isNot(contains('agricultural')),
      );
    });

    test('an incident says what is burning, or nothing yet', () {
      final set = AreaView({
        'id': 'a1',
        'status': 'arrived',
        'fire_type': 'electrical',
        'fire_subtype': 'high_tension_wire',
      });
      expect(set.fireType?.label, 'Electrical — High-tension wire');
      expect(set.onScene, isTrue);
      expect(AreaView({'id': 'a1', 'status': 'arrived'}).fireType, isNull);
      expect(AreaView({'id': 'a1', 'status': 'en_route'}).onScene, isFalse);
      // Only a server that asks gets asked: v1.12.27 sends the key.
      expect(set.asksFireType, isTrue);
      expect(
        AreaView({
          'id': 'a1',
          'status': 'arrived',
          'fire_type': null,
        }).asksFireType,
        isTrue,
      );
      expect(AreaView({'id': 'a1', 'status': 'arrived'}).asksFireType, isFalse);
      // A subtype this build does not list still reads.
      expect(
        AreaView({
          'id': 'a1',
          'fire_type': 'vehicular',
          'fire_subtype': 'jeepney',
        }).fireType?.label,
        'Vehicular — jeepney',
      );
    });

    test('the answer is posted to the incident', () async {
      late http.Request sent;
      final api = ApiClient(
        client: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode({'id': 'a1'}), 200);
        }),
      );
      await api.setFireType(
        'a1',
        const FireClassification(FireType.vehicular, 'E-bike'),
      );
      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/incidents/a1/fire-type'));
      expect(jsonDecode(sent.body), {
        'fire_type': 'vehicular',
        'fire_subtype': 'e_bike',
      });
    });

    testWidgets('unanswered, the row asks in red; answered, it names it', (
      tester,
    ) async {
      var asked = 0;
      await pump(
        tester,
        FireTypeRow(
          area: AreaView({'id': 'a1', 'status': 'arrived'}),
          onPick: () => asked++,
        ),
      );
      expect(find.text('What’s burning?'), findsOneWidget);
      expect(
        find.text('Required on scene. Pick the fire type.'),
        findsOneWidget,
      );
      await tester.tap(find.text('What’s burning?'));
      expect(asked, 1);

      await pump(
        tester,
        FireTypeRow(
          area: AreaView({
            'id': 'a1',
            'status': 'arrived',
            'fire_type': 'structural',
            'fire_subtype': 'commercial',
          }),
        ),
      );
      expect(find.text('Fire type'), findsOneWidget);
      expect(find.text('Structural — Commercial'), findsOneWidget);
    });
  });

  group('staff report a fire', () {
    testWidgets('the button says what it does', (tester) async {
      await pump(tester, const Center(child: ReportFireButton()));
      expect(find.text('REPORT A FIRE'), findsOneWidget);
      expect(find.bySemanticsLabel('Report a fire'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('report-fire'))).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('System, Light or Dark', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ThemeChoice.reset();
      ThemeChoice.phoneBrightness = () => Brightness.dark;
    });

    testWidgets('the Theme row opens the picker, and a pick applies', (
      tester,
    ) async {
      await ThemeChoice.load();
      await pump(tester, ListView(children: const [ThemeRow()]));
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('THEME'), findsOneWidget);
      for (final word in ['System', 'Light', 'Dark']) {
        expect(find.text(word), findsWidgets);
      }
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();
      expect(ThemeChoice.pick.value, ThemePick.light);
      expect(find.text('THEME'), findsNothing, reason: 'it closes on a pick');
    });
  });

  group('the trip panel folds itself while driving', () {
    Widget sheet({Duration? after, bool moving = false}) => Align(
      alignment: Alignment.bottomCenter,
      child: DragDownSheet(
        key: const ValueKey('sheet'),
        autoFoldAfter: after,
        moving: moving,
        header: const SizedBox(height: 40, child: Text('HEADER')),
        body: const SizedBox(height: 200, child: Text('BODY')),
        frame: (context, content) => content,
      ),
    );

    DragDownSheetState state(WidgetTester tester) =>
        tester.state(find.byKey(const ValueKey('sheet')));

    testWidgets('three seconds after it opens', (tester) async {
      await pump(tester, sheet(after: const Duration(seconds: 3)));
      expect(state(tester).isOpen, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(state(tester).isOpen, isTrue);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(state(tester).isOpen, isFalse);

      // Swiped back up, it stays up for three seconds more.
      state(tester).toggle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(state(tester).isOpen, isTrue);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(state(tester).isOpen, isFalse);
    });

    testWidgets('at once when the vehicle moves', (tester) async {
      await pump(tester, sheet(after: const Duration(seconds: 3)));
      expect(state(tester).isOpen, isTrue);
      await pump(
        tester,
        sheet(after: const Duration(seconds: 3), moving: true),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(state(tester).isOpen, isFalse);
    });

    testWidgets('and not at all when it is not asked to', (tester) async {
      await pump(tester, sheet());
      await tester.pump(const Duration(seconds: 10));
      expect(state(tester).isOpen, isTrue);
    });
  });

  test('a date of birth is 18 or older', () {
    expect(latestBirthday(DateTime(2026, 11, 12)), DateTime(2008, 11, 12));
    expect(latestBirthday(DateTime(2026, 2, 28)), DateTime(2008, 2, 28));
  });

  test('the server refusing an under-18 is said in the app', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'underage',
            'message': 'You must be 18 or older to use RepLiT.',
            'details': {'field': 'date_of_birth', 'minimum_age': 18},
          }),
          400,
        ),
      ),
    );
    await expectLater(
      api.updateProfile(dateOfBirth: '2010-01-01'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'underage')
            .having(
              (e) => e.message,
              'message',
              'You must be 18 or older to use RepLiT.',
            ),
      ),
    );
  });
}
