import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

import '../theme.dart';

/// How every map in the app may be handled: drag, pinch, double-tap, fling,
/// and turn with two fingers — as in Google Maps. Turning needs a deliberate
/// twist (flutter_map's 20° threshold), so an ordinary pinch never tilts the
/// map by accident, and the compass button puts north back up.
const InteractionOptions kMapGestures = InteractionOptions(
  flags: InteractiveFlag.all,
);

/// The three states of Google Maps' location button.
enum FollowMode {
  /// The map stays wherever the person put it.
  free,

  /// The map keeps them in the middle as they move.
  follow,

  /// The map keeps them in the middle and turns so the way they face is up.
  compass,
}

/// Where the blue dot's position and heading come from: the GPS and the
/// phone's rotation sensor. Replaceable in tests, which have neither.
class MapLocationSource {
  MapLocationSource._();

  static Stream<LocationMarkerPosition?> Function() positions = () =>
      const LocationMarkerDataStreamFactory().fromGeolocatorPositionStream();

  static Stream<LocationMarkerHeading?> Function() headings = () =>
      const LocationMarkerDataStreamFactory().fromRotationSensorHeadingStream();
}

/// Hybrid map rotation (PRD v12 §4.9.4): while the phone moves, the
/// direction of travel ([travelDegrees], null when still) turns the map and
/// the cone; standing still for three seconds, the compass takes over again.
/// In a moving truck the compass swings with every steel panel and engine
/// vibration; the road's direction does not.
Stream<LocationMarkerHeading?> hybridHeadings(Stream<double?> travelDegrees) {
  StreamSubscription<LocationMarkerHeading?>? sensor;
  StreamSubscription<double?>? travel;
  DateTime? lastTravel;
  late final StreamController<LocationMarkerHeading?> out;
  out = StreamController<LocationMarkerHeading?>.broadcast(
    onListen: () {
      sensor = MapLocationSource.headings().listen((h) {
        final t = lastTravel;
        if (t != null &&
            DateTime.now().difference(t) < const Duration(seconds: 3)) {
          return;
        }
        out.add(h);
      }, onError: (Object _) {});
      travel = travelDegrees.listen((deg) {
        if (deg == null) return;
        lastTravel = DateTime.now();
        out.add(
          LocationMarkerHeading(
            heading: (deg % 360) * math.pi / 180,
            accuracy: math.pi * 0.05,
          ),
        );
      });
    },
    onCancel: () {
      unawaited(sensor?.cancel());
      unawaited(travel?.cancel());
    },
  );
  return out.stream;
}

/// One map's "you are here": its mode, and the streams its blue dot reads.
///
/// Make one per map, hand [onMapEvent] to the map's options, and put a
/// [YouAreHereLayer] and [MapLocationButtons] among its children.
class MapFollow extends ChangeNotifier {
  /// [positions] and [headings] default to the GPS and the rotation sensor.
  /// Turn-by-turn directions pass their own: positions placed on the route,
  /// and the direction of travel while moving (v1.12.9).
  MapFollow({
    Stream<LocationMarkerPosition?>? positions,
    Stream<LocationMarkerHeading?>? headings,
  }) : positions = positions ?? MapLocationSource.positions(),
       headings = headings ?? MapLocationSource.headings();

  /// How close the map comes when it starts following.
  static const double followZoom = 17;

  /// How close it comes when navigating: the next streets, not the district.
  static const double navigationZoom = 17.5;

  final Stream<LocationMarkerPosition?> positions;
  final Stream<LocationMarkerHeading?> headings;
  final StreamController<double?> _alignPosition = StreamController.broadcast();
  final StreamController<void> _alignDirection = StreamController.broadcast();

  FollowMode _mode = FollowMode.free;
  bool _disposed = false;

  FollowMode get mode => _mode;

  /// Centre on the person and keep them there as they move.
  void follow() {
    _set(FollowMode.follow);
    _alignPosition.add(followZoom);
  }

  /// Follow, and turn the map with them.
  void compass() {
    _set(FollowMode.compass);
    _alignPosition.add(null);
    _alignDirection.add(null);
  }

  /// The navigation view: on the person's latest position at
  /// [navigationZoom], the way they travel pointing up, following from here
  /// on. What Re-centre restores after they look around the map by hand.
  void navigate() {
    _set(FollowMode.compass);
    _alignPosition.add(navigationZoom);
    _alignDirection.add(null);
  }

  /// Stop following; the map stays where it is.
  void release() => _set(FollowMode.free);

  /// For [MapOptions.onMapEvent]. Dragging the map with a finger leaves follow
  /// mode, as in Google Maps; turning it by hand leaves compass mode. A pinch
  /// to zoom changes neither.
  void onMapEvent(MapEvent event) {
    if (_mode == FollowMode.free) return;
    final source = event.source;
    if (source == MapEventSource.dragStart ||
        source == MapEventSource.onDrag ||
        source == MapEventSource.flingAnimationController) {
      release();
    } else if (_mode == FollowMode.compass &&
        event is MapEventRotate &&
        source != MapEventSource.mapController) {
      _set(FollowMode.follow);
    }
  }

