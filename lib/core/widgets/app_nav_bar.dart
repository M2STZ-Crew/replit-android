import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'design.dart';

/// The four tabs from the hand-off: Map, SOS, Hotlines, Guides.
///
/// Profile is deliberately absent — the design puts it behind the avatar in
/// each screen's header so the bar stays at four thumb-sized targets.
enum AppTab {
  map('Map', Art.navMapOn, Art.navMapOff),
  sos('SOS', Art.navSosOn, Art.navSosOff),
  hotlines('Hotlines', Art.navCallOn, Art.navCallOff),
  guides('Guides', Art.navGuideOn, Art.navGuideOff);

  const AppTab(this.label, this.onArt, this.offArt);

  final String label;
  final String onArt;
  final String offArt;
}

class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.active, required this.onSelect});

  final AppTab active;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    // The design's bar is 98px tall including an 11px inset. On a real handset
    // the gesture bar sits under it, so the safe-area inset is added rather
    // than baked in.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 11, 8, bottomInset > 0 ? bottomInset : 11),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Row(
        children: [
          for (final tab in AppTab.values)
            Expanded(
              child: _NavItem(
                tab: tab,
                selected: tab == active,
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          onTap: onTap,
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: selected ? AppColors.surfaceRaised : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sheet),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  selected ? tab.onArt : tab.offArt,
                  width: 30,
                  height: 21,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 6),
                Text(
                  tab.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: selected ? AppColors.text : AppColors.faint,
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
