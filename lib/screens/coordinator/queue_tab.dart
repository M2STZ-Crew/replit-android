import 'package:flutter/material.dart';

import '../../models/alarm.dart';
import '../../models/area_view.dart';
import '../../models/coordinator_powers.dart';
import '../../theme.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/report_fire_button.dart';
import '../bfp/bfp_alarm_requests_screen.dart';
import '../responder/responder_status.dart';
import '../subadmin/post_incident_report_screen.dart';
import 'area_decision_screen.dart';
import 'coordinator_feed.dart';
import 'coordinator_shell.dart';
import 'overlap_screen.dart';
import '../../widgets/loading.dart';
import '../../i18n/i18n.dart';

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
    'police' => t('Police'),
    'medical' => t('Medical'),
    'barangay' => t('Barangay'),
    _ => t('Fire'),
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

  Future<void> _answerAlarm(AlarmRequest first) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            BfpAlarmRequestsScreen(api: _feed.api, focusRequestId: first.id),
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
            TabHeader(
              eyebrow: _team,
              title: t('Queue'),
              // C23: staff report a fire the way residents do.
              trailing: const ReportFireButton(),
            ),
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
          segment(QueueSegment.decide, t('To decide'), SegmentTone.attention),
          const SizedBox(width: 8),
          segment(QueueSegment.active, t('Active'), SegmentTone.live),
          const SizedBox(width: 8),
          segment(QueueSegment.file, t('To file'), SegmentTone.settled),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_feed.loaded) {
      return _feed.error == null
          ? const LoadingView()
          : EmptyState(
              title: t('Queue unavailable'),
              body: _feed.error!,
              action: AppButton.secondary(
                t('Try again'),
                onPressed: _feed.load,
              ),
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

  String _areas(int n) => n == 1 ? t('1 area') : t('{n} areas', {'n': n});

  List<Widget> _decideList() {
    final areas = _feed.toDecide;
    return [
      if (_feed.alarmAsks.isNotEmpty) _alarmAlert(_feed.alarmAsks),
      for (final o in _feed.overlaps.take(1)) _overlapAlert(o),
      if (areas.isEmpty)
        _Empty(
          title: t('Nothing to decide'),
          body: t('A new Area that asks for {_askedWord} lands here first.', {
            '_askedWord': _askedWord,
          }),
        )
      else ...[
        SectionHeader(t('Waiting on you'), meta: _areas(areas.length)),
        for (final (i, a) in areas.indexed)
          _card(
            a,
            action: t('Decide'),
            onTap: () => _decide(a),
            // The newest is the one to look at first.
            emphasis: i == 0 ? AreaEmphasis.attention : AreaEmphasis.normal,
            facts: true,
          ),
      ],
      if (_powers.rejects)
        InlineAlert(
          body: t(
            'Any responding agency can accept. Only a Fire Volunteer or BFP '
            'coordinator can reject.',
          ),
        )
      else
        // 06 · C01P: a PNP Coordinator's queue.
        InlineAlert(
          body: t(
            'These Areas asked for {_askedWord}. Accepting acknowledges them for {_team}. Only a Fire Volunteer or BFP Coordinator can reject.',
            {'_askedWord': _askedWord, '_team': _team},
          ),
        ),
    ];
  }

  /// BFP: the alarm requests waiting on it, newest named, red because a fire
  /// is getting bigger.
  Widget _alarmAlert(List<AlarmRequest> asks) {
    final first = asks.first;
    final asked = first.askedAt;
    final who = [
      first.askedBy,
      ?first.organisation,
      if (asked != null) agoText(asked),
    ].join(' · ');
    return InlineAlert(
      tone: AlertTone.danger,
      title: asks.length == 1
          ? t('{areaName} asks for {alarmWord}', {
              'areaName': first.areaName,
              'alarmWord': alarmWord(first.level),
            })
          : t('{count} alarm requests waiting', {'count': asks.length}),
      body: asks.length == 1
          ? t('{who}. Only BFP sets the alarm level.', {'who': who})
          : t('Newest: {areaName} asks for {alarmWord} · {who}.', {
              'areaName': first.areaName,
              'alarmWord': alarmWord(first.level),
              'who': who,
            }),
      action: asks.length == 1 ? t('Answer') : t('Answer them'),
      onAction: () => _answerAlarm(first),
    );
  }

  Widget _overlapAlert(Map<String, dynamic> o) {
    final a = _designation(o['area_a_designation']);
    final b = _designation(o['area_b_designation']);
    final metres = (o['distance_m'] as num?)?.round();
    return InlineAlert(
      tone: AlertTone.warning,
      title: t('{a} and {b} overlap', {'a': a, 'b': b}),
      body: t('{value}. Merge them into one incident or keep them separate.', {
        'value': metres == null
            ? t('They are close')
            : t('They are {metres} m apart', {'metres': metres}),
      }),
      action: t('Review'),
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
        _Empty(
          title: t('Nothing under way'),
          body: t(
            'An Area you or another agency accepts shows here until the '
            'fire is out.',
          ),
        ),
      if (ground.isNotEmpty) ...[
        SectionHeader(t('On the ground'), meta: _areas(ground.length)),
        for (final a in ground)
          _card(
            a,
            action: t('Open'),
            onTap: () => widget.shell.showLive(a.id),
            emphasis: AreaEmphasis.live,
            note: _groundNote(a),
          ),
      ],
      if (nobody.isNotEmpty) ...[
        SectionHeader(
          t('Accepted, nobody going yet'),
          meta: _areas(nobody.length),
        ),
        for (final a in nobody)
          _card(
            a,
            action: t('Open'),
            onTap: () => _decide(a),
            emphasis: AreaEmphasis.attention,
            note: _acceptedNote(a),
          ),
      ],
      InlineAlert(
        body: t(
          'Only staff see who accepted. The public map shows status, '
          'confidence and report count — never who is responding.',
        ),
      ),
    ];
  }

  String? _acceptedNote(AreaView a) {
    final at = a.at('verified_at');
    final who = andList([for (final g in a.accepted) agencyWord(g)]);
    if (at == null && who.isEmpty) return null;
    return [
      if (at != null) t('Accepted {clockText}', {'clockText': clockText(at)}),
      if (who.isNotEmpty) who,
    ].join(' · ');
  }

  String? _groundNote(AreaView a) {
    final arrived = a.at('arrived_at');
    if (a.status == 'arrived' && arrived != null) {
      final who = andList([for (final g in a.accepted) agencyWord(g)]);
      return t('Arrived {clockText}{value}', {
        'clockText': clockText(arrived),
        'value': who.isEmpty ? '' : ' · $who',
      });
    }
    final going = a.respondingCount;
    final accepted = _acceptedNote(a);
    final units = going == 1
        ? t('1 responding')
        : t('{going} responding', {'going': going});
    return [?accepted, if (going > 0) units].join(' · ');
  }

  List<Widget> _fileList() {
    final owed = _feed.owed;
    return [
      if (owed.isEmpty)
        _Empty(
          title: t('Nothing to file'),
          body: t(
            'When a fire your team went to is out, its report waits here.',
          ),
        )
      else ...[
        SectionHeader(t('Reports to file'), meta: _areas(owed.length)),
        for (final a in owed)
          _card(
            a,
            action: t('File report'),
            onTap: () => _file(a),
            emphasis: _waitingLong(a)
                ? AreaEmphasis.attention
                : AreaEmphasis.normal,
            note: _fileNote(a),
          ),
      ],
      InlineAlert(
        body: t(
          'An Area closes only after its post-incident report is filed. '
          'There is no draft — the form saves once, when it is complete.',
        ),
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
    return t('Fire out {whenText} · {value}', {
      'whenText': whenText(out),
      'value': hours >= 1
          ? t('waiting {hours} h', {'hours': hours})
          : t('ready to file'),
    });
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
                (t('Reports'), '${a.reports}'),
                (t('Confidence'), a.confidence),
                (t('Reported'), reported == null ? '—' : agoText(reported)),
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
  return s.toLowerCase().startsWith('area') ? s : t('Area {s}', {'s': s});
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
