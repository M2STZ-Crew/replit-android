import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/push_service.dart';
import '../api/session.dart';
import '../location/responder_tracker.dart';
import '../screens/bfp/bfp_alarm_requests_screen.dart';
import '../screens/login_screen.dart';
import '../screens/responder/responder_duty_screen.dart';
import '../screens/responder/responder_incidents_screen.dart';
import '../screens/responder/responder_status.dart';
import '../screens/subadmin/pending_reports_screen.dart';
import '../screens/subadmin/subadmin_home_screen.dart';
import '../theme.dart';
import 'app_logo.dart';
import 'design.dart';
import 'notification_bell.dart';

/// The one console responders and coordinators share.
///
/// Every staff screen — dashboard, incident list, a report under review, the
/// live incident, the Post-Incident Report — sits in the same frame: a top bar
/// with Back (or the mark on a dashboard), the screen's name, a small tag
/// saying whether this is a responder or a coordinator, the bell, and the
/// menu. The menu is the same drawer everywhere, so it is reachable from deep
/// inside an incident, not only from the dashboard.
///
/// A responder and a coordinator see nearly the same console on purpose; the
/// tag and the handful of menu items only one of them has are the difference.
enum StaffRole {
  responder('Responder', Icons.local_fire_department_outlined),
  coordinator('Coordinator', Icons.shield_outlined);

  const StaffRole(this.label, this.icon);

  final String label;
  final IconData icon;

  /// A Response Team member responds; a (Fire Volunteer or BFP) sub-admin
  /// coordinates.
  static StaffRole of(Map<String, dynamic>? me) =>
      me?['role'] == 'sub_admin' ? coordinator : responder;

  /// Coral for the crews who go, the informational blue for command.
  Color colour(AppPalette pal) => this == responder ? pal.accentInk : pal.info;
}

/// The console's sections — what the menu opens.
enum StaffPage { dashboard, incidents, duty, reports, alarms }

/// The signed-in staff account, for the screens opened without one in hand
/// (the pending-report tray, the alarm queue). Set when a staff console opens.
abstract final class StaffAccount {
  static Map<String, dynamic>? current;
}

/// The frame of every staff screen: [StaffTopBar] over [body], the
/// [StaffDrawer] as the end drawer, and an optional pinned [bottom] action.
class StaffScaffold extends StatelessWidget {
  const StaffScaffold({
    super.key,
    required this.page,
    required this.title,
    required this.body,
    this.me,
    this.home = false,
    this.bottom,
  });

  /// The section this screen belongs to, lit in the menu.
  final StaffPage page;

  /// True on the section's own screen (the dashboard, the incident list), so
  /// choosing that section again from the menu only closes the menu.
  final bool home;

  final String title;
  final Widget body;

  /// The signed-in account; [StaffAccount.current] when not given.
  final Map<String, dynamic>? me;

