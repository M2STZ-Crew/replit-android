import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/api/tracking_socket.dart';
import 'package:replit/i18n/i18n.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/screens/live_update_screen.dart';
import 'package:replit/screens/report_status_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/alarm_status_banner.dart';
import 'package:replit/widgets/design.dart';
import 'package:replit/widgets/sheet_grip.dart';

import 'real_font.dart';

/// v1.12.61 (23 November 2026): "put the alarm level between incident
/// lifecycle and who acknowledge it" and "don't remove that circle with
/// percentage"; answered "A. Becomes title", "Only if needed", "Small badge"
/// and "Only this one".
///
/// Measured in Inter, as screen_fit_test.dart is.
const _me = 'resident@example.com';
const _place = 'Near Tayuman St., Brgy 229, Tondo';

/// The phone it was reported from: 360 × 819, a 36 status bar, small type.
const _phone = Size(360, 819);

typedef _Fire = ({String status, String? level, bool held});

const _Fire _reported = (status: 'reported', level: null, held: false);
const _Fire _confirmed = (
  status: 'verified',
  level: 'positive_fire_alarm',
  held: false,
);
const _Fire _raised = (status: 'en_route', level: 'third_alarm', held: false);
const _Fire _general = (status: 'arrived', level: 'general_alarm', held: false);
const _Fire _held = (status: 'arrived', level: 'second_alarm', held: true);
const _Fire _out = (status: 'fire_out', level: 'general_alarm', held: false);

const _stages = [_reported, _confirmed, _raised, _general, _held, _out];

class _Feed implements TrackingFeed {
  final StreamController<Map<String, dynamic>> pushes =
      StreamController.broadcast();

