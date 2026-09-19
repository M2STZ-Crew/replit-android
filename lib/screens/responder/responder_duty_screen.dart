import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../location/responder_tracker.dart';
import '../../theme.dart';
import '../../widgets/design.dart';
import '../../widgets/responder_nav_bar.dart';
import 'responder_incident_screen.dart';
import 'responder_incidents_screen.dart';
import 'responder_status.dart';

/// "02 Duty — standby" from the RESPONSE TEAM hand-off.
///
/// What a responder needs before a run: whether anything is happening, whether
/// they are on it, and whether their location is going out. Everything on this
/// screen is read from the API — which is why it does not match the frame
/// figure for figure.
///
/// The frame's three counters are "runs this month", "this week" and "right
/// now". `GET /incidents/stats` has no per-responder run history — no endpoint
/// counts a person's past runs — so the tiles show what it does return:
/// incidents live now, units out, and whether this responder is one of them.
/// The frame's unit card names a truck ("Tanker 1"), its driver and its crew
/// size; no endpoint assigns a vehicle or a crew to a responder, so the card
/// names the organisation they answer for instead (§2.7.1).
class ResponderDutyScreen extends StatefulWidget {
  const ResponderDutyScreen({super.key, required this.me, this.api});

  final Map<String, dynamic> me;
  final ApiClient? api;

  @override
  State<ResponderDutyScreen> createState() => _ResponderDutyScreenState();
}

