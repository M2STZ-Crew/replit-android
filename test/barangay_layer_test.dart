import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/api/map_cache.dart';
import 'package:replit/models/area_view.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/barangay_layer.dart';

/// v1.12.57 (backend v1.12.45), 19 Nov 2026: every fire in its barangay, and
/// "barangay map outline ... displayed as a clean layer so you can
/// color-code and highlight fire risk zones", with Pasay's eight High zones,
/// research-based, never a BFP designation.
const _centre = LatLng(14.5378, 121.0014);

String _square(LatLng c, [double d = 0.0025]) => jsonEncode({
  'type': 'MultiPolygon',
  'coordinates': [
    [
      [
        [c.longitude - d, c.latitude - d],
        [c.longitude + d, c.latitude - d],
        [c.longitude + d, c.latitude + d],
        [c.longitude - d, c.latitude + d],
        [c.longitude - d, c.latitude - d],
      ],
    ],
  ],
});

Map<String, dynamic> _barangay(
  String number,
  int zone,
  LatLng at, {
  bool high = false,
}) => {
  'pcode': 'PH13076050$number',
  'name': 'Barangay $number',
  'kind': 'numbered',
  'number': number,
  'zone': zone,
  'district': null,
  'city': 'Pasay',
  'area_geojson': _square(at),
  'risk': high
      ? {
          'zone_id': zone,
          'level': 'High',
          'label': 'High fire-risk zone (research-based)',
          'official_bfp_designation': false,
        }
      : null,
};

final _rows = [
  _barangay('76', 10, _centre),
  _barangay('51', 8, const LatLng(14.5428, 121.0014), high: true),
];

Future<void> _pumpMap(
  WidgetTester tester, {
  required double zoom,
  required bool outlines,
  required bool risk,
  LatLng centre = _centre,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pal = AppPalette.dark;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: FlutterMap(
          // A new map each time: a map keeps its first camera.
          key: UniqueKey(),
          options: MapOptions(initialCenter: centre, initialZoom: zoom),
          children: [
            BarangayLayer(
              shapes: BarangayShapes.from(_rows, pal),
              outlines: outlines,
              risk: risk,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Iterable<PolygonLayer<String>> _layers(WidgetTester tester) =>
    tester.widgetList<PolygonLayer<String>>(find.byType(PolygonLayer<String>));

void main() {
  test('a barangay is said the way a fire’s full place says it', () {
    expect(barangayPlace(_rows.first), 'Barangay 76 Zone 10, Pasay');
    expect(
      barangayPlace({
        'name': 'Barangay 70',
        'kind': 'numbered',
        'zone': 6,
        'district': 'Tondo',
        'city': 'Manila',
      }),
      'Barangay 70 Zone 6, Tondo, Manila',
    );
    expect(
      barangayPlace({'name': 'Bel-Air', 'kind': 'named', 'city': 'Makati'}),
      'Bel-Air, Makati',
    );
  });

  test('every barangay has an outline; only the High zones are filled', () {
    final shapes = BarangayShapes.from(_rows, AppPalette.dark);
    expect(shapes.outlines, hasLength(2));
    expect(shapes.highRisk, hasLength(1));
    expect(shapes.highRisk.single.hitValue, 'Barangay 51 Zone 8, Pasay');
    expect(shapes.highRisk.single.color, isNotNull);
    expect(shapes.outlines.first.color, isNull, reason: 'outlines only');
  });

  testWidgets('outlines wait for street level; the High zones show always', (
    tester,
  ) async {
    await _pumpMap(tester, zoom: 12, outlines: true, risk: true);
    expect(_layers(tester).map((l) => l.polygons.length), [1]);

    await _pumpMap(tester, zoom: 15, outlines: true, risk: true);
    expect(_layers(tester).map((l) => l.polygons.length), [2, 1]);

    await _pumpMap(tester, zoom: 15, outlines: false, risk: false);
    expect(_layers(tester), isEmpty);
  });

  testWidgets('a tap on a High zone says what it is', (tester) async {
    await _pumpMap(
      tester,
      zoom: 15,
      outlines: false,
      risk: true,
      centre: const LatLng(14.5428, 121.0014),
    );
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump();
    expect(
      find.text(
        'Barangay 51 Zone 8, Pasay · High fire-risk zone (research-based)',
      ),
      findsOneWidget,
    );
  });

  test('the layer is kept on the phone for offline maps', () {
    expect(MapCache.layers, contains('barangays'));
  });

  test("an incident's full place comes from the server when it has one", () {
    final named = AreaView({
      'id': 'a1',
      'designation': 'Near F. Victor St., Brgy 76, Pasay',
      'place_line': 'Near F. Victor Street, Barangay 76 Zone 10, Pasay',
    });
    expect(
      named.placeLine,
      'Near F. Victor Street, Barangay 76 Zone 10, Pasay',
    );
    expect(named.name, 'Near F. Victor St., Brgy 76, Pasay');
    final older = AreaView({'id': 'a2', 'designation': 'Near Taft Avenue'});
    expect(older.placeLine, isNull);
  });
}
