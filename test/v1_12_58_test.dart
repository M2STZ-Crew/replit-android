import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/screens/coordinator/codes_tab.dart';
import 'package:replit/screens/coordinator/coordinator_shell.dart';
import 'package:replit/screens/responder/responder_shell.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/fire_ripple.dart';
import 'package:replit/widgets/map_marker.dart';
import 'package:replit/widgets/ops_layers.dart';

/// v1.12.58 (backend v1.12.46), 20 Nov 2026: fire codes shown and heard, a
/// 100 m ripple on every fire, gray hydrants until checked, Report in the
/// staff bars.
const _fire = LatLng(14.5378, 121.0014);

Future<void> _pumpRipple(WidgetTester tester, {bool still = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: _fire, initialZoom: 16),
            children: const [
              FireRipple(centres: [_fire]),
            ],
          ),
        ),
      ),
    ),
  );
}

double _radius(WidgetTester tester) =>
    tester.widget<CircleLayer>(find.byType(CircleLayer)).circles.single.radius;

void main() {
  testWidgets('a fire ripples out to 100 m and starts again', (tester) async {
    await _pumpRipple(tester);
    final start = _radius(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    final later = _radius(tester);
    expect(later, greaterThan(start));
    expect(later, lessThanOrEqualTo(FireRipple.metres));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_radius(tester), lessThan(later), reason: 'a new ring');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no ripple where the phone removes animations', (tester) async {
    await _pumpRipple(tester, still: true);
    expect(find.byType(CircleLayer), findsNothing);
  });

  test('a hydrant unchecked for 6 months is gray; a checked one is not', () {
    final hydrants = opsLayers(
      ApiClient(),
    ).firstWhere((l) => l.key == 'hydrants');
    MapMarker marker(bool verified) =>
        opsMarker(
              AppPalette.dark,
              hydrants,
              OpsPoint(
                _fire,
                row: {'id': 'h1', 'code': 'H-1', 'verified': verified},
              ),
            ).child
            as MapMarker;
    expect(marker(false).muted, isTrue);
    expect(marker(true).muted, isFalse);
  });

  testWidgets('a gray marker wears the gray, not its category', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Center(
          child: MapMarker(
            kind: MapMarkerKind.hydrant,
            label: 'H-1',
            muted: true,
          ),
        ),
      ),
    );
    final squares = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color);
    expect(squares, contains(MapMarker.mutedSurface));
    expect(squares, isNot(contains(MapMarkerKind.hydrant.surface)));
  });

  test('Report sits beside Profile on both staff bars', () {
    expect(CoordinatorTab.values.map((t) => t.label), [
      'Queue',
      'Map',
      'LIVE',
      'Report',
      'Profile',
    ]);
    expect(ResponderTab.values.map((t) => t.label), [
      'Duty',
      'Map',
      'RUN',
      'Report',
      'Profile',
    ]);
  });

  test('a fire code alert opens its incident for staff', () {
    const staff = {'role': 'sub_admin', 'agency_type': 'bfp'};
    const resident = {'role': 'general_user'};
    expect(targetFor('fire_code', staff), NotificationTarget.staffIncident);
    expect(targetFor('fire_code', resident), NotificationTarget.none);
  });

  test('a press reads as code, name, when and who', () {
    final line = codeLine({
      'code_number': 'FC-6',
      'name': 'Water Supply Needed',
      'pressed_at': DateTime.now()
          .subtract(const Duration(minutes: 3))
          .toUtc()
          .toIso8601String(),
      'pressed_by_name': 'Ana Cruz',
    });
    expect(line, 'FC-6 · Water Supply Needed · 3 min ago · Ana Cruz');
  });
}