  @override
  final ValueListenable<bool> live = ValueNotifier(false);
  @override
  final ValueListenable<bool> denied = ValueNotifier(false);
  @override
  Stream<Map<String, dynamic>> get snapshots => pushes.stream;
  @override
  void start() {}
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> _snapshot(_Fire fire) {
  final now = DateTime.now().toUtc();
  final acked = fire.status != 'reported';
  return {
    'area_id': 'a1',
    'designation': _place,
    'status': fire.status,
    'centroid_lat': 14.6155,
    'centroid_lng': 120.9822,
    'generated_at': now.toIso8601String(),
    'responders': const <Object>[],
    'alarm_level': fire.level,
    if (fire.held) 'under_control_at': now.toIso8601String(),
    if (acked) 'verified_by': 'BFP Pasay',
    if (acked) 'verified_by_agency': 'bfp',
    if (acked) 'verified_at': now.toIso8601String(),
  };
}

/// Answers for [fire] as it is when asked, so a test can move it along.
ApiClient _api(_Fire Function() fire) => ApiClient(
  client: MockClient((req) async {
    final now = fire();
    final path = req.url.path;
    final Object body;
    if (path.endsWith('/tracking')) {
      body = _snapshot(now);
    } else if (path.endsWith('/reports/mine') ||
        path.endsWith('/map/evacuation-sites')) {
      body = const <Object>[];
    } else {
      body = {
        'id': 'a1',
        'designation': _place,
        'status': now.status,
        'report_count': 1,
        'centroid_lat': 14.6155,
        'centroid_lng': 120.9822,
        'reported_at': DateTime.now()
            .subtract(const Duration(minutes: 3))
            .toUtc()
            .toIso8601String(),
        'alarm_level': now.level,
        if (now.held)
          'under_control_at': DateTime.now().toUtc().toIso8601String(),
        if (now.status == 'arrived') ...{
          'fire_type': 'structural',
          'fire_subtype': 'residential',
          'fire_type_org_name': 'BFP Pasay',
        },
      };
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  Size size = _phone,
  double top = 36,
  double bottom = 0,
  double scale = 0.85,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(key: UniqueKey(), theme: buildAppTheme(), home: screen),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _helping(_Fire Function() fire) => ReportStatusScreen.of(
  ActiveReport(
    owner: _me,
    reportId: 'r1',
    areaId: 'a1',
    designation: _place,
    lat: 14.6155,
    lng: 120.9822,
    submittedAt: DateTime.now(),
    agencies: const ['fire_volunteer'],
  ),
  status: fire().status,
  api: _api(fire),
);

Widget _tracking(_Fire Function() fire, [_Feed? feed]) => LiveUpdateScreen(
  areaId: 'a1',
  lat: 14.6155,
  lng: 120.9822,
  api: _api(fire),
  feed: feed ?? _Feed(),
);

double _pageScroll(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .maxScrollExtent;

Finder _ring() => find.byType(CircularProgressIndicator);

Finder _grip() => find.byKey(SheetGrip.handleKey);

Future<void> _pullDown(WidgetTester tester) async {
  await tester.drag(_grip(), const Offset(0, 500), warnIfMissed: false);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Everything a screen reader is told.
String _readOut(WidgetTester tester) {
  final out = StringBuffer();
  void visit(SemanticsNode node) {
    out.writeln(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(Scaffold).first));
  return out.toString();
}

void main() {
  setUpAll(loadAppFont);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = _me;
  });
  tearDown(() => LanguageChoice.current.value = AppLanguage.en);

  group('"Getting you help"', () {
    const phones = [
      (Size(360, 600), 24.0, 0.0),
      (Size(360, 640), 24.0, 0.0),
      (Size(360, 720), 30.0, 0.0),
      (Size(360, 800), 30.0, 48.0),
      (_phone, 36.0, 0.0),
      (Size(393, 851), 36.0, 0.0),
      (Size(412, 915), 36.0, 0.0),
    ];
    for (final language in AppLanguage.values) {
      for (final (size, top, bottom) in phones) {
        testWidgets('keeps the circle without scrolling, every stage: '
            '${size.width.round()} × ${size.height.round()}, '
            '${language.label}', (tester) async {
          LanguageChoice.current.value = language;
          for (final scale in [0.85, 1.0, 1.15]) {
            for (final fire in _stages) {
              // At a type over the standard, only with an alarm: before one
              // the paragraph is there, and was let scroll on a short phone.
              if (scale > 1 && fire.level == null) continue;
              await _open(
                tester,
                _helping(() => fire),
                size: size,
                top: top,
                bottom: bottom,
                scale: scale,
              );
              final at = '${fire.status} at $scale';
              expect(tester.takeException(), isNull, reason: at);
              expect(_ring(), findsOneWidget, reason: at);
              expect(
                tester.getSize(_ring()).width,
                greaterThanOrEqualTo(50),
                reason: at,
              );
              expect(_pageScroll(tester), lessThan(0.5), reason: at);
            }
          }
        });
      }
    }

    testWidgets('at a very large type it scrolls, and keeps the circle', (
      tester,
    ) async {
      await _open(
        tester,
        _helping(() => _general),
        size: const Size(360, 600),
        top: 24,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(_pageScroll(tester), greaterThan(0));
      expect(_ring(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('TRACK IT LIVE'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('TRACK IT LIVE').hitTestable(), findsOneWidget);
    });

    testWidgets('the alarm is the title, above the circle', (tester) async {
      await _open(tester, _helping(() => _general));
      expect(find.byType(AlarmStatusTitle), findsOneWidget);
      expect(find.byType(AlarmStatusBanner), findsNothing);
      expect(find.text('GENERAL ALARM'), findsOneWidget);
      expect(find.text('REPORT SENT · GETTING YOU HELP'), findsOneWidget);
      expect(find.text('GETTING YOU HELP'), findsNothing);
      expect(find.textContaining('You do not need to'), findsNothing);

      final eyebrow = tester.getBottomLeft(
        find.text('REPORT SENT · GETTING YOU HELP'),
      );
      final title = tester.getRect(find.byType(AlarmStatusTitle));
      expect(title.top, greaterThan(eyebrow.dy));
      expect(tester.getRect(_ring()).top, greaterThan(title.bottom));
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('ON SCENE'), findsOneWidget);
    });

    testWidgets('no alarm yet: the title and paragraph as before', (
      tester,
    ) async {
      await _open(tester, _helping(() => _reported));
      expect(find.byType(AlarmStatusTitle), findsNothing);
      expect(find.text('GETTING YOU HELP'), findsOneWidget);
      expect(find.text('REPORT SENT'), findsOneWidget);
      expect(find.textContaining('You do not need to'), findsOneWidget);
    });

    testWidgets('under control is a title too', (tester) async {
      await _open(tester, _helping(() => _held));
      expect(find.byType(AlarmStatusTitle), findsOneWidget);
      expect(find.text('UNDER CONTROL'), findsOneWidget);
    });

    testWidgets('fire out says so once, with no second banner', (tester) async {
      await _open(tester, _helping(() => _out));
      expect(find.byType(AlarmStatusTitle), findsNothing);
      expect(find.byType(AlarmStatusBanner), findsNothing);
      expect(find.text('REPORT DONE'), findsOneWidget);
    });

    testWidgets('the alarm becomes the title when it is set', (tester) async {
      var fire = _reported;
      await _open(tester, _helping(() => fire));
      expect(find.byType(AlarmStatusTitle), findsNothing);
      final before = tester.getSize(_ring()).width;

      fire = _confirmed;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('POSITIVE FIRE ALARM'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(_ring(), findsOneWidget);
      expect(tester.getSize(_ring()).width, closeTo(before, 24));
    });

    testWidgets('on the phone it was reported from, every step keeps both '
        'lines', (tester) async {
      await _open(tester, _helping(() => _general));
      for (final line in [
        'Photo and GPS stored',
        'A new incident — the first report here',
        'Neighbours within 100 m were alerted too',
        'Responders reached the scene',
        'Responders are working on it',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
    });

    testWidgets('a smaller phone folds the finished steps, as little as it '
        'takes', (tester) async {
      await _open(
        tester,
        _helping(() => _general),
        size: const Size(360, 640),
        top: 24,
        scale: 1,
      );
      expect(find.text('Photo and GPS stored'), findsNothing);
      expect(find.text('Responders reached the scene'), findsNothing);
      // The current one keeps its line; every step keeps its name.
      expect(find.text('Responders are working on it'), findsOneWidget);
      for (final name in [
        'Report received',
        'Responders notified',
        'Accepted',
        'Fire out',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });

    testWidgets('before anyone is on scene, the last step reached keeps its '
        'line', (tester) async {
      await _open(
        tester,
        _helping(() => _raised),
        size: const Size(360, 600),
        top: 24,
        scale: 1,
      );
      expect(find.text('Photo and GPS stored'), findsNothing);
      expect(find.text('Responders are on the way'), findsOneWidget);
    });

    testWidgets('only the form on screen is read out', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _helping(() => _general));
      final said = _readOut(tester);
      expect('Report received'.allMatches(said), hasLength(1));
      expect(said, contains('GENERAL ALARM'));
      expect(said, contains('90 percent'));
      semantics.dispose();
    });

    testWidgets('the circle names its stage in Tagalog', (tester) async {
      LanguageChoice.current.value = AppLanguage.tl;
      await _open(tester, _helping(() => _confirmed));
      expect(find.text('NA-ACKNOWLEDGE'), findsOneWidget);
    });
  });

  group('FirstThatFits', () {
    Widget forms(double room, void Function(String) pressed) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 200, maxHeight: room),
          child: FirstThatFits(
            children: [
              for (final (name, height) in [
                ('roomy', 300.0),
                ('folded', 200.0),
                ('card', 100.0),
              ])
                GestureDetector(
                  onTap: () => pressed(name),
                  child: Container(
                    height: height,
                    color: Colors.black,
                    child: Text(name),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    for (final (room, shown) in [
      (400.0, 'roomy'),
      (300.0, 'roomy'),
      (250.0, 'folded'),
      (120.0, 'card'),
      (60.0, 'card'),
    ]) {
      testWidgets('$room shows and presses $shown', (tester) async {
        String? pressed;
        await tester.pumpWidget(forms(room, (name) => pressed = name));
        expect(tester.takeException(), isNull);
        for (final name in ['roomy', 'folded', 'card']) {
          expect(
            find.text(name),
            name == shown ? findsOneWidget : findsNothing,
            reason: name,
          );
        }
        await tester.tapAt(const Offset(20, 20));
        expect(pressed, shown);
      });
    }
  });

  group('Track it live', () {
    for (final (size, scale) in [(_phone, 0.85), (const Size(402, 874), 1.0)]) {
      testWidgets('status, fire type, stages, alarm, who acknowledged: '
          '${size.width.round()} × ${size.height.round()}', (tester) async {
        await _open(
          tester,
          _tracking(() => _general),
          size: size,
          scale: scale,
        );
        double y(Finder finder) => tester.getTopLeft(finder).dy;
        final order = [
          y(find.text('STATUS')),
          y(find.text('ON SCENE')),
          y(find.byKey(const ValueKey('resident-fire-type'))),
          y(find.text('Reported')),
          y(find.byType(AlarmStatusBanner)),
          y(find.text('Acknowledged by BFP Pasay')),
        ];
        for (var i = 1; i < order.length; i++) {
          expect(order[i], greaterThan(order[i - 1]), reason: '$i: $order');
        }
        // All of it in view when the sheet is open, without scrolling.
        expect(find.text('GENERAL ALARM').hitTestable(), findsOneWidget);
        expect(find.byType(AlarmBadge), findsNothing);
        await _close(tester);
      });
    }

    testWidgets('pulled down, the badge takes the time\'s place', (
      tester,
    ) async {
      await _open(tester, _tracking(() => _general));
      expect(find.text('Reported 3 min ago'), findsOneWidget);

      await _pullDown(tester);
      final badge = find.descendant(
        of: find.byType(AlarmBadge),
        matching: find.text('GENERAL ALARM'),
      );
      expect(badge.hitTestable(), findsOneWidget);
      expect(tester.getRect(badge).bottom, lessThanOrEqualTo(_phone.height));
      expect(find.text('Reported 3 min ago'), findsNothing);
      expect(find.text('ON SCENE'), findsOneWidget);

      await tester.drag(_grip(), const Offset(0, -500), warnIfMissed: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AlarmBadge), findsNothing);
      expect(find.text('Reported 3 min ago'), findsOneWidget);
      await _close(tester);
    });

    for (final language in AppLanguage.values) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'the longest badge is in view at $scale, ${language.label}',
          (tester) async {
            LanguageChoice.current.value = language;
            await _open(
              tester,
              _tracking(() => _confirmed),
              size: const Size(360, 640),
              top: 24,
              bottom: 24,
              scale: scale,
            );
            await _pullDown(tester);
            expect(tester.takeException(), isNull);
            final badge = find.byType(AlarmBadge);
            expect(badge, findsOneWidget);
            // Above the navigation bar.
            expect(tester.getRect(badge).bottom, lessThanOrEqualTo(640 - 24));
            await _close(tester);
          },
        );
      }
    }

    testWidgets('folded from a scrolled list, the status line comes back', (
      tester,
    ) async {
      await _open(tester, _tracking(() => _general));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final list = tester.widget<ListView>(find.byType(ListView)).controller!;
      expect(list.offset, greaterThan(0));

      await tester.tap(_grip(), warnIfMissed: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(list.offset, 0);
      expect(tester.getTopLeft(_grip()).dy, greaterThan(_phone.height - 130));
      expect(find.byType(AlarmBadge).hitTestable(), findsOneWidget);
      await _close(tester);
    });

    testWidgets('no alarm yet: the time stays when pulled down', (
      tester,
    ) async {
      await _open(tester, _tracking(() => _reported));
      await _pullDown(tester);
      expect(find.byType(AlarmBadge), findsNothing);
      expect(find.text('Reported 3 min ago'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('a raise shows on the badge at once', (tester) async {
      final feed = _Feed();
      await _open(tester, _tracking(() => _confirmed, feed));
      await _pullDown(tester);
      expect(
        find.descendant(
          of: find.byType(AlarmBadge),
          matching: find.text('POSITIVE FIRE ALARM'),
        ),
        findsOneWidget,
      );

      feed.pushes.add(_snapshot(_general));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byType(AlarmBadge),
          matching: find.text('GENERAL ALARM'),
        ),
        findsOneWidget,
      );
      await _close(tester);
    });
  });

  group('permissions', () {
    test('neither the microphone nor storage is declared', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('xmlns:tools='));
      for (final name in ['RECORD_AUDIO', 'WRITE_EXTERNAL_STORAGE']) {
        expect(
          manifest,
          contains(
            '<uses-permission android:name="android.permission.$name" '
            'tools:node="remove"/>',
          ),
        );
      }
    });

    test('and no camera records sound, which would need the microphone', () {
      for (final screen in ['camera_capture_screen', 'id_camera_screen']) {
        final code = File('lib/screens/$screen.dart').readAsStringSync();
        expect(code, contains('enableAudio: false'));
        expect(code, isNot(contains('enableAudio: true')));
      }
    });
  });
}
