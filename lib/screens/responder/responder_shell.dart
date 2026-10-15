import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../location/responder_tracker.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_nav_bar.dart';
import '../notifications_screen.dart';
import 'duty_tab.dart';
import 'field_map_tab.dart';
import 'responder_feed.dart';
import 'responder_profile_tab.dart';
import 'run_tab.dart';

/// The responder's five destinations (REPLIT (MAIN) 07 · Responder): Duty,
/// Map, the raised RUN disc, Alerts, Profile.
///
/// Figma's fourth slot is Runs (R12), a history of this responder's runs. No
/// endpoint lists a responder's past runs, so Runs stays on standby and the
/// slot holds Alerts — the inbox of every call and stand-down sent to them,
/// which the old console reached from the bell.
enum ResponderTab {
  duty('Duty', AppIcons.inbox),
  map('Map', AppIcons.map),
  run('RUN', AppIcons.circle),
  alerts('Alerts', AppIcons.notifications),
  profile('Profile', AppIcons.person);

  const ResponderTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The Response Team member's app: one bar, five tabs, and the shared
/// [ResponderFeed] they read from — the same bar and disc as the resident's
/// SOS and the coordinator's LIVE ([NavBarShell]).
///
/// Tabs keep their place when you leave them (an IndexedStack), and are built
/// the first time they are opened. An Area's brief is pushed over the whole
/// shell, so Back returns to the tab it was opened from.
class ResponderShell extends StatefulWidget {
  const ResponderShell({
    super.key,
    required this.me,
    this.api,
    this.tracker,
    this.startOn = ResponderTab.duty,
  });

  final Map<String, dynamic> me;
  final ApiClient? api;
  final ResponderTracker? tracker;
  final ResponderTab startOn;

  @override
  State<ResponderShell> createState() => ResponderShellState();
}

class ResponderShellState extends State<ResponderShell> {
  late final ResponderFeed feed = ResponderFeed(
    me: widget.me,
    api: widget.api,
    tracker: widget.tracker,
  )..start();

  late ResponderTab _tab = widget.startOn;
  late final Set<ResponderTab> _built = {_tab};

  ResponderTab get tab => _tab;

  @override
  void dispose() {
    feed.dispose();
    super.dispose();
  }

  void show(ResponderTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _built.add(tab);
    });
  }

  /// "Back to duty" from a run that has ended.
  void backToDuty() {
    feed.clearRun();
    show(ResponderTab.duty);
  }

  Widget _build(ResponderTab tab) => switch (tab) {
    ResponderTab.duty => DutyTab(feed: feed, shell: this),
    ResponderTab.map => FieldMapTab(feed: feed, shell: this),
    ResponderTab.run => RunTab(feed: feed, shell: this),
    ResponderTab.alerts => NotificationsScreen(api: feed.api, asTab: true),
    ResponderTab.profile => ResponderProfileTab(feed: feed),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from any other tab is Duty; Back from Duty leaves.
      canPop: _tab == ResponderTab.duty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) show(ResponderTab.duty);
      },
      child: Scaffold(
        backgroundColor: context.pal.background,
        // The field map draws under the bar's raised disc.
        extendBody: true,
        body: IndexedStack(
          index: _tab.index,
          children: [
            for (final t in ResponderTab.values)
              TickerMode(
                enabled: t == _tab,
                child: _built.contains(t) ? _build(t) : const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: NavBarShell(
          disc: 'RUN',
          discLabel: 'Run — the Area you are going to',
          discActive: _tab == ResponderTab.run,
          onDisc: () => show(ResponderTab.run),
          items: [
            for (final t in ResponderTab.values)
              (
                icon: t.icon,
                label: t.label,
                selected: t == _tab,
                onTap: () => show(t),
              ),
          ],
        ),
      ),
    );
  }
}
