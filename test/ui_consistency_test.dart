import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/location/place_names.dart';
import 'package:replit/models/hotline.dart';
import 'package:replit/screens/call_screen.dart';
import 'package:replit/screens/coordinator/coordinator_shell.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/app_icons.dart';
import 'package:replit/widgets/app_nav_bar.dart';
import 'package:replit/widgets/coordinator_kit.dart';
import 'package:replit/widgets/design.dart';
import 'package:replit/widgets/map_layers.dart';
import 'package:replit/widgets/map_marker.dart';

/// One look across the roles: the map legend's colours, the disc in the
/// middle of every bar, a settings row at rest, and the hotlines' glyphs.
void main() {
  const pal = AppPalette.dark;

  setUpAll(() {
    // The maps' tile cache asks for a cache folder; tests have no plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaceNames.clear();
    PlaceNames.lookUp = (_, _) async => const PlaceName(street: 'Taft Ave');
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: home));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  const coordinator = {
    'id': 'me',
    'role': 'sub_admin',
    'agency_type': 'fire_volunteer',
    'organization_name': 'Pasay Fire Volunteers',
    'full_name': 'R. Alonzo',
  };

  ApiClient api() => ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      if (path == '/incidents') {
        return http.Response(
          jsonEncode([
            {
              'id': 'a1',
              'designation': 'Area 1.2',
              'status': 'en_route',
              'centroid_lat': 14.5378,
              'centroid_lng': 121.0014,
              'report_count': 3,
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    }),
  );

  group('the map legend', () {
    test('incidents are coral and risk zones red, on every map', () {
      expect(MapMarkerKind.incident.tone(pal), pal.accentInk);
      expect(MapMarkerKind.risk.tone(pal), pal.live);
      for (final water in [
        MapMarkerKind.hydrant,
        MapMarkerKind.water,
        MapMarkerKind.cistern,
      ]) {
        expect(water.tone(pal), pal.water);
      }
      expect(MapMarkerKind.shelter.tone(pal), pal.ok);
    });

    test(
      'an incident radius and a risk zone are drawn from the same tones',
      () {
        final radius = MapAreas.incidentRadius(
          pal,
          const LatLng(14.5, 121),
          metres: 300,
        );
        expect(radius.color, pal.accentInk.withValues(alpha: 0.10));
        expect(radius.borderColor, pal.accentInk.withValues(alpha: 0.8));
        expect(radius.borderStrokeWidth, 1);
        expect(radius.radius, 300, reason: 'the caller keeps its radius');

        final zone = MapAreas.riskZone(pal, {
          'type': 'Polygon',
          'coordinates': [
            [
              [121.0, 14.5],
              [121.001, 14.5],
              [121.001, 14.501],
              [121.0, 14.5],
            ],
          ],
        });
        expect(zone, hasLength(1));
        expect(zone.single.color, pal.live.withValues(alpha: 0.08));
        expect(zone.single.borderColor, pal.live.withValues(alpha: 0.45));
      },
    );

    testWidgets('the coordinator map: Areas coral, risk zones red, and the '
        'radius in the Areas colour', (tester) async {
      await pump(tester, CoordinatorShell(me: coordinator, api: api()));
      await tester.tap(find.bySemanticsLabel(RegExp('^Map, tab ')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      MapLayerChip chip(String label) => tester.widget<MapLayerChip>(
        find.byWidgetPredicate(
          (w) => w is MapLayerChip && w.label == label,
          skipOffstage: false,
        ),
      );
      expect(chip('Areas').tone, pal.accentInk);
      expect(chip('Risk zones').tone, pal.live);
      expect(chip('Hydrants').tone, pal.water);
      expect(chip('Shelters').tone, pal.ok);
      final circles = tester
          .widget<CircleLayer>(find.byType(CircleLayer))
          .circles;
      expect(circles.single.color, pal.accentInk.withValues(alpha: 0.10));
      expect(circles.single.borderColor, pal.accentInk.withValues(alpha: 0.8));
      await done(tester);
    });
  });

  group('a settings row at rest', () {
    testWidgets('"You can accept and reject" wears the hairline, not the '
        'selected edge', (tester) async {
      await pump(tester, CoordinatorShell(me: coordinator, api: api()));
      await tester.tap(find.bySemanticsLabel(RegExp('^Profile, tab ')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final row = find.widgetWithText(ListRow, 'You can accept and reject');
      final ink = tester.widget<Ink>(
        find.descendant(of: row, matching: find.byType(Ink)),
      );
      final border = (ink.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, pal.line);
      expect(border.top.width, 1);
      await done(tester);
    });

    testWidgets('focus is a ring outside the row, and only from a keyboard', (
      tester,
    ) async {
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      Container ringBox() => tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ListRow),
              matching: find.byType(Container),
            )
            .first,
      );
      Future<void> focusWith(FocusHighlightStrategy strategy) async {
        FocusManager.instance.highlightStrategy = strategy;
        await pump(
          tester,
          Scaffold(
            // A fresh row each time, so focus starts nowhere.
            key: UniqueKey(),
            body: ListRow(title: 'Map rotation', onTap: () {}),
          ),
        );
        expect(ringBox().foregroundDecoration, isNull, reason: 'at rest');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      // Focused by touch (or programmatically, after a tap): no ring, and no
      // fill that could read as a selection.
      await focusWith(FocusHighlightStrategy.alwaysTouch);
      expect(ringBox().foregroundDecoration, isNull);

      // From a keyboard or switch: the coral ring, outside the row.
      await focusWith(FocusHighlightStrategy.alwaysTraditional);
      final ring = ringBox().foregroundDecoration! as BoxDecoration;
      expect((ring.border! as Border).top.color, pal.focusRing);
      expect(
        (ring.border! as Border).top.strokeAlign,
        BorderSide.strokeAlignOutside,
      );
    });

    testWidgets('a button disabled mid-press does not come back pressed', (
      tester,
    ) async {
      var busy = false;
      late StateSetter set;
      await pump(
        tester,
        Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, s) {
                set = s;
                return AppButton(
                  'Save',
                  busy: busy,
                  onPressed: () => s(() => busy = true),
                );
              },
            ),
          ),
        ),
      );
      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      final press = await tester.startGesture(
        tester.getCenter(find.byType(AppButton)),
      );
      await tester.pump();
      expect(scale(), 0.97);
      // It saves: busy while the pointer is still down, so the press's
      // Listener goes away before the release arrives.
      set(() => busy = true);
      await tester.pump();
      await press.up();
      set(() => busy = false);
      await tester.pumpAndSettle();
      expect(scale(), 1, reason: 'idle again, not still scaled down');
    });
  });

  group('the disc', () {
    BoxDecoration disc(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is DecoratedBox &&
                        w.decoration is BoxDecoration &&
                        (w.decoration as BoxDecoration).gradient ==
                            AppColors.accentGradient &&
                        (w.decoration as BoxDecoration).shape ==
                            BoxShape.circle,
                  ),
                )
                .decoration
            as BoxDecoration;

    Future<void> bar(WidgetTester tester, String word) => pump(
      tester,
      Scaffold(
        bottomNavigationBar: NavBarShell(
          disc: word,
          discActive: false,
          onDisc: () {},
          items: [
            for (final label in ['A', 'B', word, 'D', 'E'])
              (icon: AppIcons.map, label: label, selected: false, onTap: () {}),
          ],
        ),
      ),
    );

    testWidgets('SOS, LIVE and RUN are one disc: size, glow and label', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(bottomNavigationBar: AppNavBar(active: AppTab.map)),
      );
      final sos = disc(tester);
      final sosSize = tester.getSize(
        find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration == sos),
      );
      expect(sos.boxShadow, isNotEmpty, reason: 'the SOS glow');

      for (final word in ['LIVE', 'RUN']) {
        await bar(tester, word);
        final other = disc(tester);
        expect(other.boxShadow, sos.boxShadow, reason: word);
        expect(other.border, sos.border, reason: word);
        expect(
          tester.getSize(
            find.byWidgetPredicate(
              (w) => w is DecoratedBox && w.decoration == other,
            ),
          ),
          sosSize,
          reason: word,
        );
        final label = tester.widget<Text>(find.text(word));
        expect(label.style, AppText.actionRun, reason: word);
      }
    });
  });

  group('the hotlines', () {
    testWidgets('every row draws a filled glyph from the icon font, never a '
        'logo bitmap', (tester) async {
      await pump(tester, const CallScreen());
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      for (final h in kHotlines) {
        expect(h.icon.fontFamily, 'AppSymbols', reason: h.name);
      }
      // No two agencies share the generic phone glyph any more.
      expect(kHotlines.where((h) => h.icon == AppIcons.call), isEmpty);
      await done(tester);
    });
  });
}
