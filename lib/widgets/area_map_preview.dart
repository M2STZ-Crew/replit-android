import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import 'coordinator_kit.dart';
import 'map_marker.dart';
import 'map_tiles.dart';

/// The map extract on an Area's detail (06 · C04, C07): each Area's centre as
/// a selected incident marker inside its 300 m radius (Area radius: the tone
/// at 10 % with a 1 px tone outline), framed to fit. A picture, not a map to
/// work in — it takes no gestures, so the page scrolls over it.
class AreaMapPreview extends StatelessWidget {
  const AreaMapPreview({
    super.key,
    required this.centres,
    this.height = 150,
    this.label = 'Incident',
  });

  final List<LatLng> centres;
  final double height;

  /// What a screen reader calls each marker.
  final String label;

  /// The centres' bounds, grown by a little more than the radius.
  static LatLngBounds _around(List<LatLng> centres) {
    const geo = Distance();
    const reach = kAreaRadiusMetres * 1.3;
    final points = [
      for (final c in centres) ...[
        geo.offset(c, reach, 315),
        geo.offset(c, reach, 135),
      ],
    ];
    return LatLngBounds.fromPoints(points);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final tone = pal.live;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: centres.isEmpty
          ? const SizedBox.shrink()
          : FlutterMap(
              options: MapOptions(
                // Every radius whole, with room around it.
                initialCameraFit: CameraFit.bounds(
                  bounds: _around(centres),
                  padding: const EdgeInsets.all(8),
                ),
                initialCenter: centres.first,
                backgroundColor: pal.background,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                MapTiles.layer(light: pal.isLight),
                CircleLayer(
                  circles: [
                    for (final c in centres)
                      CircleMarker(
                        point: c,
                        radius: kAreaRadiusMetres,
                        useRadiusInMeter: true,
                        color: tone.withValues(alpha: 0.10),
                        borderColor: tone,
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final c in centres)
                      Marker(
                        point: c,
                        width: MapMarker.target,
                        height: MapMarker.target,
                        child: MapMarker(
                          kind: MapMarkerKind.incident,
                          label: label,
                          selected: true,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
