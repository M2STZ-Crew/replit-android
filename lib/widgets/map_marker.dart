import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_icons.dart';
import 'motion.dart';

/// What a map point is. Category is carried by the surface and the glyph
/// together, never by colour alone (REPLIT (MAIN) 04 · Map marker, pass 3).
enum MapMarkerKind {
  incident(AppColors.markerIncident, AppIcons.localFireDepartment, 'Incident'),
  police(AppColors.markerPolice, AppIcons.localPolice, 'Police'),
  medical(AppColors.markerMedical, AppIcons.medicalServices, 'Medical'),
  barangay(AppColors.markerBarangay, AppIcons.accountBalance, 'Barangay'),
  hydrant(AppColors.markerWaterSurface, AppIcons.fireHydrant, 'Hydrant'),
  water(AppColors.markerWaterSurface, AppIcons.water, 'Water'),
  cistern(AppColors.markerWaterSurface, AppIcons.oilBarrel, 'Cistern'),
  shelter(AppColors.markerShelterSurface, AppIcons.house, 'Shelter'),
  risk(AppColors.markerRisk, AppIcons.warning, 'Risk zone'),
  unit(AppColors.markerUnit, AppIcons.fireTruck, 'Unit');

  const MapMarkerKind(this.surface, this.glyph, this.noun);

  /// color/map/marker-surface-*: the 700 step of the category colour, so the
  /// white glyph on it measures 3.55–7.23 : 1.
  final Color surface;
  final IconData glyph;

  /// What a screen reader calls it, before the place's own name.
  final String noun;

  /// The category's colour in the legend and on the ground: a layer chip's
  /// dot, wash and edge, and the area a layer draws (MapAreas). The bright
  /// ink, where [surface] is the 700 step a white glyph sits on. Incident is
  /// the fire's coral and a risk zone red, on every role's map.
  Color tone(AppPalette pal) => switch (this) {
    incident => pal.accentInk,
    risk => pal.live,
    hydrant || water || cistern => pal.water,
    shelter => pal.ok,
    police => pal.police,
    medical => pal.medical,
    barangay => pal.barangay,
    unit => pal.muted,
  };
}

/// One map point, in the archive MAP | ELEMENTS shape: a rounded square in
/// the category's surface colour carrying a white filled glyph, edged in
/// white for dark and busy maps, on a ground-coloured backing plate that
/// carries the edge over the light OpenStreetMap fallback (11.2 : 1).
///
/// Default 32 px (radius 8, 1.5 px edge, 20 px glyph, 38 px plate); selected
/// 40 px (radius 10, 2 px edge, 24 px glyph, 48 px plate). Whatever its size
/// it answers taps over 48 × 48, so put it in a 48 px flutter_map Marker.
class MapMarker extends StatelessWidget {
  const MapMarker({
    super.key,
    required this.kind,
    required this.label,
    this.selected = false,
    this.live = false,
    this.dimmed = false,
    this.badge,
    this.onTap,
  });

  final MapMarkerKind kind;

  /// The place, for screen readers: "Incident, F. Victor Street".
  final String label;
  final bool selected;

  /// A live Area: a halo pulses around it every 1 600 ms — the one loop the
  /// design allows, stopped under reduced motion.
  final bool live;

  /// Still marks the place, at half strength (a shelter that is closed).
  final bool dimmed;

  /// A small sign on the corner (a shelter outside Pasay).
  final Widget? badge;
  final VoidCallback? onTap;

  /// The tap target every marker gets.
  static const double target = 48;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 40.0 : 32.0;
    final plate = selected ? 48.0 : 38.0;
    final square = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kind.surface,
        borderRadius: BorderRadius.circular(selected ? 10 : 8),
        border: Border.all(color: Colors.white, width: selected ? 2 : 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(kind.glyph, size: selected ? 24 : 20, color: Colors.white),
    );
    final body = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (live) _LivePulse(color: kind.surface, size: plate + 8),
        Container(
          width: plate,
          height: plate,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(selected ? 14 : 12),
          ),
        ),
        square,
        if (badge != null)
          Positioned(
            right: (target - size) / 2 - 5,
            top: (target - size) / 2 - 5,
            child: badge!,
          ),
      ],
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${kind.noun}, $label',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: target,
          child: Opacity(opacity: dimmed ? 0.5 : 1, child: body),
        ),
      ),
    );
  }
}

/// The corner sign on a shelter outside Pasay (§2.4): an outward arrow on
/// the shelter green, so the trip's length reads before the name does.
class OutsidePasayBadge extends StatelessWidget {
  const OutsidePasayBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: context.pal.ok,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 1.5),
      ),
      child: Icon(AppIcons.northEast, size: 9, color: AppColors.background),
    );
  }
}

class _LivePulse extends StatefulWidget {
  const _LivePulse({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _c
        ..stop()
        ..value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Motion.standard),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.size * 0.32),
          color: widget.color.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