  void _set(FollowMode mode) {
    if (_disposed || mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_alignPosition.close());
    unawaited(_alignDirection.close());
    super.dispose();
  }
}

/// The blue dot, in the app's accent: where the phone is, how sure the GPS
/// is (the halo), and which way the phone faces (the cone). A map child.
///
/// [navigating] (v1.12.9) is for turn-by-turn directions, where a fix
/// arrives every second: the dot and the camera glide across the whole second
/// instead of jumping in 200 ms and waiting, turns ease in over half a
/// second, and the dot sits low on the screen so the road ahead shows.
class YouAreHereLayer extends StatelessWidget {
  const YouAreHereLayer({
    super.key,
    required this.follow,
    this.navigating = false,
  });

  final MapFollow follow;
  final bool navigating;

  /// One fix's worth of motion: the next fix lands as this one finishes.
  static const Duration _glide = Duration(milliseconds: 950);
  static const Duration _turn = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final accent = context.pal.accent;
    return ListenableBuilder(
      listenable: follow,
      builder: (context, _) => CurrentLocationLayer(
        positionStream: follow.positions,
        headingStream: follow.headings,
        alignPositionStream: follow._alignPosition.stream,
        alignDirectionStream: follow._alignDirection.stream,
        alignPositionOnUpdate: follow.mode == FollowMode.free
            ? AlignOnUpdate.never
            : AlignOnUpdate.always,
        alignDirectionOnUpdate: follow.mode == FollowMode.compass
            ? AlignOnUpdate.always
            : AlignOnUpdate.never,
        focalPoint: navigating
            ? const FocalPoint(ratio: Offset(0, 0.4))
            : const FocalPoint(),
        moveAnimationDuration: navigating
            ? _glide
            : const Duration(milliseconds: 200),
        moveAnimationCurve: navigating ? Curves.linear : Curves.fastOutSlowIn,
        alignPositionAnimationDuration: navigating
            ? _glide
            : const Duration(milliseconds: 200),
        alignPositionAnimationCurve: navigating
            ? Curves.linear
            : Curves.fastOutSlowIn,
        rotateAnimationDuration: navigating
            ? _turn
            : const Duration(milliseconds: 120),
        alignDirectionAnimationDuration: navigating
            ? _turn
            : const Duration(milliseconds: 120),
        style: LocationMarkerStyle(
          marker: DefaultLocationMarker(color: accent),
          markerSize: const Size.square(18),
          markerDirection: MarkerDirection.heading,
          accuracyCircleColor: accent.withValues(alpha: 0.12),
          headingSectorColor: accent.withValues(alpha: 0.55),
          headingSectorRadius: 56,
        ),
      ),
    );
  }
}

/// Google Maps' two map buttons, as a map child: a compass that appears once
/// the map is turned (tap: north up again), and the location button, which
/// steps free → follow → compass → follow.
class MapLocationButtons extends StatelessWidget {
  const MapLocationButtons({
    super.key,
    required this.follow,
    this.alignment = Alignment.centerRight,
    this.padding = const EdgeInsets.all(16),
  });

  final MapFollow follow;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final controller = MapController.of(context);
    final turn = camera.rotation % 360;
    final turned = turn > 0.5 && turn < 359.5;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: ListenableBuilder(
          listenable: follow,
          builder: (context, _) {
            final mode = follow.mode;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (turned) ...[
                  _MapButton(
                    label: 'Point the map north',
                    onTap: () {
                      if (follow.mode == FollowMode.compass) follow.follow();
                      controller.rotate(0);
                    },
                    // The arrow turns with the map, so it always points north.
                    child: Transform.rotate(
                      angle: camera.rotationRad,
                      child: Icon(
                        Icons.navigation,
                        size: 20,
                        color: context.pal.live,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _MapButton(
                  label: switch (mode) {
                    FollowMode.free => 'Show where I am',
                    FollowMode.follow => 'Turn the map with me',
                    FollowMode.compass => 'Stop turning the map',
                  },
                  onTap: () {
                    switch (mode) {
                      case FollowMode.free:
                        follow.follow();
                      case FollowMode.follow:
                        follow.compass();
                      case FollowMode.compass:
                        follow.follow();
                        controller.rotate(0);
                    }
                  },
                  child: Icon(
                    switch (mode) {
                      FollowMode.free => Icons.location_searching,
                      FollowMode.follow => Icons.my_location,
                      FollowMode.compass => Icons.explore,
                    },
                    size: 20,
                    color: mode == FollowMode.free
                        ? context.pal.onBackground
                        : context.pal.accent,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: context.pal.surfaceSolid,
          shape: CircleBorder(side: BorderSide(color: context.pal.line)),
          elevation: 3,
          shadowColor: Colors.black54,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
