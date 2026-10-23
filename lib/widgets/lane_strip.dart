import 'package:flutter/material.dart';

import '../navigation/instructions.dart';
import '../navigation/nav_route.dart';
import '../theme.dart';
import 'maneuver_arrow.dart';

/// The lanes at the next maneuver, left to right (PRD v14 §4.9.2): each
/// lane's arrow, the ones to use in coral on a coral-edged plate, the others
/// dimmed with no plate — so the shape, not only the colour, says which.
///
/// A V14 frontend extension: pass 6 has no frame for it, so it is composed
/// from the C10 banner's tokens and the maneuver arrows. Read as one phrase
/// by a screen reader ("Lanes: 3. Use the left two lanes").
class LaneStrip extends StatelessWidget {
  const LaneStrip({super.key, required this.lanes});

  final List<LaneInfo> lanes;

  @override
  Widget build(BuildContext context) {
    final phrase = lanePhrase(lanes);
    final pal = context.pal;
    return Semantics(
      container: true,
      label:
          'Lanes: ${lanes.length}. '
          '${phrase == null ? 'Use the highlighted lanes' : 'Use $phrase'}',
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('lane-strip'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lanes.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              key: ValueKey('lane-$i-${lanes[i].valid ? 'use' : 'not'}'),
              width: 36,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: lanes[i].valid
                    ? pal.accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: lanes[i].valid ? pal.accent : pal.line,
                  width: lanes[i].valid ? 1.5 : 1,
                ),
              ),
              child: ManeuverArrow(
                type: 'turn',
                modifier: _modifier(lanes[i].shown),
                size: 24,
                color: lanes[i].valid ? pal.accent : pal.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A lane's indication as a maneuver modifier: "none" is straight on.
  static String _modifier(String indication) =>
      indication == 'none' ? 'straight' : indication;
}
