import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../models/facility.dart';
import '../theme.dart';

/// The operational map layers every staff dashboard draws — responder, Fire
/// Volunteer and BFP (Master Context v10 §2.4). One definition, where each of
/// the three used to carry its own copy.
///
/// Every layer here has data behind it (§2.7.1). The Response Teams, Hospital
/// and Barangay Hall chips the dashboards used to show had none — tapping them
/// only said "not in this build yet" — so they are left out until a source
/// exists.

/// A map point, and whether it is a shelter outside Pasay (§2.4), drawn as a
/// hollow ring with an outward arrow so the destination's distance reads at a
/// glance.
class OpsPoint {
  const OpsPoint(this.point, {this.outside = false});

  final LatLng point;
  final bool outside;
}

class OpsLayer {
  const OpsLayer(this.key, this.label, this.color, this.load);

  final String key;
  final String label;
  final Color color;

  /// Null for the incident layer, which each dashboard draws itself.
  final Future<List<OpsPoint>> Function()? load;
}

List<OpsPoint> _points(List<dynamic> rows, String latKey, String lngKey) => [
  for (final r in rows.cast<Map<String, dynamic>>())
    if (r[latKey] != null && r[lngKey] != null)
      OpsPoint(LatLng((r[latKey] as num).toDouble(), (r[lngKey] as num).toDouble())),
];

/// The layers, in chip order. 'incidents' is first and has no loader.
List<OpsLayer> opsLayers(ApiClient api) => [
  const OpsLayer('incidents', 'Incidents', AppColors.live, null),
  OpsLayer('evac', 'Evacuation Sites', AppColors.ok, () async {
    final rows = (await api.getEvacuationSites()).cast<Map<String, dynamic>>();
    return [
      for (final r in rows)
        if (r['latitude'] != null && r['longitude'] != null)
          OpsPoint(
            LatLng((r['latitude'] as num).toDouble(), (r['longitude'] as num).toDouble()),
            outside: r['outside_pasay'] == true,
          ),
    ];
  }),
  OpsLayer('risk', 'Risk Areas', AppColors.accent,
      () async => _points(await api.getRiskZones(), 'centroid_lat', 'centroid_lng')),
  OpsLayer('hydrants', 'Fire Hydrants', AppColors.muted,
      () async => _points(await api.getHydrants(), 'latitude', 'longitude')),
  OpsLayer('water', 'Bodies of Water', const Color(0xFF4EA8FF),
      () async => _points(await api.getBodiesOfWater(), 'latitude', 'longitude')),
  OpsLayer('cisterns', 'Cisterns', const Color(0xFF9A8CFF),
      () async => _points(await api.getUndergroundCisterns(), 'latitude', 'longitude')),
  // Static reference lists held in the app — there is no station GIS table.
  OpsLayer('fire', 'Fire Department', AppColors.live,
      () async => [for (final f in kFireStations) OpsPoint(LatLng(f.lat, f.lng))]),
  OpsLayer('police', 'Police Department', AppColors.info,
      () async => [for (final f in kPoliceStations) OpsPoint(LatLng(f.lat, f.lng))]),
];

/// The marker for one GIS point: a small dot, or for a shelter outside Pasay
/// a hollow ring with an outward arrow.
Marker opsMarker(OpsLayer layer, OpsPoint p) {
  if (p.outside) {
    return Marker(
      point: p.point,
      width: 20,
      height: 20,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSolid,
          shape: BoxShape.circle,
          border: Border.all(color: layer.color, width: 2.5),
        ),
        child: Icon(Icons.north_east_rounded, size: 10, color: layer.color),
      ),
    );
  }
  return Marker(
    point: p.point,
    width: 16,
    height: 16,
    child: Container(
      decoration: BoxDecoration(
        color: layer.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      ),
    ),
  );
}
