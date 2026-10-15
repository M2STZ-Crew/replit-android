import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import 'coordinator_kit.dart';
import 'map_marker.dart';
import 'map_layers.dart';
import 'map_tiles.dart';
import 'you_are_here.dart';

/// The map extract on an Area's detail (06 · C04, C07): each Area's centre as
/// a selected incident marker inside its 300 m radius (the shared incident
/// radius, [MapAreas.incidentRadius]), framed to fit. A real map: it pans,
/// zooms and turns like every other map in the app, shows where you are, and
/// its location button finds you.
class AreaMapPreview extends StatefulWidget {
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

  @override
  State<AreaMapPreview> createState() => _AreaMapPreviewState();
}

class _AreaMapPreviewState extends State<AreaMapPreview> {
  final MapFollow _follow = MapFollow();

  @override
  void dispose() {
    _follow.dispose();
    super.dispose();
  }

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
    final centres = widget.centres;
    return Container(
      height: widget.height,
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
                interactionOptions: kMapGestures,
                onMapEvent: _follow.onMapEvent,
              ),
              children: [
                MapTiles.layer(light: pal.isLight),
                CircleLayer(
                  circles: [
                    for (final c in centres)
                      MapAreas.incidentRadius(
                        pal,
                        c,
                        metres: kAreaRadiusMetres,
                      ),
                  ],
                ),
                MarkerLayer(
                  rotate: true,
                  markers: [
                    for (final c in centres)
                      Marker(
                        point: c,
                        width: MapMarker.target,
                        height: MapMarker.target,
                        child: MapMarker(
                          kind: MapMarkerKind.incident,
                          label: widget.label,
                          selected: true,
                        ),
                      ),
                  ],
                ),
                YouAreHereLayer(follow: _follow),
                MapLocationButtons(
                  follow: _follow,
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(8),
                ),
                MapTiles.attribution(),
              ],
            ),
    );
  }
}
