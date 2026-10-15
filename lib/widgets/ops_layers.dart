import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../models/facility.dart';
import '../theme.dart';
import 'map_marker.dart';

/// The operational map layers every staff dashboard draws — responder, Fire
/// Volunteer and BFP (Master Context v10 §2.4). One definition, where each of
/// the three used to carry its own copy.
///
/// Every layer here has data behind it (§2.7.1). The Response Teams, Hospital
/// and Barangay Hall chips the dashboards used to show had none — tapping them
/// only said "not in this build yet" — so they are left out until a source
/// exists.
///
/// Each layer's colour is its category's legend tone ([MapMarkerKind.tone]),
/// the same as on the resident's map: incidents coral, risk zones red, water
/// blue, shelters green.

/// A map point, and whether it is a shelter outside Pasay (§2.4), drawn as a
/// hollow ring with an outward arrow so the destination's distance reads at a
/// glance. A risk zone also carries its drawn [area] (GeoJSON), when the
/// server has one.
class OpsPoint {
  const OpsPoint(this.point, {this.outside = false, this.name, this.area});

  final LatLng point;
  final bool outside;

  /// The place's own name, for a screen reader and a list of what is near.
  final String? name;

  /// A risk zone's Polygon or MultiPolygon, as `area_geojson` sends it.
  final Object? area;
}

class OpsLayer {
  const OpsLayer(this.key, this.label, this.kind, this.load);

  final String key;
  final String label;

  /// The marker this layer's points wear, and so its legend tone. Null for
  /// the stations, which are plain dots in a neutral tone: they are neither
  /// a hazard nor a resource the legend colours.
  final MapMarkerKind? kind;

  /// Null for the incident layer, which each dashboard draws itself.
  final Future<List<OpsPoint>> Function()? load;

  /// The layer's colour on its chip and its points.
  Color colour(AppPalette pal) => kind?.tone(pal) ?? pal.textSoft;
}

List<OpsPoint> _points(
  List<dynamic> rows,
  String latKey,
  String lngKey, {
  String? areaKey,
}) => [
  for (final r in rows.cast<Map<String, dynamic>>())
    if (r[latKey] != null && r[lngKey] != null)
      OpsPoint(
        LatLng((r[latKey] as num).toDouble(), (r[lngKey] as num).toDouble()),
        name: r['name'] as String?,
        area: areaKey == null ? null : r[areaKey],
      ),
];

/// The layers, in chip order. 'incidents' is first and has no loader.
List<OpsLayer> opsLayers(ApiClient api) => [
  const OpsLayer('incidents', 'Incidents', MapMarkerKind.incident, null),
  OpsLayer('evac', 'Evacuation Sites', MapMarkerKind.shelter, () async {
    final rows = (await api.getEvacuationSites()).cast<Map<String, dynamic>>();
    return [
      for (final r in rows)
        if (r['latitude'] != null && r['longitude'] != null)
          OpsPoint(
            LatLng(
              (r['latitude'] as num).toDouble(),
              (r['longitude'] as num).toDouble(),
            ),
            outside: r['outside_pasay'] == true,
            name: r['name'] as String?,
          ),
    ];
  }),
  OpsLayer(
    'risk',
    'Risk Areas',
    MapMarkerKind.risk,
    () async => _points(
      await api.getRiskZones(),
      'centroid_lat',
      'centroid_lng',
      areaKey: 'area_geojson',
    ),
  ),
  OpsLayer(
    'hydrants',
    'Fire Hydrants',
    MapMarkerKind.hydrant,
    () async => _points(await api.getHydrants(), 'latitude', 'longitude'),
  ),
  OpsLayer(
    'water',
    'Bodies of Water',
    MapMarkerKind.water,
    () async => _points(await api.getBodiesOfWater(), 'latitude', 'longitude'),
  ),
  OpsLayer(
    'cisterns',
    'Cisterns',
    MapMarkerKind.cistern,
    () async =>
        _points(await api.getUndergroundCisterns(), 'latitude', 'longitude'),
  ),
  // Static reference lists held in the app — there is no station GIS table.
  OpsLayer(
    'fire',
    'Fire Department',
    null,
    () async => [for (final f in kFireStations) OpsPoint(LatLng(f.lat, f.lng))],
  ),
  OpsLayer(
    'police',
    'Police Department',
    MapMarkerKind.police,
    () async => [
      for (final f in kPoliceStations) OpsPoint(LatLng(f.lat, f.lng)),
    ],
  ),
];

/// The marker for one GIS point: the layer's map marker (04 · Map marker),
/// a shelter outside Pasay badged with an outward arrow; a station without a
/// marker kind is a small dot in the layer's tone.
Marker opsMarker(AppPalette pal, OpsLayer layer, OpsPoint p) {
  final kind = layer.kind;
  if (kind != null) {
    return Marker(
      point: p.point,
      width: MapMarker.target,
      height: MapMarker.target,
      child: MapMarker(
        kind: kind,
        label: p.name ?? layer.label,
        badge: p.outside ? const OutsidePasayBadge() : null,
      ),
    );
  }
  final tone = layer.colour(pal);
  return Marker(
    point: p.point,
    width: 16,
    height: 16,
    child: Semantics(
      label: layer.label,
      child: Container(
        decoration: BoxDecoration(
          color: tone,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
    ),
  );
}
