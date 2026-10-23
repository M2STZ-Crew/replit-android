import 'package:flutter/material.dart';

import '../../models/area_view.dart';
import '../../models/coordinator_powers.dart';
import '../../theme.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../responder/responder_status.dart';
import '../subadmin/post_incident_report_screen.dart';
import 'area_decision_screen.dart';
import 'coordinator_feed.dart';
import 'coordinator_shell.dart';
import 'overlap_screen.dart';

/// Which part of the queue is showing.
enum QueueSegment { decide, active, file }

/// The Queue tab (06 · C01–C03): what needs this coordinator, in three
/// counted segments — To decide (coral), Active (red), To file (green).
class QueueTab extends StatefulWidget {
  const QueueTab({super.key, required this.feed, required this.shell});

  final CoordinatorFeed feed;
  final CoordinatorShellState shell;

  @override
  State<QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends State<QueueTab> {
  QueueSegment _segment = QueueSegment.decide;

  CoordinatorFeed get _feed => widget.feed;
  CoordinatorPowers get _powers => CoordinatorPowers.of(_feed.me);

  /// What a new Area asks this coordinator's agency for: "Fire", "Police".
  String get _askedWord => switch (_feed.agency) {
    'police' => 'Police',
    'medical' => 'Medical',
    'barangay' => 'Barangay',
    _ => 'Fire',
  };

  /// "Pasay Fire Volunteers · Team 2": whose queue this is.
  String get _team {
    final org = (_feed.me['organization_name'] as String?)?.trim();
    final agency = responderAgencyLabel(_feed.agency);
    return org == null || org.isEmpty ? agency : org;
  }

  Future<void> _decide(AreaView area) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AreaDecisionScreen(
          areaId: area.id,
          me: _feed.me,
          api: _feed.api,
          onLive: widget.shell.showLive,
        ),
      ),
    );
    await _feed.load();
  }

  Future<void> _file(AreaView area) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostIncidentReportScreen(
          areaId: area.id,
          designation: area.designation,
          api: _feed.api,
        ),
      ),
    );
    await _feed.load();
  }

  Future<void> _review(Map<String, dynamic> overlap) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OverlapScreen(overlap: overlap, feed: _feed),
      ),
    );
    await _feed.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _feed,
      builder: (context, _) => SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabHeader(eyebrow: _team, title: 'Queue'),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _segments(),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _segments() {
    final counts = {
      QueueSegment.decide: _feed.toDecide.length,
      QueueSegment.active: _feed.active.length,
      QueueSegment.file: _feed.owed.length,
    };
    Widget segment(QueueSegment s, String label, SegmentTone tone) => Expanded(
      child: CountSegment(
        count: counts[s]!,
        label: label,
        tone: tone,
        selected: _segment == s,
        onTap: () => setState(() => _segment = s),
      ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          segment(QueueSegment.decide, 'To decide', SegmentTone.attention),
          const SizedBox(width: 8),
          segment(QueueSegment.active, 'Active', SegmentTone.live),
          const SizedBox(width: 8),
          segment(QueueSegment.file, 'To file', SegmentTone.settled),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_feed.loaded) {
      return _feed.error == null
          ? Center(child: CircularProgressIndicator(color: context.pal.accent))
          : EmptyState(
              title: 'Queue unavailable',
              body: _feed.error!,
              action: AppButton.secondary('Try again', onPressed: _feed.load),
            );
    }
    final children = switch (_segment) {
      QueueSegment.decide => _decideList(),
      QueueSegment.active => _activeList(),
      QueueSegment.file => _fileList(),
    };
    return RefreshIndicator(
      color: context.pal.accent,
      onRefresh: _feed.load,
      child: ScrollFade(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            MediaQuery.paddingOf(context).bottom + kScrollFadeEndPadding,
          ),
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }

  String _areas(int n) => n == 1 ? '1 area' : '$n areas';

  List<Widget> _decideList() {
    final areas = _feed.toDecide;
    return [
      for (final o in _feed.overlaps.take(1)) _overlapAlert(o),
      if (areas.isEmpty)
        _Empty(
          title: 'Nothing to decide',
          body: 'A new Area that asks for $_askedWord lands here first.',
        )
      else ...[
        SectionHeader('Waiting on you', meta: _areas(areas.length)),
        for (final (i, a) in areas.indexed)
          _card(
            a,
            action: 'Decide',
            onTap: () => _decide(a),
            // The newest is the one to look at first.
            emphasis: i == 0 ? AreaEmphasis.attention : AreaEmphasis.normal,
            facts: true,
          ),
      ],
      if (_powers.rejects)
        const InlineAlert(
          body:
              'Any responding agency can accept. Only a Fire Volunteer or BFP '
              'coordinator can reject.',
        )
      else
        // 06 · C01P: a PNP Coordinator's queue.
        InlineAlert(
          body:
              'These Areas asked for $_askedWord. Accepting acknowledges them '
              'for $_team. Only a Fire Volunteer or BFP Coordinator can '
              'reject.',
        ),
    ];
  }

  Widget _overlapAlert(Map<String, dynamic> o) {
    final a = _designation(o['area_a_designation']);
    final b = _designation(o['area_b_designation']);
    final metres = (o['distance_m'] as num?)?.round();
    return InlineAlert(
      tone: AlertTone.warning,
      title: '$a and $b overlap',
      body:
          '${metres == null ? 'They are close' : 'They are $metres m apart'}. '
          'Merge them into one incident or keep them separate.',
      action: 'Review',
      onAction: () => _review(o),
    );
  }

  List<Widget> _activeList() {
    final ground = [
      for (final a in _feed.active)
        if (a.live) a,
    ];
    final nobody = [
      for (final a in _feed.active)
        if (!a.live) a,
    ];
    return [
      if (ground.isEmpty && nobody.isEmpty)
        const _Empty(
          title: 'Nothing under way',
          body:
              'An Area you or another agency accepts shows here until the '
              'fire is out.',
        ),
      if (ground.isNotEmpty) ...[
        SectionHeader('On the ground', meta: _areas(ground.length)),
        for (final a in ground)
          _card(
            a,
            action: 'Open',
            onTap: () => widget.shell.showLive(a.id),
            emphasis: AreaEmphasis.live,
            note: _groundNote(a),
          ),
      ],
      if (nobody.isNotEmpty) ...[
        SectionHeader(
          'Accepted, nobody going yet',
          meta: _areas(nobody.length),
        ),
        for (final a in nobody)
          _card(
            a,
            action: 'Open',
            onTap: () => _decide(a),
            emphasis: AreaEmphasis.attention,
            note: _acceptedNote(a),
          ),
      ],
      const InlineAlert(
        body:
            'Only staff see who accepted. The public map shows status, '
            'confidence and report count — never who is responding.',
      ),
    ];
  }

  String? _acceptedNote(AreaView a) {
    final at = a.at('verified_at');
    final who = andList([for (final g in a.accepted) agencyWord(g)]);
    if (at == null && who.isEmpty) return null;
    return [
      if (at != null) 'Accepted ${clockText(at)}',
      if (who.isNotEmpty) who,
    ].join(' · ');
  }

  String? _groundNote(AreaView a) {
    final arrived = a.at('arrived_at');
    if (a.status == 'arrived' && arrived != null) {
      final who = andList([for (final g in a.accepted) agencyWord(g)]);
      return 'Arrived ${clockText(arrived)}${who.isEmpty ? '' : ' · $who'}';
    }
    final going = a.respondingCount;
    final accepted = _acceptedNote(a);
    final units = going == 1 ? '1 responding' : '$going responding';
    return [?accepted, if (going > 0) units].join(' · ');
  }

  List<Widget> _fileList() {
    final owed = _feed.owed;
    return [
      if (owed.isEmpty)
        const _Empty(
          title: 'Nothing to file',
          body: 'When a fire your team went to is out, its report waits here.',
        )
      else ...[
        SectionHeader('Reports to file', meta: _areas(owed.length)),
        for (final a in owed)
          _card(
            a,
            action: 'File report',
            onTap: () => _file(a),
            emphasis: _waitingLong(a)
                ? AreaEmphasis.attention
                : AreaEmphasis.normal,
            note: _fileNote(a),
          ),
      ],
      const InlineAlert(
        body:
            'An Area closes only after its post-incident report is filed. '
            'There is no draft — the form saves once, when it is complete.',
      ),
    ];
  }

  bool _waitingLong(AreaView a) {
    final out = a.at('resolved_at');
    return out != null && DateTime.now().difference(out).inHours >= 12;
  }

  String? _fileNote(AreaView a) {
    final out = a.at('resolved_at');
    if (out == null) return null;
    final hours = DateTime.now().difference(out).inHours;
    return 'Fire out ${whenText(out)} · '
        '${hours >= 1 ? 'waiting $hours h' : 'ready to file'}';
  }

  Widget _card(
    AreaView a, {
    required String action,
    required VoidCallback onTap,
    AreaEmphasis emphasis = AreaEmphasis.normal,
    bool facts = false,
    String? note,
  }) {
    final reported = a.reportedAt;
    return AreaPlace(
      area: a,
      builder: (context, place) => AreaCard(
        status: a.status,
        agency: _feed.agency ?? 'fire_volunteer',
        title: a.name,
        place: placeLine(a, place),
        facts: facts
            ? [
                ('Reports', '${a.reports}'),
                ('Confidence', a.confidence),
                ('Reported', reported == null ? '—' : agoText(reported)),
              ]
            : const [],
        note: note,
        action: action,
        onTap: onTap,
        emphasis: emphasis,
      ),
    );
  }
}

String _designation(Object? d) {
  final s = (d as String?) ?? '';
  return s.toLowerCase().startsWith('area') ? s : 'Area $s';
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: EmptyState(title: title, body: body),
  );
}
