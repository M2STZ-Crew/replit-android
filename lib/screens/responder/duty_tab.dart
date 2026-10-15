import 'package:flutter/material.dart';

import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import 'responder_feed.dart';
import 'responder_incident_screen.dart';
import 'responder_shell.dart';
import 'responder_status.dart';

/// Duty (REPLIT (MAIN) 07 · R01, R02): what needs this unit now.
///
/// Whether the responder's location is going out, their run if they are on
/// one, every live Area their agency sees that they are not on — the newest
/// first and edged for attention — and the counters behind the old
/// dashboard. With nothing waiting, the empty state says what will arrive
/// and that the screen can be left.
///
/// R02's "Last run" card needs a list of this responder's past runs, which
/// no endpoint gives, so it is not drawn; the run of this session shows as
/// "Your run" until they go back to duty.
class DutyTab extends StatelessWidget {
  const DutyTab({super.key, required this.feed, required this.shell});

  final ResponderFeed feed;
  final ResponderShellState shell;

  Future<void> _review(BuildContext context, AreaView area) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResponderIncidentScreen(
          incidentId: area.id,
          myId: feed.myId,
          agency: feed.agency,
          orgId: feed.orgId,
          unit: feed.unit,
          api: feed.api,
          tracker: feed.tracker,
        ),
      ),
    );
    await feed.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) => SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabHeader(
              eyebrow: '${feed.unit} — ${agencyLabel(feed.agency)}',
              title: 'Duty',
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!feed.loaded) {
      return feed.error == null
          ? Center(child: CircularProgressIndicator(color: context.pal.accent))
          : EmptyState(
              icon: AppIcons.cloudOff,
              tone: context.pal.live,
              title: 'Could not reach command',
              body: feed.error!,
              action: AppButton.secondary('Try again', onPressed: feed.load),
            );
    }
    final waiting = feed.needsUnit;
    final runId = feed.runId;
    final run = runId == null ? null : feed.byId(runId);
    final sharing = feed.tracker.isSharing;
    return ScrollFade(
      child: RefreshIndicator(
        onRefresh: feed.load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.paddingOf(context).bottom + kScrollFadeEndPadding,
          ),
          children: [
            if (waiting.isEmpty) ...[
              _NothingWaiting(unit: feed.unit, agency: feed.agency),
              const SizedBox(height: 16),
              _sharingAlert(run, sharing),
            ] else ...[
              _sharingAlert(run, sharing),
              const SizedBox(height: 20),
            ],
            if (run != null) ...[
              if (waiting.isEmpty) const SizedBox(height: 20),
              const SectionHeader('Your run'),
              const SizedBox(height: 12),
              _card(
                context,
                run,
                action: 'Open run',
                emphasis: run.live ? AreaEmphasis.live : AreaEmphasis.normal,
                onTap: () => shell.show(ResponderTab.run),
              ),
              const SizedBox(height: 20),
            ],
            if (waiting.isNotEmpty) ...[
              SectionHeader(
                'Needs a unit',
                meta: waiting.length == 1
                    ? '1 Area'
                    : '${waiting.length} Areas',
              ),
              const SizedBox(height: 12),
              for (final (i, a) in waiting.indexed) ...[
                _card(
                  context,
                  a,
                  action: 'Review',
                  // The newest is the one to look at first.
                  emphasis: i == 0
                      ? AreaEmphasis.attention
                      : AreaEmphasis.normal,
                  onTap: () => _review(context, a),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
            ],
            if (feed.stats case final stats?) ...[
              if (waiting.isEmpty && run == null) const SizedBox(height: 20),
              const SectionHeader('Pasay now'),
              const SizedBox(height: 12),
              _Counters(stats: stats),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sharingAlert(AreaView? run, bool sharing) {
    if (sharing) {
      return InlineAlert(
        tone: AlertTone.success,
        title: 'Location sharing is on',
        body:
            'Command sees where you are while you are on '
            '${run?.name ?? 'your run'}. It stops when the Captain marks fire '
            'out.',
        action: 'Open run',
        onAction: () => shell.show(ResponderTab.run),
      );
    }
    return const InlineAlert(
      title: 'Location sharing is off',
      body:
          'It starts when you tap I am going and stops when the Captain marks '
          'fire out.',
    );
  }

  Widget _card(
    BuildContext context,
    AreaView a, {
    required String action,
    required VoidCallback onTap,
    AreaEmphasis emphasis = AreaEmphasis.normal,
  }) {
    final reported = a.reportedAt;
    return AreaPlace(
      area: a,
      builder: (context, place) => AreaCard(
        status: a.status,
        title: a.name,
        place: placeLine(a, place),
        facts: [
          ('Reports', '${a.reports}'),
          ('Confidence', a.confidence),
          ('Reported', reported == null ? '—' : agoText(reported)),
        ],
        action: action,
        onTap: onTap,
        emphasis: emphasis,
      ),
    );
  }
}

/// R02 — nothing waiting: what will arrive, and that the screen can be left.
class _NothingWaiting extends StatelessWidget {
  const _NothingWaiting({required this.unit, required this.agency});

  final String unit;
  final String? agency;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        children: [
          const IconPlate(AppIcons.inbox),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              'No Area needs $unit'.toUpperCase(),
              textAlign: TextAlign.center,
              style: context.type.cardTitle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When an Area asks for ${agencyLabel(agency)} it arrives here '
            'with an alert sound. You can leave this screen.',
            textAlign: TextAlign.center,
            style: context.type.bodySm.copyWith(color: pal.textSoft),
          ),
        ],
      ),
    );
  }
}

/// The counters GET /incidents/stats returns for this agency — the old
/// dashboard's four, read as they are; none is invented.
class _Counters extends StatelessWidget {
  const _Counters({required this.stats});

  final Map<String, dynamic> stats;

  String _n(String key) => '${(stats[key] as num?)?.toInt() ?? '—'}';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: _n('active_incidents'),
                label: 'Live now',
                color: pal.live,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: _n('pending_verify'),
                label: 'To verify',
                color: pal.warn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatTile(value: _n('units_deployed'), label: 'Units out'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(value: _n('units_standby'), label: 'Standby'),
            ),
          ],
        ),
      ],
    );
  }
}
