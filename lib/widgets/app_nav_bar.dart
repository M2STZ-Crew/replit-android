import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../models/active_report.dart';
import '../screens/profile_screen.dart';
import '../screens/report_status_screen.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'design.dart';

/// The five slots of the REPLIT-OVERHAUL tab bar: Map, Hotlines, SOS, Guides,
/// Profile. SOS is not a tab label but a raised coral disc in the middle slot —
/// the one control that must be findable without looking.
///
/// Profile moved onto the bar in the overhaul (v2 kept it behind the header
/// avatar). The avatars stay in the headers and now switch to this tab.
///
/// The glyphs are the design's filled icons (map, phone, document, person —
/// REPLIT (MAIN) 04 · Nav bar, pass 3), drawn from the app's icon font rather
/// than tinted bitmaps.
enum AppTab {
  map('Map', AppIcons.map),
  hotlines('Hotlines', AppIcons.call),
  sos('SOS', null),
  guides('Guides', AppIcons.description),
  profile('Profile', AppIcons.person);

  const AppTab(this.label, this.icon);

  final String label;

  /// Tab glyph; null for SOS, which is drawn as the disc.
  final IconData? icon;

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
  IconData icon,
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
///
/// Selection follows the Nav tab component (04, pass 3): the selected tab
/// sits in a 56 × 32 pill with a coral edge and gets a bright glyph and a bold
/// label; the others are grey, never outlines. When the disc's own screen is
/// showing, no tab is selected and the disc wears a white ring instead.
class NavBarShell extends StatelessWidget {
  const NavBarShell({
    super.key,
    required this.items,
    required this.disc,
    required this.discActive,
    required this.onDisc,
    this.discLabel,
    this.discGlow = true,
    this.discSlot = 2,
  });

  final List<NavBarItem> items;

  /// The word on the raised disc: SOS, RUN, LIVE.
  final String disc;
  final bool discActive;
  final VoidCallback onDisc;

  /// What a screen reader calls the disc — its full act ("SOS — hold to
  /// report"). Defaults to [disc].
  final String? discLabel;

  /// Only the resident's SOS disc glows: PRD §4.7.1 allows glow on exactly
  /// two objects, the splash mark and the SOS button.
  final bool discGlow;

  /// Which slot the disc covers.
  final int discSlot;

  /// How far the disc rises above the bar. The widget is this much taller
  /// than the visible bar; the strip above is transparent and lets taps
  /// through. Screens that draw under it (a map) set `extendBody`.
  static const double overhang = 36;

  /// Height of the tab row, excluding the safe-area inset below it.
  static const double tabs = 64;

  /// The 4 px the design keeps above the tab row.
  static const double _top = 4;

  @override
  Widget build(BuildContext context) {
    // The design's bar is 102px: a 4px lip and a 64px tab row over the 34px
    // iOS home indicator. On a real handset the gesture bar sits under it, so
    // the safe-area inset is added rather than baked in.
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final below = inset > 0 ? inset : 10.0;

    return SizedBox(
      height: overhang + _top + tabs + below,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _top + tabs + below,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.pal.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.sheet),
                ),
                border: Border(top: BorderSide(color: context.pal.line)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, _top, 8, below),
                child: Row(
                  children: [
                    for (final (i, item) in items.indexed)
                      Expanded(
                        child: i == discSlot
                            // The disc owns this slot; it sits above the row.
                            ? const SizedBox.shrink()
                            : _NavItem(
                                item: item,
                                position: i + 1,
                                of: items.length,
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: _Disc(
              label: disc,
              semantics: discLabel ?? disc,
              active: discActive,
              glow: discGlow,
              onTap: onDisc,
            ),
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
    // With a report already out, SOS goes back to it rather than to a blank
    // dial: a second hold would send a second report of the same fire. The
    // report screen keeps a way to report something different.
    if (tab == AppTab.sos) {
      final report = ActiveReportStore.mine;
      if (report != null) {
        ReportStatusScreen.open(context, report);
        return;
      }
    }
    if (tab == active) return;
    switchTo(context, tab);
  }

  @override
  Widget build(BuildContext context) {
    return NavBarShell(
      disc: 'SOS',
      discLabel: 'SOS — hold to report',
      discActive: active == AppTab.sos,
      onDisc: () => _go(context, AppTab.sos),
      items: [
        for (final tab in AppTab.values)
          (
            icon: tab.icon ?? AppIcons.circle,
            label: tab.label,
            selected: tab == active,
            onTap: () => _go(context, tab),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.position,
    required this.of,
  });

  final NavBarItem item;

  /// Where the tab sits among the bar's destinations, for "tab 2 of 5".
  final int position;
  final int of;

  @override
  Widget build(BuildContext context) {
    final on = item.selected;
    // Bright on the pill, grey elsewhere — a filled glyph in both states, so
    // selection never rests on colour alone: the pill's edge and the label's
    // weight say it too.
    final color = on ? context.pal.onBackground : context.pal.label;
    final fade = Motion.of(context).fade;
    return Semantics(
      button: true,
      selected: on,
      label: '${item.label}, tab $position of $of',
      // The tap has to be on this node: excluding the children's semantics
      // also drops the InkResponse's tap, and TalkBack's double-tap needs it.
      onTap: item.onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: item.onTap,
        radius: 36,
        highlightColor: context.pal.pressed,
        splashColor: context.pal.pressed,
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
                AnimatedContainer(
                  key: on ? const ValueKey('nav-pill') : null,
                  duration: fade,
                  curve: Motion.standard,
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    color: on
                        ? context.pal.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: on ? context.pal.accent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, size: 24, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  style: on
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

/// The raised disc: 72px, the coral gradient top to bottom, edged in a 6px
/// ground stroke that cuts the notch in the bar. The resident's SOS disc
/// glows (one of the two places the design permits it, §2.7); on its own
/// screen the disc gains a 2px white ring 6px outside it.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.label,
    required this.semantics,
    required this.active,
    required this.glow,
    required this.onTap,
  });

  final String label;
  final String semantics;
  final bool active;
  final bool glow;
  final VoidCallback onTap;

  static const double _size = 72;
  static const double _ring = 84;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: semantics,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Pressable(
          child: SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // The ring sits outside the disc's box, so the bar's layout
                // is the same whichever screen is showing.
                Positioned(
                  left: (_size - _ring) / 2,
                  top: (_size - _ring) / 2,
                  width: _ring,
                  height: _ring,
                  child: AnimatedOpacity(
                    key: const ValueKey('nav-disc-ring'),
                    opacity: active ? 1 : 0,
                    duration: Motion.of(context).fade,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.pal.onBackground,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                    border: Border.all(color: context.pal.background, width: 6),
                    boxShadow: glow
                        ? [
                            BoxShadow(
                              color: context.pal.accent.withValues(alpha: 0.3),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: SizedBox.square(
                    dimension: _size,
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          height: 20 / 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: AppColors.accentText,
                        ),
                      ),
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
