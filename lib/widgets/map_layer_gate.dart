import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../i18n/i18n.dart';
import '../theme.dart';

/// The zoom from which a map draws its layers' points: shelters, hydrants,
/// cisterns, bodies of water, stations (v1.12.49).
///
/// 18 Nov 2026: Metro Manila's layers went from about 40 points to about
/// 3,100, and "Only nearby, when zoomed in" keeps an older phone's map
/// smooth. Everything is still downloaded and kept for offline use; the map
/// only leaves the points out until zoomed in this far (a few streets
/// across), and says so. Incidents and "you are here" are drawn at every
/// zoom.
const double kLayerMinZoom = 14;

/// A FlutterMap child: [markers] from [kLayerMinZoom] in; below it, while
/// there are any to show, a hint to zoom in. It follows the map's own camera,
/// so panning and zooming need no rebuild of the screen around it.
class ZoomGatedMarkers extends StatelessWidget {
  const ZoomGatedMarkers({
    super.key,
    required this.markers,
    this.hintAlignment = const Alignment(0, -0.55),
  });

  final List<Marker> markers;

  /// Where the "zoom in" hint sits on the map, clear of each screen's chips.
  final Alignment hintAlignment;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();
    if (MapCamera.of(context).zoom >= kLayerMinZoom) {
      return MarkerLayer(rotate: true, markers: markers);
    }
    final pal = context.pal;
    return IgnorePointer(
      child: Align(
        alignment: hintAlignment,
        child: Container(
          key: const ValueKey('zoom-in-hint'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: pal.surfaceSolid.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: pal.line),
          ),
          child: Text(
            t('Zoom in to see the places you turned on'),
            style: context.type.caption.copyWith(color: pal.onBackground),
          ),
        ),
      ),
    );
  }
}