  /// A pinned action under the body (Fire out on a live incident).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final account = me ?? StaffAccount.current;
    return Scaffold(
      backgroundColor: context.pal.background,
      endDrawer: StaffDrawer(me: account, page: page, home: home),
      bottomNavigationBar: bottom,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            StaffTopBar(me: account, title: title),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Back (or the mark, on a screen nothing sits under), the title with the
/// role tag beneath it, the bell and the menu.
class StaffTopBar extends StatelessWidget {
  const StaffTopBar({super.key, required this.title, this.me});

  final String title;
  final Map<String, dynamic>? me;

  @override
  Widget build(BuildContext context) {
    // Back when a screen sits under this one. Not ModalRoute.canPop: an open
    // menu is something Back can close, so the dashboard would grow a Back
    // arrow the moment its own menu opened.
    final route = ModalRoute.of(context);
    final canPop = route != null && !route.isFirst;
    final account = me;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: context.pal.background,
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      child: Row(
        children: [
          if (canPop)
            Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: IconWellButton(
                icon: Icons.chevron_left_rounded,
                size: 40,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            )
          else
            Image.asset(Art.mark, width: 40, height: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.screenTitle,
                ),
                if (account != null) ...[
                  const SizedBox(height: 5),
                  RoleTag(StaffRole.of(account)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const NotificationBell(),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Menu',
            excludeSemantics: true,
            child: IconWellButton(
              icon: Icons.menu_rounded,
              size: 40,
              onTap: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
    );
  }
}

/// "RESPONDER" or "COORDINATOR": the hint of whose console this is.
class RoleTag extends StatelessWidget {
  const RoleTag(this.role, {super.key});

  final StaffRole role;

  @override
  Widget build(BuildContext context) =>
      Tag(role.label, color: role.colour(context.pal), dot: true);
}

/// The console menu — one drawer for every staff screen.
///
/// Dashboard and Incidents for everyone; My duty for a responder; Pending
/// reports for a coordinator (each team files its own Post-Incident Report);
/// Alarm requests for BFP, whose authority executing them is. Choosing a
/// section goes back to the dashboard and opens it from there, so Back from
/// any section is always the dashboard.
class StaffDrawer extends StatefulWidget {
  const StaffDrawer({
    super.key,
    required this.me,
    required this.page,
    this.home = false,
    this.api,
  });

  final Map<String, dynamic>? me;
  final StaffPage page;
  final bool home;
  final ApiClient? api;

  @override
  State<StaffDrawer> createState() => _StaffDrawerState();
}

class _StaffDrawerState extends State<StaffDrawer> {
  late final ApiClient _api = widget.api ?? ApiClient();
  int _reportsOwed = 0;
  int _alarmsPending = 0;

  StaffRole get _role => StaffRole.of(widget.me);
  String? get _agency => widget.me?['agency_type'] as String?;
  bool get _bfp => _role == StaffRole.coordinator && _agency == 'bfp';

  @override
  void initState() {
    super.initState();
    if (_role == StaffRole.coordinator) _loadCounts();
  }

  /// What is waiting behind the coordinator's items, read as the menu opens.
  Future<void> _loadCounts() async {
    try {
      final stats = await _api.getIncidentStats();
      final owed = (stats['pending_reports'] as num?)?.toInt() ?? 0;
      final alarms = _bfp
          ? (await _api.getAlarmRequests(status: 'pending')).length
          : 0;
      if (mounted) {
        setState(() {
          _reportsOwed = owed;
          _alarmsPending = alarms;
        });
      }
    } catch (_) {
      // The items still open; only the counts are missing.
    }
  }

  Widget? _screenFor(StaffPage page, Map<String, dynamic> me) => switch (page) {
    StaffPage.dashboard => null,
    StaffPage.incidents =>
      _role == StaffRole.coordinator
          ? SubAdminHomeScreen(me: me)
          : ResponderIncidentsScreen(me: me),
    StaffPage.duty => ResponderDutyScreen(me: me),
    StaffPage.reports => const PendingReportsScreen(),
    StaffPage.alarms => const BfpAlarmRequestsScreen(),
  };

  void _open(StaffPage page) {
    final nav = Navigator.of(context);
    nav.pop(); // the menu
    if (page == widget.page && widget.home) return;
    final me = widget.me ?? const <String, dynamic>{};
    nav.popUntil((route) => route.isFirst);
    final screen = _screenFor(page, me);
    if (screen != null) {
      nav.push(MaterialPageRoute<void>(builder: (_) => screen));
    }
  }

  Future<void> _signOut() async {
    final nav = Navigator.of(context);
    nav.pop();
    await staffSignOut(nav, api: _api);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final name =
        (me?['full_name'] as String?) ?? (me?['email'] as String?) ?? 'Staff';
    final team = (me?['organization_name'] as String?)?.trim();
    final agency = responderAgencyLabel(_agency);
    return Drawer(
      backgroundColor: context.pal.background,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(width: 118, height: 32),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.cardTitle,
                  ),
                  const SizedBox(height: 8),
                  RoleTag(_role),
                  const SizedBox(height: 8),
                  Text(
                    team == null || team.isEmpty ? agency : '$team · $agency',
                    style: context.type.caption,
                  ),
                ],
              ),
            ),
            Divider(color: context.pal.line, height: 1),
            const SizedBox(height: 8),
            _item(Icons.dashboard_outlined, 'Dashboard', StaffPage.dashboard),
            _item(Icons.list_alt_rounded, 'Incidents', StaffPage.incidents),
            if (_role == StaffRole.responder)
              _item(Icons.badge_outlined, 'My duty', StaffPage.duty),
            if (_role == StaffRole.coordinator)
              _item(
                Icons.assignment_late_outlined,
                'Pending reports',
                StaffPage.reports,
                count: _reportsOwed,
              ),
            if (_bfp)
              _item(
                Icons.campaign_outlined,
                'Alarm requests',
                StaffPage.alarms,
                count: _alarmsPending,
              ),
            const Spacer(),
            Divider(color: context.pal.line, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                leading: Icon(Icons.logout_rounded, color: context.pal.live),
                title: Text(
                  'Log out',
                  style: context.type.label.copyWith(color: context.pal.live),
                ),
                onTap: _signOut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, StaffPage page, {int count = 0}) {
    final selected = page == widget.page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: context.pal.accentInk.withValues(alpha: 0.1),
        selectedColor: context.pal.accentInk,
        iconColor: context.pal.textSoft,
        textColor: context.pal.onBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        leading: Icon(icon, size: 20),
        title: Text(
          label,
          style: context.type.label.copyWith(
            color: selected ? context.pal.accentInk : null,
          ),
        ),
        trailing: count > 0
            ? Tag('$count', color: context.pal.live, solid: true)
            : null,
        onTap: () => _open(page),
      ),
    );
  }
}

/// Sign a staff member out: stop sharing their location, stop pushes to this
/// phone, end the session, and go to the login screen.
Future<void> staffSignOut(NavigatorState nav, {ApiClient? api}) async {
  await ResponderTracker.instance.stop();
  try {
    await PushService.instance.unregister();
  } catch (_) {
    // A phone that never registered has nothing to unregister.
  }
  try {
    await (api ?? ApiClient()).logout();
  } catch (_) {
    // Signed out on the phone regardless.
  }
  await Session.instance.clear();
  StaffAccount.current = null;
  nav.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
