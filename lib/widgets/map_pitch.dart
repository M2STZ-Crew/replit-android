import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_icons.dart';
import 'map_glass.dart';

/// UI READY — PRD v14 §4.9.1: Coordinators and Responders drive on Mapbox
/// Standard with the map tilted into a driver's view, stepped 0° / 30° / 45° /
/// 60° from a control on the map, 45° at launch; long-pressing the compass
/// resets to north-up and 0°. If Standard does not load, the flat dark map
/// shows with "3D view unavailable — showing flat map."
///
/// Not wired to any map yet, on purpose: the app draws its maps with
/// flutter_map, which renders flat raster tiles and has no camera pitch or
/// vector buildings, so there is no genuine 3D for this control to drive.
/// It needs the Mapbox Maps SDK for Flutter (mapbox_maps_flutter) behind the
/// driving screens — see docs/FRONTEND_INTEGRATION_HANDOFF.md. Until then
/// the maps stay flat and working, and nothing pretends to tilt.

/// The pitch steps, in the order a tap moves through them.
const List<int> kPitchSteps = [0, 30, 45, 60];

/// The pitch at launch. PRD v14 §4.9.1 states 45° but §18 still lists it as a
/// proposal: one place to change it once it is signed off.
const int kLaunchPitch = 45;

/// The step after [pitch], wrapping from 60° back to 0°.
int nextPitch(int pitch) {
  final i = kPitchSteps.indexOf(pitch);
  return kPitchSteps[(i < 0 ? 0 : i + 1) % kPitchSteps.length];
}

/// The map's tilt control: a 48 px glass button saying the pitch now; a tap
/// moves to the next step. [onChanged] null shows it disabled (flat map).
class MapPitchButton extends StatelessWidget {
  const MapPitchButton({super.key, required this.pitch, this.onChanged});

  final int pitch;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final enabled = onChanged != null;
    final next = nextPitch(pitch);
    final shape = BorderRadius.circular(AppRadius.control);
    void tap() => onChanged?.call(next);
    final button = Material(
      color: MapGlass.glass(context),
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: enabled ? tap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: pal.line),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.layers,
                size: 18,
                color: enabled ? pal.onBackground : pal.faint,
              ),
              Text(
                '$pitch°',
                style: context.type.captionSm.copyWith(
                  color: enabled ? pal.onBackground : pal.faint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? 'Map tilt $pitch degrees. Tap for $next degrees'
          : 'Map tilt unavailable on the flat map',
      excludeSemantics: true,
      onTap: enabled ? tap : null,
      child: ClipRRect(
        borderRadius: shape,
        child: MapGlass.blurs(context)
            ? BackdropFilter(filter: MapGlass.blur, child: button)
            : button,
      ),
    );
  }
}

/// The one line shown over the map when Mapbox Standard does not load.
class Map3dUnavailableBanner extends StatelessWidget {
  const Map3dUnavailableBanner({super.key});

  static const String message = '3D view unavailable — showing flat map.';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MapGlass.strong(context),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: pal.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.info, size: 18, color: pal.label),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: context.type.detail.copyWith(color: pal.textSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
