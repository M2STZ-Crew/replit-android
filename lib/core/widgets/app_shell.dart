import 'package:flutter/material.dart';

import '../../features/guides/presentation/screens/safety_guides_screen.dart';
import '../../features/hotlines/presentation/screens/hotlines_screen.dart';
import '../../features/map/presentation/screens/map_home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reports/presentation/screens/sos_screen.dart';
import '../theme/app_theme.dart';
import 'app_nav_bar.dart';

/// The citizen app: four tabs over one persistent scaffold.
///
/// The tabs are kept alive in an IndexedStack rather than rebuilt on switch.
/// The map is the expensive one — re-fetching layers and re-tiling every time
/// someone glances at the hotlines would be wasteful, and worse, would lose
/// the map's pan position mid-emergency.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.map;

  void _go(AppTab tab) => setState(() => _tab = tab);

  void _openProfile() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // The map runs edge to edge under the status bar; the other tabs handle
      // their own top inset, so the body is never wrapped in a SafeArea here.
      extendBody: true,
      body: IndexedStack(
        index: AppTab.values.indexOf(_tab),
        children: [
          MapHomeScreen(
            onSos: () => _go(AppTab.sos),
            onProfile: _openProfile,
          ),
          SosScreen(onProfile: _openProfile),
          HotlinesScreen(onProfile: _openProfile),
          SafetyGuidesScreen(onProfile: _openProfile),
        ],
      ),
      bottomNavigationBar: AppNavBar(active: _tab, onSelect: _go),
    );
  }
}
