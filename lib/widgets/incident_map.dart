import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import '../widgets/map_tiles.dart';
import 'map_marker.dart';
import 'you_are_here.dart';

/// Map centred on an incident with an orange marker, on [MapTiles]' basemap.
///
/// Movable like every map in the app — drag, pinch, turn — with the viewer's
/// blue dot and the location buttons. [interactive] false makes it a still
/// picture: the SOS camera's thumbnail, where a thumb must never drag the map
/// in the middle of taking the photo. [evacSites] plots nearby evacuation sites
/// as green markers.
class IncidentMap extends StatefulWidget {
  const IncidentMap({
    super.key,
    required this.lat,
    required this.lng,
    this.zoom = 15.0,
    this.interactive = true,
    this.evacSites = const [],
  });

  final double lat;
  final double lng;
  final double zoom;
  final bool interactive;
  final List<LatLng> evacSites;

  @override
  State<IncidentMap> createState() => _IncidentMapState();
}

class _IncidentMapState extends State<IncidentMap> {
  final MapFollow _follow = MapFollow();

  @override
  void dispose() {
    _follow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.lat, widget.lng);
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: widget.zoom,
        minZoom: 4,
        maxZoom: 18,
        interactionOptions: widget.interactive
            ? kMapGestures
            : const InteractionOptions(flags: InteractiveFlag.none),
        onMapEvent: _follow.onMapEvent,
      ),
      children: [
        MapTiles.layer(light: context.pal.isLight),
        MarkerLayer(
          rotate: true,
          markers: [
            for (final site in widget.evacSites)
              Marker(
                point: site,
                width: MapMarker.target,
                height: MapMarker.target,
                child: const MapMarker(
                  kind: MapMarkerKind.shelter,
                  label: 'Evacuation site',
                ),
              ),
            Marker(
              point: point,
              width: MapMarker.target,
              height: MapMarker.target,
              child: const MapMarker(
                kind: MapMarkerKind.incident,
                label: 'the incident',
                selected: true,
              ),
            ),
          ],
        ),
        if (widget.interactive) ...[
          YouAreHereLayer(follow: _follow),
          MapLocationButtons(
            follow: _follow,
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(8),
          ),
        ],
        // The tiles are MapTiles' (Mapbox, or OSM without a token), so the
        // credit is too — this used to name CARTO, whose tiles it no longer
        // draws.
        MapTiles.attribution(),
      ],
    );
  }
}
