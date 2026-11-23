import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

import '../theme.dart';
import 'app_icons.dart';
import 'map_glass.dart';
import '../i18n/i18n.dart';

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

  /// Before Center brings the map to the person (v1.12.62): a screen whose
  /// drawer can cover most of the map lowers it first.
  VoidCallback? makeRoom;

  /// The moves to the person the map is told to make, for tests.
  @visibleForTesting
  Stream<double?> get alignments => _alignPosition.stream;

  /// Back to the person at the same zoom, when following: the part of the
  /// map in view changed (v1.12.62).
  void realign() {
    if (_disposed || _mode == FollowMode.free) return;
    _alignPosition.add(null);
  }

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
    this.cover,
  });

  final MapFollow follow;
  final bool navigating;

  /// How much of the map a drawer over its bottom covers, from a [MapCover]
  /// around it (v1.12.62; 23 Nov 2026: "it centers the whole screen but the
  /// drawer blocks it"; answered "Visible center"). The person is put in the
  /// middle of what is left in view, and stays there as the drawer moves.
  final ValueListenable<double>? cover;

  /// Where the person sits: the middle of the map in view, or low in it
  /// while navigating, so the road ahead shows.
  @visibleForTesting
  static FocalPoint focalFor({
    required bool navigating,
    required double covered,
  }) {
    final ratio = navigating ? 0.4 : 0.0;
    final share = 0.5 + ratio / 2;
    return FocalPoint(
      ratio: Offset(0, ratio),
      offset: Offset(0, -share * covered),
    );
  }

  /// One fix's worth of motion: the next fix lands as this one finishes.
  static const Duration _glide = Duration(milliseconds: 950);
  static const Duration _turn = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final cover = this.cover;
    if (cover == null) return _layer(context, 0);
    return _CoverWatch(cover: cover, follow: follow, builder: _layer);
  }

  Widget _layer(BuildContext context, double covered) {
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
        focalPoint: focalFor(navigating: navigating, covered: covered),
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
          marker: const _YouDot(),
          markerSize: const Size.square(24),
          markerDirection: MarkerDirection.heading,
          accuracyCircleColor: accent.withValues(alpha: 0.12),
          headingSectorColor: accent.withValues(alpha: 0.55),
          headingSectorRadius: 56,
        ),
      ),
    );
  }
}

/// Rebuilds the layer as the drawer moves, and once it settles brings a
/// following map back to the person.
class _CoverWatch extends StatefulWidget {
  const _CoverWatch({
    required this.cover,
    required this.follow,
    required this.builder,
  });

  final ValueListenable<double> cover;
  final MapFollow follow;
  final Widget Function(BuildContext context, double covered) builder;

  @override
  State<_CoverWatch> createState() => _CoverWatchState();
}

class _CoverWatchState extends State<_CoverWatch> {
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    widget.cover.addListener(_moved);
  }

  @override
  void didUpdateWidget(_CoverWatch old) {
    super.didUpdateWidget(old);
    if (old.cover != widget.cover) {
      old.cover.removeListener(_moved);
      widget.cover.addListener(_moved);
    }
  }

  @override
  void dispose() {
    _settle?.cancel();
    widget.cover.removeListener(_moved);
    super.dispose();
  }

  void _moved() {
    if (!mounted) return;
    setState(() {});
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 150), widget.follow.realign);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.cover.value);
}

/// Wrap a drawer over a map in this, and hand [cover] to the map's
/// [YouAreHereLayer]: it says how much of the screen the drawer covers,
/// measured from its top edge after each frame it moves in (v1.12.62).
class MapCover extends SingleChildRenderObjectWidget {
  const MapCover({super.key, required this.cover, super.child});

  final ValueNotifier<double> cover;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMapCover(cover, MediaQuery.sizeOf(context).height);

  @override
  void updateRenderObject(BuildContext context, RenderMapCover renderObject) {
    renderObject
      ..cover = cover
      ..screen = MediaQuery.sizeOf(context).height;
  }
}

class RenderMapCover extends RenderProxyBox {
  RenderMapCover(this.cover, this.screen);

  ValueNotifier<double> cover;
  double screen;
  bool _queued = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_queued) return;
    _queued = true;
    // Where it is on screen once the frame is done, never during it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!attached || !hasSize) return;
      final top = localToGlobal(Offset.zero).dy;
      final covered = (screen - top).clamp(0.0, screen).toDouble();
      if ((cover.value - covered).abs() >= 1) cover.value = covered;
    });
  }
}

/// Google Maps' two map buttons, as a map child: a compass that appears once
/// the map is turned (tap: north up again), and the location button, which
/// steps free → follow → compass → follow. A screen's own map controls
/// ([extra], [MapControlButton]s) stack under them, so none overlaps.
class MapLocationButtons extends StatelessWidget {
  const MapLocationButtons({
    super.key,
    required this.follow,
    this.alignment = Alignment.centerRight,
    this.padding = const EdgeInsets.all(16),
    this.extra = const [],
  });

  final MapFollow follow;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  /// Under the location button: a coordinator's Add a water source (v1.12.55).
  final List<Widget> extra;

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
                  MapControlButton(
                    label: t('Point the map north'),
                    onTap: () {
                      if (follow.mode == FollowMode.compass) follow.follow();
                      controller.rotate(0);
                    },
                    // The arrow turns with the map, so it always points north.
                    child: Transform.rotate(
                      angle: camera.rotationRad,
                      child: Icon(
                        AppIcons.navigation,
                        size: 20,
                        color: context.pal.live,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                MapControlButton(
                  label: switch (mode) {
                    FollowMode.free => t('Show where I am'),
                    FollowMode.follow => t('Turn the map with me'),
                    FollowMode.compass => t('Stop turning the map'),
                  },
                  onTap: () {
                    switch (mode) {
                      case FollowMode.free:
                        follow.makeRoom?.call();
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
                      FollowMode.free => AppIcons.locationSearching,
                      FollowMode.follow => AppIcons.myLocation,
                      FollowMode.compass => AppIcons.explore,
                    },
                    size: 20,
                    color: mode == FollowMode.free
                        ? context.pal.onBackground
                        : context.pal.accent,
                  ),
                ),
                for (final control in extra) ...[
                  const SizedBox(height: 10),
                  control,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A map control (04 · Icon button, Overlay): a 48 px glass square with a
/// hairline, its [label] said and shown as a tooltip.
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
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
      onTap: onTap,
      child: Tooltip(
        message: label,
        // A map control (04 · Icon button, Overlay): a 48 px square at the
        // control radius with a hairline, no shadow. Glass strong without
        // its own blur — the map already blurs behind its chips, card and
        // sheet, and the design keeps blurred surfaces to three.
        child: Material(
          color: MapGlass.strong(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            side: BorderSide(color: context.pal.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: onTap,
            child: SizedBox.square(dimension: 48, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

/// You on the map (04 · Map marker, Kind=You): an 18 px dot in
/// color/map/you with a 1.5 px white edge, on a 24 px ground plate that keeps
/// it visible over light tiles. No glyph.
class _YouDot extends StatelessWidget {
  const _YouDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: context.pal.you,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}
