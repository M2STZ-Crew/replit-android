import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import 'app_icons.dart';
import 'map_glass.dart';
import 'map_marker.dart';

/// How a map's areas and its legend are drawn, for every role (DAWI "MAP |
/// LEGENDS"): an incident's radius in the fire's coral, a risk zone in red,
/// and the chips that switch the layers in each category's tone
/// ([MapMarkerKind.tone]). One definition, so the resident's, the
/// coordinator's and the responder's maps — and their chips — agree.
abstract final class MapAreas {
  /// Incident radius ("INCIDENT RADIUS | FIRE"): the coral at 10 % inside a
  /// 1 px coral edge at 80 %. [metres] is the caller's radius; this only
  /// paints it.
  static CircleMarker incidentRadius(
    AppPalette pal,
    LatLng centre, {
    required double metres,
  }) {
    final tone = MapMarkerKind.incident.tone(pal);
    return CircleMarker(
      point: centre,
      radius: metres,
      useRadiusInMeter: true,
      color: tone.withValues(alpha: 0.10),
      borderColor: tone.withValues(alpha: 0.8),
      borderStrokeWidth: 1,
    );
  }

  /// A risk zone's drawn area: red at 8 % inside a 1 px red edge at 45 %.
  /// [geojson] is the zone's Polygon or MultiPolygon as the server sends it
  /// (`area_geojson`); a zone without one draws nothing here and keeps its
  /// marker.
  static List<Polygon> riskZone(AppPalette pal, Object? geojson) {
    final tone = MapMarkerKind.risk.tone(pal);
    return [
      for (final shape in shapes(geojson))
        Polygon(
          points: shape.outer,
          holePointsList: shape.holes,
          color: tone.withValues(alpha: 0.08),
          borderColor: tone.withValues(alpha: 0.45),
          borderStrokeWidth: 1,
        ),
    ];
  }

  /// Polygon and MultiPolygon GeoJSON, as the server's ST_AsGeoJSON sends it.
  static List<({List<LatLng> outer, List<List<LatLng>> holes})> shapes(
    Object? geojson,
  ) {
    try {
      final g = geojson is String ? jsonDecode(geojson) : geojson;
      if (g is! Map) return const [];
      final coords = g['coordinates'] as List;
      final polygons = switch (g['type']) {
        'Polygon' => [coords],
        'MultiPolygon' => coords,
        _ => const <dynamic>[],
      };
      List<LatLng> ring(dynamic r) => [
        for (final c in r as List)
          LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
      return [
        for (final p in polygons.cast<List>())
          (outer: ring(p.first), holes: [for (final h in p.skip(1)) ring(h)]),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// A Map layers chip (04 · pass 2): a 36 px glass pill in a 44 px target. A
/// layer that is on is washed in its tone at 10 %, edged in it and checked,
/// so "on" never rests on colour alone; one that is off is plain glass with
/// its tone's dot. The label stays light either way.
class MapLayerChip extends StatelessWidget {
  const MapLayerChip({
    super.key,
    required this.label,
    required this.tone,
    required this.on,
    required this.onTap,
  });

  final String label;

  /// The layer's colour — [MapMarkerKind.tone] for its category.
  final Color tone;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final shape = BorderRadius.circular(AppRadius.chip);
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: on ? tone.withValues(alpha: 0.1) : MapGlass.glass(context),
        borderRadius: shape,
        border: Border.all(color: on ? tone : pal.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on)
            Icon(AppIcons.check, size: 14, color: tone)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: context.type.eyebrow.copyWith(
              color: on ? pal.onBackground : pal.label,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: ClipRRect(
            borderRadius: shape,
            child: MapGlass.blurs(context)
                ? BackdropFilter.grouped(filter: MapGlass.blur, child: pill)
                : pill,
          ),
        ),
      ),
    );
  }
}
