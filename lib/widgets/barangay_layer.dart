import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../i18n/i18n.dart';
import '../theme.dart';
import 'map_layers.dart';
import 'map_marker.dart';

/// The barangay layer (v1.12.57, backend v1.12.45; 19 Nov 2026: "barangay
/// map outline refers to the exact geographic boundary lines (polygons) of
/// each barangay, displayed as a clean layer so you can color-code and
/// highlight fire risk zones").
///
/// GET /map/barangays sends Metro Manila's 1,712 PSA/NAMRIA outlines, and on
/// the 86 of Pasay's eight High zones a `risk`. Two chips on every map:
/// Barangays draws each border, dashed, from [outlineMinZoom] in (all of
/// them at once would be a tangle); High fire risk fills the High zones at
/// every zoom, "research-based", never a BFP designation, and a tap on one
/// says so. The admin-drawn Risk zones are their own layer.

/// The chips' keys on every map.
const String kBarangaysLayer = 'barangays';
const String kFireRiskLayer = 'fireRisk';

/// What the map calls a High zone (the user's risk file).
String highRiskLabel() => t('High fire-risk zone (research-based)');

/// "Barangay 76 Zone 10, Pasay", "Barangay 70 Zone 6, Tondo, Manila",
/// "Bel-Air, Makati": the full form a fire's place uses.
String barangayPlace(Map<String, dynamic> row) {
  final name = (row['name'] as String?) ?? '';
  final zone = row['zone'];
  final full = row['kind'] == 'numbered' && zone != null
      ? '$name Zone $zone'
      : name;
  return [
    full,
    ?row['district'] as String?,
    ?row['city'] as String?,
  ].where((s) => s.isNotEmpty).join(', ');
}

/// The outlines' dash: 6 px drawn, 4 px gap.
final StrokePattern _dashed = StrokePattern.dashed(segments: const [6, 4]);

/// The layer's polygons, made once from the rows (rebuilding 1,712 polygons
/// on every frame would make the map stutter).
class BarangayShapes {
  BarangayShapes._(this.outlines, this.highRisk);

  factory BarangayShapes.from(List<Map<String, dynamic>> rows, AppPalette pal) {
    final edge = MapMarkerKind.barangay.tone(pal);
    final risk = MapMarkerKind.risk.tone(pal);
    final outlines = <Polygon<String>>[];
    final highRisk = <Polygon<String>>[];
    for (final row in rows) {
      final place = barangayPlace(row);
      final high = row['risk'] is Map;
      for (final shape in MapAreas.shapes(row['area_geojson'])) {
        outlines.add(
          Polygon<String>(
            points: shape.outer,
            holePointsList: shape.holes,
            borderColor: edge.withValues(alpha: 0.85),
            borderStrokeWidth: 1.2,
            pattern: _dashed,
            hitValue: place,
          ),
        );
        if (high) {
          highRisk.add(
            Polygon<String>(
              points: shape.outer,
              holePointsList: shape.holes,
              color: risk.withValues(alpha: 0.16),
              borderColor: risk.withValues(alpha: 0.9),
              borderStrokeWidth: 1.5,
              hitValue: place,
            ),
          );
        }
      }
    }
    return BarangayShapes._(outlines, highRisk);
  }

  static final BarangayShapes empty = BarangayShapes._(const [], const []);

  final List<Polygon<String>> outlines;
  final List<Polygon<String>> highRisk;
}

/// A FlutterMap child: the outlines from [outlineMinZoom] in when [outlines]
/// is on, the High zones when [risk] is on.
class BarangayLayer extends StatefulWidget {
  const BarangayLayer({
    super.key,
    required this.shapes,
    required this.outlines,
    required this.risk,
  });

  final BarangayShapes shapes;
  final bool outlines;
  final bool risk;

  /// About a district across: closer than this the borders are worth
  /// reading.
  static const double outlineMinZoom = 13;

  @override
  State<BarangayLayer> createState() => _BarangayLayerState();
}

class _BarangayLayerState extends State<BarangayLayer> {
  final LayerHitNotifier<String> _hits = ValueNotifier(null);

  @override
  void dispose() {
    _hits.dispose();
    super.dispose();
  }

  void _tell() {
    final place = _hits.value?.hitValues.firstOrNull;
    if (place == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$place · ${highRiskLabel()}')));
  }

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    final outlines =
        widget.outlines && zoom >= BarangayLayer.outlineMinZoom;
    final risk = widget.risk && widget.shapes.highRisk.isNotEmpty;
    if (!outlines && !risk) return const SizedBox.shrink();
    return Stack(
      children: [
        if (outlines)
          PolygonLayer<String>(
            polygons: widget.shapes.outlines,
            simplificationTolerance: 1,
          ),
        if (risk)
          GestureDetector(
            onTap: _tell,
            child: PolygonLayer<String>(
              polygons: widget.shapes.highRisk,
              hitNotifier: _hits,
            ),
          ),
      ],
    );
  }
}
