import 'package:flutter/material.dart';

import '../screens/profile_screen.dart';
import '../screens/responder/responder_duty_screen.dart';
import '../screens/responder/responder_home_screen.dart';
import '../screens/responder/responder_incidents_screen.dart';
import 'app_nav_bar.dart';
import 'design.dart';

/// The five slots of the Response Team bar (COMPONENTS: NavBar (Responder)):
/// Duty, Map, RUN, Unit, Profile.
///
/// RUN is the raised disc, where SOS sits on the resident's bar: the run the
/// responder is on, which is the one thing they need to reach without looking.
enum ResponderTab {
  duty('Duty', Art.navDuty),
  map('Map', Art.navMap),
  run('RUN', null),
  unit('Unit', Art.navUnit),
  profile('Profile', Art.navProfile);

  const ResponderTab(this.label, this.icon);

  final String label;

  /// Tab glyph; null for RUN, which is drawn as the disc.
  final String? icon;
}

/// The Response Team's bottom bar.
///
/// Like the resident's, each tab is its own route: switching clears the stack,
/// so Back leaves the app rather than walking through every tab visited.
class ResponderNavBar extends StatelessWidget {
  const ResponderNavBar({
    super.key,
    required this.active,
    required this.me,
    this.onRun,
  });

  final ResponderTab active;

  /// How far the RUN disc rises above the bar — see [NavBarShell.overhang].
  static const double overhang = NavBarShell.overhang;

  /// The signed-in responder, from GET /auth/me — every tab needs it.
  final Map<String, dynamic> me;

  /// What the RUN disc does. Null when there is no run to go to, in which
  /// case the disc says so rather than opening an empty screen.
  final VoidCallback? onRun;

  static void switchTo(
    BuildContext context,
    ResponderTab tab,
    Map<String, dynamic> me,
  ) {
    // Map, Unit and Profile still show the screens built before this
    // hand-off; their own frames (09, 12, 15) are next.
    final screen = switch (tab) {
      ResponderTab.duty => ResponderDutyScreen(me: me),
      ResponderTab.map => ResponderHomeScreen(me: me),
      ResponderTab.unit => ResponderIncidentsScreen(me: me),
      ResponderTab.profile => const ProfileScreen(),
      ResponderTab.run => ResponderDutyScreen(me: me),
    };
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (_) => false,
    );
  }

  void _go(BuildContext context, ResponderTab tab) {
    if (tab == active) return;
    switchTo(context, tab, me);
  }

  @override
  Widget build(BuildContext context) {
    return NavBarShell(
      disc: 'RUN',
      discActive: active == ResponderTab.run,
      onDisc: () {
        final run = onRun;
        if (run != null) {
          run();
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No run right now.')));
      },
      items: [
        for (final tab in ResponderTab.values)
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
