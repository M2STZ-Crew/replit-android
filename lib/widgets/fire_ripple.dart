import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import 'map_marker.dart';
import 'motion.dart';

/// A fire's ripple (v1.12.58; 20 Nov 2026: "make the incident in the map has
/// a pulsing location marker through the whole 100m area"; answered "Ripple
/// out to 100 m"): a ring grows from each fire to [metres], the distance its
/// neighbours are alerted within, and fades, every [period]. The fire's own
/// circle stays drawn beneath it. Under the phone's "remove animations" it
/// is not drawn: the circle and the marker still say where the fire is.
class FireRipple extends StatefulWidget {
  const FireRipple({super.key, required this.centres});

  final List<LatLng> centres;

  static const double metres = 100;
  static const Duration period = Duration(seconds: 2);

  @override
  State<FireRipple> createState() => _FireRippleState();
}

class _FireRippleState extends State<FireRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: FireRipple.period,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = Motion.of(context).reduced;
    if (_still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still || widget.centres.isEmpty) return const SizedBox.shrink();
    final tone = MapMarkerKind.incident.tone(context.pal);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        final fade = 1 - t;
        return CircleLayer(
          circles: [
            for (final c in widget.centres)
              CircleMarker(
                point: c,
                radius: math.max(2, FireRipple.metres * t),
                useRadiusInMeter: true,
                color: tone.withValues(alpha: 0.14 * fade),
                borderColor: tone.withValues(alpha: 0.8 * fade),
                borderStrokeWidth: 2,
              ),
          ],
        );
      },
    );
  }
}
