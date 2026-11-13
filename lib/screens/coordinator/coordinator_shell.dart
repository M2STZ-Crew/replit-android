import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_nav_bar.dart';
import 'codes_tab.dart';
import 'coordinator_feed.dart';
import 'live_incident.dart';
import 'map_tab.dart';
import 'profile_tab.dart';
import 'queue_tab.dart';
import '../../i18n/i18n.dart';
import '../../updates/update_banner.dart';
import '../../widgets/responsive_frame.dart';

/// The coordinator's five destinations (REPLIT (MAIN) 06 · Coordinator
/// Experience): Queue, Map, the raised LIVE disc, Codes, Profile.
enum CoordinatorTab {
  queue('Queue', AppIcons.inbox),
  map('Map', AppIcons.map),
  live('LIVE', AppIcons.circle),
  codes('Codes', AppIcons.gridView),
  profile('Profile', AppIcons.person);

  const CoordinatorTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Every organisation's coordinator app: one bar, five tabs, and the shared
/// [CoordinatorFeed] they read from. A Police, Medical or Barangay
/// coordinator gets the same tabs (06 · C01P) with only what the server lets
/// them do ([CoordinatorPowers]).
///
/// Tabs keep their place when you leave them (an IndexedStack), and are built
/// the first time they are opened. Detail screens — an Area, an overlap, the
/// Post-Incident Report — are pushed over the whole shell, so they hide the
/// bar and Back returns to the tab they were opened from (06 · 09).
class CoordinatorShell extends StatefulWidget {
  const CoordinatorShell({
    super.key,
    required this.me,
    this.api,
    this.startOn = CoordinatorTab.queue,
  });

  final Map<String, dynamic> me;
  final ApiClient? api;
  final CoordinatorTab startOn;

  static CoordinatorShellState? _mounted;

  /// Bring the mounted shell to LIVE on [areaId], closing anything pushed
  /// over it. False when no coordinator shell is showing.
  static bool showLive(NavigatorState nav, String areaId) {
    final shell = _mounted;
    if (shell == null || !shell.mounted) return false;
    nav.popUntil((route) => route.isFirst);
    shell.showLive(areaId);
    return true;
  }

  /// Bring the mounted shell back to the Queue, closing anything pushed over
  /// it. False when no coordinator shell is showing.
  static bool showQueue(NavigatorState nav) {
    final shell = _mounted;
    if (shell == null || !shell.mounted) return false;
    nav.popUntil((route) => route.isFirst);
    shell.show(CoordinatorTab.queue);
    return true;
  }

  @override
  State<CoordinatorShell> createState() => CoordinatorShellState();
}

class CoordinatorShellState extends State<CoordinatorShell> {
  late final CoordinatorFeed feed = CoordinatorFeed(
    me: widget.me,
    api: widget.api,
  )..start();

  late CoordinatorTab _tab = widget.startOn;
  late final Set<CoordinatorTab> _built = {_tab};

  /// The Area LIVE shows; null lets it choose.
  String? _liveFocus;

  CoordinatorTab get tab => _tab;

  @override
  void initState() {
    super.initState();
    CoordinatorShell._mounted = this;
  }

  @override
  void dispose() {
    if (CoordinatorShell._mounted == this) CoordinatorShell._mounted = null;
    feed.dispose();
    super.dispose();
  }

  void show(CoordinatorTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _built.add(tab);
    });
  }

  void showLive(String areaId) {
    setState(() {
      _liveFocus = areaId;
      _tab = CoordinatorTab.live;
      _built.add(CoordinatorTab.live);
    });
  }

  Widget _build(CoordinatorTab tab) => switch (tab) {
    // The reading tabs keep the column on a tablet; the map and LIVE
    // fill it (v1.12.43).
    CoordinatorTab.queue => ReadingColumn(
      child: QueueTab(feed: feed, shell: this),
    ),
    CoordinatorTab.map => MapTab(feed: feed, shell: this),
    CoordinatorTab.live => LiveTab(
      feed: feed,
      focus: _liveFocus,
      visible: _tab == CoordinatorTab.live,
      onFocus: (id) => setState(() => _liveFocus = id),
    ),
    CoordinatorTab.codes => ReadingColumn(
      child: CodesTab(feed: feed, focus: _liveFocus),
    ),
    CoordinatorTab.profile => ReadingColumn(child: ProfileTab(feed: feed)),
  };

  @override
  Widget build(BuildContext context) => FullBleed(child: _fullScreen(context));

  /// The screen, filling a tablet (v1.12.43: maps full, the rest
  /// centred).
  Widget _fullScreen(BuildContext context) {
    return PopScope(
      // Back from any other tab is the queue; Back from the queue leaves.
      canPop: _tab == CoordinatorTab.queue,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) show(CoordinatorTab.queue);
      },
      child: Scaffold(
        backgroundColor: context.pal.background,
        // The map and LIVE draw under the bar's raised disc.
        extendBody: true,
        // "There's a new update!" above the home tab, while one is waiting.
        body: UpdateBannerSlot(
          visible: _tab == CoordinatorTab.queue,
          child: IndexedStack(
            index: _tab.index,
            children: [
              for (final t in CoordinatorTab.values)
                TickerMode(
                  enabled: t == _tab,
                  child: _built.contains(t)
                      ? _build(t)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        bottomNavigationBar: NavBarShell(
          disc: t('LIVE'),
          discLabel: t('Live — the incident under way'),
          discActive: _tab == CoordinatorTab.live,
          onDisc: () => show(CoordinatorTab.live),
          items: [
            for (final tab in CoordinatorTab.values)
              (
                icon: tab.icon,
                label: t(tab.label),
                selected: tab == _tab,
                onTap: () => show(tab),
              ),
          ],
        ),
      ),
    );
  }
}
