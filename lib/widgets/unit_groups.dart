import 'package:flutter/material.dart';

import '../theme.dart';

/// How close, in screen pixels, two trucks' centres may be before their
/// markers merge. A truck marker is 38 px across, so this is "they would touch
/// or overlap" with a little air.
const double kUnitMergeRadius = 44;

/// Which trucks share one marker at the current zoom (v1.12.7).
///
/// Grouped by where they are on the screen, not by road: trucks in convoy on
/// the same road merge, and as the resident zooms in, or the trucks spread out,
/// they split back into their own markers. A group never grows wider than the
/// merge radius around its centre, so the merged marker always sits where its
/// trucks are rather than between two far-apart ones.
///
/// [points] are screen positions, in a stable order; returns groups of indices
/// into it, each in that same order.
List<List<int>> groupOnScreen(
  List<Offset> points, {
  double radius = kUnitMergeRadius,
}) {
  final groups = <List<int>>[];
  final centres = <Offset>[];
  for (var i = 0; i < points.length; i++) {
    var best = -1;
    var bestDistance = double.infinity;
    for (var g = 0; g < groups.length; g++) {
      final d = (points[i] - centres[g]).distance;
      if (d <= radius && d < bestDistance) {
        best = g;
        bestDistance = d;
      }
    }
    if (best < 0) {
      groups.add([i]);
      centres.add(points[i]);
    } else {
      final members = groups[best]..add(i);
      centres[best] += (points[i] - centres[best]) / members.length.toDouble();
    }
  }
  return groups;
}

/// The count on a merged marker: "2" … "9", then "9+".
String groupCount(int n) => n > 9 ? '9+' : '$n';

/// Several trucks in one marker: the truck in its agency's colour, a second
/// disc peeking out behind it (in the other agency's colour when the group is
/// mixed), and the count at its top right.
class UnitGroupMarker extends StatelessWidget {
  const UnitGroupMarker({
    super.key,
    required this.count,
    required this.colour,
    required this.behind,
    required this.label,
    this.stale = false,
    this.onTap,
  });

  /// The box a [Marker] gives this: the 38 px disc centred, room for the
  /// disc behind it and the count.
  static const double size = 50;

  final int count;
  final Color colour;

  /// The disc behind: the same colour, or the other agency's.
  final Color behind;

  /// What a screen reader says: "3 trucks: Apollo, Hermes, Unit 2".
  final String label;

  /// Every truck in the group has lost its location.
  final bool stale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final edge = Border.all(color: context.pal.surfaceSolid, width: 3);
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: stale ? 0.6 : 1,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The truck behind: the group is more than one.
                Positioned(
                  left: 11,
                  top: 1,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: behind,
                      shape: BoxShape.circle,
                      border: edge,
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colour,
                      shape: BoxShape.circle,
                      border: edge,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.fire_truck,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                // The count, at the top right — where a badge always is.
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    key: const ValueKey('unit-group-count'),
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: colour, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      groupCount(count),
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
