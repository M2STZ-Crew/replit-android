import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../theme.dart';
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

  Widget build() => switch (this) {
    AppTab.map => const MapScreen(),
    AppTab.sos => const HomeScreen(),
    AppTab.hotlines => const CallScreen(),
    AppTab.guides => const GuideScreen(),
  };
}

/// The shared bottom bar.
///
/// Each tab is its own route rather than a page in an IndexedStack, because
/// that is how the rest of the app already navigates. Switching replaces the
/// current route with no transition, so tabs never stack up behind each other
/// and Back never walks you through four tabs to leave the app.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.active});

  final AppTab active;

  void _go(BuildContext context, AppTab tab) {
    if (tab == active) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => tab.build(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Row(
        children: [
          for (final tab in AppTab.values)
            Expanded(
              child: _NavItem(
                tab: tab,
                selected: tab == active,
                onTap: () => _go(context, tab),
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
    final shape = BorderRadius.circular(AppRadius.sheet);
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: selected ? AppColors.raised : Colors.transparent,
              borderRadius: shape,
            ),
            // Scaled down rather than clipped: a tab bar is a fixed height, so
            // at a large system font scale the label has to shrink to fit
            // instead of overflowing its 66px cell.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: selected ? AppColors.onBackground : AppColors.faint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
