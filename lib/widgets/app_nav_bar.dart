import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';
import '../theme.dart';
import 'design.dart';

/// The five slots of the REPLIT-OVERHAUL tab bar: Map, Hotlines, SOS, Guides,
/// Profile. SOS is not a tab label but a raised coral disc in the middle slot —
/// the one control that must be findable without looking.
///
/// Profile moved onto the bar in the overhaul (v2 kept it behind the header
/// avatar). The avatars stay in the headers and now switch to this tab.
enum AppTab {
  map('Map', Art.navMap),
  hotlines('Hotlines', Art.navHotlines),
  sos('SOS', null),
  guides('Guides', Art.navGuides),
  profile('Profile', Art.navProfile);

  const AppTab(this.label, this.icon);

  final String label;

  /// Tab glyph; null for SOS, which is drawn as the disc.
  final String? icon;

  Widget build() => switch (this) {
    AppTab.map => const MapScreen(),
    AppTab.hotlines => const CallScreen(),
    AppTab.sos => const HomeScreen(),
    AppTab.guides => const GuideScreen(),
    AppTab.profile => const ProfileScreen(),
  };
}

/// One slot on a bottom bar.
typedef NavBarItem = ({
  String icon,
  String label,
  bool selected,
  VoidCallback onTap,
});

/// The bar itself, without the tabs it carries: a 64px row on the ground
/// colour under a raised disc, rounded at the top and hairlined.
///
/// Three roles have one — Map/SOS for a resident, Duty/RUN for a responder,
/// Queue/LIVE for a coordinator — and they are the same object with different
/// slots, so it lives in one place rather than three.
class NavBarShell extends StatelessWidget {
  const NavBarShell({
    super.key,
    required this.items,
    required this.disc,
    required this.discActive,
    required this.onDisc,
    this.discSlot = 2,
  });

  final List<NavBarItem> items;

  /// The word on the raised disc: SOS, RUN, LIVE.
  final String disc;
  final bool discActive;
  final VoidCallback onDisc;

  /// Which slot the disc covers.
  final int discSlot;

  /// How far the disc rises above the bar. The widget is this much taller
  /// than the visible bar; the strip above is transparent and lets taps
  /// through. Screens that draw under it (a map) set `extendBody`.
  static const double overhang = 36;

  /// Height of the tab row, excluding the safe-area inset below it.
  static const double tabs = 64;

  @override
  Widget build(BuildContext context) {
    // The design's bar is 98px: a 64px tab row over the 34px iOS home
    // indicator. On a real handset the gesture bar sits under it, so the
    // safe-area inset is added rather than baked in.
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final below = inset > 0 ? inset : 10.0;

    return SizedBox(
      height: overhang + tabs + below,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: tabs + below,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.pal.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: context.pal.line)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, below),
                child: Row(
                  children: [
                    for (final (i, item) in items.indexed)
                      Expanded(
                        child: i == discSlot
                            // The disc owns this slot; it sits above the row.
                            ? const SizedBox.shrink()
                            : _NavItem(item: item),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: _Disc(label: disc, active: discActive, onTap: onDisc),
          ),
        ],
      ),
    );
  }
}

/// The resident's bar.
///
/// Each tab is its own route rather than a page in an IndexedStack, because
/// that is how the rest of the app already navigates. Switching clears the
/// stack and shows the tab with no transition, so tabs never pile up behind
/// each other and Back never walks you through five tabs to leave the app —
/// even when the bar was reached on a pushed screen (Hotlines from the help
/// centre, say).
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.active});

  final AppTab active;

  /// How far the SOS disc rises above the bar — see [NavBarShell.overhang].
  static const double overhang = NavBarShell.overhang;

  /// Switch to [tab] from anywhere — the header avatars use this for Profile.
  static void switchTo(BuildContext context, AppTab tab) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => tab.build(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (_) => false,
    );
  }

  void _go(BuildContext context, AppTab tab) {
    if (tab == active) return;
    switchTo(context, tab);
  }

  @override
  Widget build(BuildContext context) {
    return NavBarShell(
      disc: 'SOS',
      discActive: active == AppTab.sos,
      onDisc: () => _go(context, AppTab.sos),
      items: [
        for (final tab in AppTab.values)
          (
            icon: tab.icon ?? '',
            label: tab.label,
            selected: tab == active,
            onTap: () => _go(context, tab),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item});

  final NavBarItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? context.pal.onBackground : context.pal.muted;
    return Semantics(
      button: true,
      selected: item.selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: item.onTap,
        radius: 36,
        child: SizedBox(
          height: NavBarShell.tabs,
          // Scaled down rather than clipped: a tab bar is a fixed height, so
          // at a large system font scale the label has to shrink to fit
          // instead of overflowing its cell.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(item.icon, width: 22, height: 22, color: color),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  maxLines: 1,
                  style: item.selected
                      ? context.type.labelSm.copyWith(color: color)
                      : context.type.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised disc: 72px, coral gradient, ringed in the ground colour so it
/// reads as cut out of the bar. Glow is one of the two places the design
/// permits it (§2.7); it strengthens while its own screen is showing.
class _Disc extends StatelessWidget {
  const _Disc({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.pal.background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.pal.accent.withValues(
                  alpha: active ? 0.55 : 0.26,
                ),
                blurRadius: active ? 22 : 7,
                spreadRadius: active ? 1 : 0,
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment(-0.21, -1),
                end: Alignment(0.21, 1),
                stops: [0.076, 0.916],
                colors: [context.pal.gradientStart, context.pal.gradientEnd],
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.accentText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
