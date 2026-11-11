import 'package:flutter/material.dart';

import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import 'area_decision_screen.dart';
import 'coordinator_feed.dart';
import '../../widgets/loading.dart';
import '../../i18n/i18n.dart';

/// The kinds of decision a coordinator makes, as the audit log names them.
enum Decision {
  accepted('Accepted'),
  fireOut('Fire out'),
  rejected('Rejected'),
  merged('Merged'),
  keptSeparate('Kept separate');

  const Decision(this.word);

  final String word;

  static Decision? of(String action) => switch (action) {
    'incident.verify' || 'incident.accept.participate' => accepted,
    'incident.resolve' => fireOut,
    'incident.reject' => rejected,
    'area.merge' => merged,
    'area.keep_separate' => keptSeparate,
    _ => null,
  };
}

/// One decision, read back from the audit log.
class DecisionEntry {
  DecisionEntry(this.kind, this.raw, {this.filed = false});

  final Decision kind;
  final Map<String, dynamic> raw;

  /// For a fire out: this coordinator also filed the report.
  final bool filed;

  String? get areaId => raw['area_id'] as String?;
  DateTime? get at => parseTime(raw['created_at']);

  String get area {
    final d = (raw['area_designation'] as String?) ?? '';
    return d.isEmpty
        ? t('An Area')
        : d.toLowerCase().startsWith('area')
        ? d
        : t('Area {d}', {'d': d});
  }

  Map<String, dynamic> get meta =>
      (raw['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};

  String get title => switch (kind) {
    Decision.fireOut when filed => t('{area} · Fire out, report filed', {
      'area': area,
    }),
    Decision.merged => () {
      final merged = meta['merged_designation'] as String?;
      return merged == null
          ? t('Merged into {area}', {'area': area})
          : t('{_area} · Merged into {area}', {
              '_area': _area(merged),
              'area': area,
            });
    }(),
    _ => '$area · ${t(kind.word)}',
  };

  static String _area(String d) =>
      d.toLowerCase().startsWith('area') ? d : t('Area {d}', {'d': d});
}

/// Every decision this coordinator made (06 · C16), from the audit log the
/// server keeps — so it cannot be edited, here or anywhere.
class MyDecisionsScreen extends StatefulWidget {
  const MyDecisionsScreen({super.key, required this.feed});

  final CoordinatorFeed feed;

  @override
  State<MyDecisionsScreen> createState() => _MyDecisionsScreenState();
}

class _MyDecisionsScreenState extends State<MyDecisionsScreen> {
  List<DecisionEntry>? _entries;
  String? _error;
  Decision? _only;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = (await widget.feed.api.getMyDecisions(
        widget.feed.myId,
      )).cast<Map<String, dynamic>>();
      final filedFor = {
        for (final r in rows)
          if (r['action'] == 'incident.post_incident_report') r['area_id'],
      };
      final entries = [
        for (final r in rows)
          if (Decision.of(r['action'] as String? ?? '') case final kind?)
            DecisionEntry(
              kind,
              r,
              filed:
                  kind == Decision.fireOut && filedFor.contains(r['area_id']),
            ),
      ];
      if (mounted) {
        setState(() {
          _entries = entries;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = t('Could not load your decisions.'));
      }
    }
  }

  void _open(DecisionEntry e) {
    final id = e.areaId;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AreaDecisionScreen(
          areaId: id,
          me: widget.feed.me,
          api: widget.feed.api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(eyebrow: t('Account'), title: t('My decisions')),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final entries = _entries;
    if (entries == null) {
      return _error == null
          ? const LoadingView()
          : EmptyState(
              title: t('Decisions unavailable'),
              body: _error!,
              action: AppButton.secondary(t('Try again'), onPressed: _load),
            );
    }
    int count(Decision d) => entries.where((e) => e.kind == d).length;
    final shown = _only == null
        ? entries
        : entries.where((e) => e.kind == _only).toList();
    Widget segment(Decision d, SegmentTone tone) => Expanded(
      child: CountSegment(
        count: count(d),
        label: t(d.word),
        tone: tone,
        selected: _only == d,
        onTap: () => setState(() => _only = _only == d ? null : d),
      ),
    );
    return ScrollFade(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, kScrollFadeEndPadding),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                segment(Decision.accepted, SegmentTone.attention),
                const SizedBox(width: 8),
                segment(Decision.fireOut, SegmentTone.settled),
                const SizedBox(width: 8),
                segment(Decision.rejected, SegmentTone.live),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            _only == null ? t('Recent') : t(_only!.word),
            meta: t('{count} shown', {'count': shown.length}),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Text(
              t(
                'Nothing here yet. Each accept, reject, merge and fire out you '
                'make is listed as it happens.',
              ),
              style: context.type.bodySm,
            ),
          for (final e in shown) ...[
            ListRow(
              leading: _plate(e.kind),
              title: e.title,
              subtitle: [
                if (e.at != null) whenText(e.at!),
                if (e.raw['actor_agency'] case final String agency)
                  agencyWord(agency),
              ].join(' · '),
              chevron: e.areaId != null,
              onTap: e.areaId == null ? null : () => _open(e),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          InlineAlert(
            body: t(
              'Every decision is kept in the audit log with your role and '
              'agency at the time. It cannot be edited.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _plate(Decision d) {
    final pal = context.pal;
    return switch (d) {
      Decision.accepted => const AgencyPlate(),
      Decision.fireOut => IconPlate(AppIcons.check, tint: pal.ok),
      Decision.rejected => IconPlate(AppIcons.close, tint: pal.live),
      Decision.merged => const IconPlate(AppIcons.joinInner),
      Decision.keptSeparate => const IconPlate(AppIcons.layers),
    };
  }
}