class _ResponderDutyScreenState extends State<ResponderDutyScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final ResponderTracker _tracker = ResponderTracker.instance;

  Timer? _poll;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _run;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getIncidentStats(),
        _api.getIncidents(activeOnly: true),
      ]);
      if (!mounted) return;
      final incidents = (results[1] as List).cast<Map<String, dynamic>>();
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _run = _mine(incidents);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not reach command. Retrying.';
        });
      }
    }
  }

  /// The incident this responder is on, if any: the one the tracker is
  /// broadcasting for, else the first they are dispatched to.
  Map<String, dynamic>? _mine(List<Map<String, dynamic>> incidents) {
    final tracking = _tracker.sharingFor.value;
    for (final i in incidents) {
      if (i['id'] == tracking) return i;
    }
    for (final i in incidents) {
      final status = '${i['status']}';
      if (status == 'dispatched' ||
          status == 'en_route' ||
          status == 'arrived') {
        if (i['i_am_dispatched'] == true) return i;
      }
    }
    return null;
  }

  Future<void> _openRun() async {
    final run = _run;
    if (run == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResponderIncidentScreen(
          incidentId: '${run['id']}',
          myId: '${widget.me['id']}',
          agency: widget.me['agency_type'] as String?,
          orgId: widget.me['primary_org_id'] as String?,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _openRuns() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResponderIncidentsScreen(me: widget.me),
      ),
    );
  }

  String get _unitName {
    final org = widget.me['organization_name'] as String?;
    if (org != null && org.trim().isNotEmpty) return org;
    return agencyLabel(widget.me['agency_type'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final stats = _stats;
    final sharing = _tracker.isSharing;

    return Scaffold(
      backgroundColor: context.pal.background,
      extendBody: true,
      bottomNavigationBar: ResponderNavBar(
        active: ResponderTab.duty,
        me: widget.me,
        onRun: run == null ? null : _openRun,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              24 + ResponderNavBar.overhang,
            ),
            children: [
              Eyebrow(
                '$_unitName · ${agencyLabel(widget.me['agency_type'] as String?)}',
                color: context.pal.label,
              ),
              const SizedBox(height: 8),
              Text('DUTY', style: context.type.title),
              const SizedBox(height: 22),
              _counts(stats, run),
              const SizedBox(height: 26),
              Eyebrow(
                run == null ? 'Standby' : 'On a run',
                color: run == null ? context.pal.ok : context.pal.accentInk,
              ),
              const SizedBox(height: 12),
              _unitCard(),
              const SizedBox(height: 10),
              _runCard(run),
              const SizedBox(height: 10),
              _sharingCard(sharing, run),
              const SizedBox(height: 16),
              _ruleNote(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: context.type.caption.copyWith(color: context.pal.live),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- pieces ---
  Widget _counts(Map<String, dynamic>? stats, Map<String, dynamic>? run) {
    final live = (stats?['active_incidents'] as num?)?.toInt() ?? 0;
    final out = (stats?['units_deployed'] as num?)?.toInt() ?? 0;
    return Row(
      children: [
        Expanded(
          child: StatTile(value: _loading ? '—' : '$live', label: 'Live now'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(value: _loading ? '—' : '$out', label: 'Units out'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatTile(
            value: run == null ? '0' : '1',
            label: 'Your run',
            color: run == null ? context.pal.ok : context.pal.accentInk,
          ),
        ),
      ],
    );
  }

  Widget _unitCard() {
    return _DutyCard(
      icon: Icons.local_shipping_outlined,
      tint: context.pal.accentInk,
      title: _unitName.toUpperCase(),
      meta: agencyLabel(widget.me['agency_type'] as String?),
      chip: 'Your unit',
      chipTone: context.pal.accentInk,
      note: widget.me['full_name'] as String? ?? 'Response team',
      action: 'PROFILE',
      onAction: () =>
          ResponderNavBar.switchTo(context, ResponderTab.profile, widget.me),
    );
  }

  Widget _runCard(Map<String, dynamic>? run) {
    if (run == null) {
      return _DutyCard(
        icon: Icons.check_rounded,
        tint: context.pal.ok,
        title: 'NO RUN RIGHT NOW',
        meta: 'Nothing is assigned to you',
        chip: 'Clear',
        chipTone: context.pal.ok,
        note: 'A push arrives when your unit rolls',
        action: 'MY RUNS',
        onAction: _openRuns,
      );
    }
    final status = '${run['status']}';
    return _DutyCard(
      icon: Icons.local_fire_department_outlined,
      tint: responderStatusColor(status),
      title: '${run['designation'] ?? 'Incident'}'.toUpperCase(),
      meta: run['barangay'] as String? ?? 'Pasay City',
      chip: responderStatusLabel(status),
      chipTone: responderStatusColor(status),
      dot: true,
      note: 'Tap through for the brief and the map',
      action: 'OPEN',
      onAction: _openRun,
    );
  }

  Widget _sharingCard(bool sharing, Map<String, dynamic>? run) {
    return _DutyCard(
      icon: Icons.podcasts_rounded,
      tint: sharing ? context.pal.ok : context.pal.muted,
      title: 'LOCATION SHARING',
      meta: sharing
          ? 'Command can see where you are'
          : 'Starts when you are on a run',
      chip: sharing ? 'On' : 'Off',
      chipTone: sharing ? context.pal.ok : context.pal.muted,
      note: 'Broadcasts every 5 s on a run',
      action: run == null ? null : 'OPEN RUN',
      onAction: run == null ? null : _openRun,
    );
  }

  Widget _ruleNote() {
    return Panel(
      radius: AppRadius.card,
      color: context.pal.glassDim,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.pal.accentInk,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // The frame says "Accept puts your unit en route", which is the
              // v11 lifecycle. Today a coordinator dispatches and the crew
              // marks itself en route, so that is what this says.
              'A dispatch puts your unit on the run. En route and Arrived '
              'are the two statuses you set.',
              style: context.type.caption.copyWith(color: context.pal.label),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 105px card the Duty screen is made of: a tinted glyph, two lines, a
/// status chip, a hairline, and a footer that says what the row can do.
class _DutyCard extends StatelessWidget {
  const _DutyCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.meta,
    required this.chip,
    required this.chipTone,
    required this.note,
    this.action,
    this.onAction,
    this.dot = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String meta;
  final String chip;
  final Color chipTone;
  final String note;
  final String? action;
  final VoidCallback? onAction;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: onAction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconWell(tint: tint, icon: icon, size: 34, glyph: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tag(chip, color: chipTone, dot: dot),
            ],
          ),
          const SizedBox(height: 13),
          Divider(height: 1, thickness: 1, color: context.pal.line),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption,
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 10),
                Text(
                  action!,
                  style: context.type.eyebrow.copyWith(
                    color: context.pal.accentInk,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
