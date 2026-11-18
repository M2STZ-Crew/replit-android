import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/map_layer_gate.dart';

/// v1.12.50 (18 Nov 2026, Metro Manila's 3,100 points): "Only nearby, when
/// zoomed in". A layer's points are drawn from street level in; zoomed out,
/// the map says to zoom in.
void main() {
  Future<MapController> show(WidgetTester tester, double zoom) async {
    final map = MapController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: const LatLng(14.5378, 121.0014),
              initialZoom: zoom,
            ),
            children: [
              ZoomGatedMarkers(
                markers: [
                  for (var i = 0; i < 3; i++)
                    Marker(
                      point: LatLng(14.5378 + i * 0.0005, 121.0014),
                      child: Text('hydrant $i'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return map;
  }

  testWidgets('zoomed out: no points, and a hint to zoom in', (tester) async {
    await show(tester, 12);
    expect(find.textContaining('hydrant'), findsNothing);
    expect(
      find.text('Zoom in to see the places you turned on'),
      findsOneWidget,
    );
  });

  testWidgets('from street level in: the points, and no hint', (tester) async {
    final map = await show(tester, 12);
    map.move(const LatLng(14.5378, 121.0014), kLayerMinZoom);
    await tester.pump();
    expect(find.textContaining('hydrant'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('zoom-in-hint')), findsNothing);
  });
}
