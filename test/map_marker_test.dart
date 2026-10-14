import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/theme.dart';
import 'package:replit/widgets/app_icons.dart';
import 'package:replit/widgets/map_marker.dart';

/// The map marker (REPLIT (MAIN) 04 · Map marker, pass 3): a white filled
/// glyph on the 700 step of its category, a white edge, a ground plate, a
/// 48 px target and a name — never colour alone.
void main() {
  Future<void> pump(WidgetTester tester, Widget marker) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Center(child: marker)),
      ),
    );
  }

  testWidgets('a white glyph on the category surface, edged in white', (
    tester,
  ) async {
    await pump(
      tester,
      const MapMarker(kind: MapMarkerKind.hydrant, label: 'Taft Avenue'),
    );
    final glyph = tester.widget<Icon>(find.byIcon(AppIcons.fireHydrant));
    expect(glyph.color, Colors.white);
    expect(glyph.size, 20);
    final square = tester.widget<Container>(
      find
          .ancestor(of: find.byType(Icon), matching: find.byType(Container))
          .first,
    );
    final box = square.decoration! as BoxDecoration;
    expect(box.color, const Color(0xFF4168AE), reason: 'water 700');
    expect((box.border! as Border).top.color, Colors.white);
    expect((box.border! as Border).top.width, 1.5);
  });

  testWidgets('selected grows to 40 px with a 24 px glyph', (tester) async {
    await pump(
      tester,
      const MapMarker(
        kind: MapMarkerKind.incident,
        label: 'Area 1.2',
        selected: true,
      ),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).size, 24);
    expect(
      tester.getSize(
        find
            .ancestor(of: find.byType(Icon), matching: find.byType(Container))
            .first,
      ),
      const Size(40, 40),
    );
  });

  testWidgets('every marker answers taps over 48 x 48 and has a name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pump(
      tester,
      MapMarker(
        kind: MapMarkerKind.shelter,
        label: 'Pasay City Hall',
        onTap: () => taps++,
      ),
    );
    expect(tester.getSize(find.byType(MapMarker)), const Size(48, 48));
    // A corner of the target, outside the 32 px square, still opens it.
    final corner =
        tester.getTopLeft(find.byType(MapMarker)) + const Offset(3, 3);
    await tester.tapAt(corner);
    expect(taps, 1);
    expect(find.bySemanticsLabel('Shelter, Pasay City Hall'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a live Area pulses, and stops under reduced motion', (
    tester,
  ) async {
    await pump(
      tester,
      const MapMarker(kind: MapMarkerKind.incident, label: 'A', live: true),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(
      tester,
      const MapMarker(kind: MapMarkerKind.incident, label: 'B', live: true),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('every kind keeps its glyph readable on its surface (>= 3 : 1)', () {
    for (final kind in MapMarkerKind.values) {
      final l = kind.surface.computeLuminance();
      final ratio = (1.0 + 0.05) / (l + 0.05);
      expect(ratio, greaterThanOrEqualTo(3.0), reason: kind.name);
    }
  });
}
