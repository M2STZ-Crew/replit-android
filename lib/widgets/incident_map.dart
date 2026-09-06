import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import '../widgets/map_tiles.dart';

const Color _safeGreen = AppColors.ok;

/// Map centered on an incident with an orange marker.
///
/// Uses CARTO "Dark Matter" basemap tiles — free, NO API key, NO account, NO
/// billing — which also match the app's dark theme. To use plain OpenStreetMap
/// instead, swap the [TileLayer] urlTemplate for
/// `https://tile.openstreetmap.org/{z}/{x}/{y}.png`.
///
/// By default it's a static snapshot ([interactive] = false). Pass
/// interactive: true to allow panning/zooming, and [evacSites] to plot nearby
/// evacuation sites as green markers.
class IncidentMap extends StatelessWidget {
  const IncidentMap({
    super.key,
    required this.lat,
    required this.lng,
    this.zoom = 15.0,
    this.interactive = false,
    this.evacSites = const [],
  });

  final double lat;
  final double lng;
  final double zoom;
  final bool interactive;
  final List<LatLng> evacSites;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: zoom,
        minZoom: 4,
        maxZoom: 18,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        MapTiles.layer(),
        MarkerLayer(
          markers: [
            for (final site in evacSites)
              Marker(
                point: site,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: _safeGreen,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x9922C55E), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.home_outlined, color: Colors.white, size: 16),
                ),
              ),
            Marker(
              point: point,
              width: 26,
              height: 26,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap, © CARTO'),
          ],
        ),
      ],
    );
  }
}
