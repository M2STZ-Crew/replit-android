import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/live_refresh.dart';
import '../../models/alarm.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/staff_shell.dart';
import '../subadmin/coordinator_nav.dart';
import '../../widgets/loading.dart';
import '../../i18n/i18n.dart';

/// BFP's alarm request queue: Fire Volunteer coordinators (and their
/// responders) ask BFP to raise an Area's alarm; a BFP Coordinator sets the
/// level or declines (PRD v14 §3.4, §4.7: "only authority allowed to execute
/// alarm escalation"). The server checks every answer again.
///
/// Waiting requests come first, the newest on top, each with the Area it is
/// for (where, how far along, at what level now), who asked and for which
/// organisation, and when. Set and Decline are one tap and a confirmation;
/// Open Area goes to the Area itself.
///
/// It listens as well as polls: a request asked, answered or taken back on
/// any phone reaches this screen over the WebSocket (`agency:bfp`) within a
/// second, and the 15 s poll covers a dropped socket. [focusRequestId] (from
/// a tapped push) and [areaId] (from an Area's LIVE screen) put that request,
/// or that Area's, first.
class BfpAlarmRequestsScreen extends StatefulWidget {
  const BfpAlarmRequestsScreen({
    super.key,
    this.api,
    this.focusRequestId,
    this.areaId,
  });

  final ApiClient? api;
  final String? focusRequestId;
  final String? areaId;

  /// How often the queue re-reads when the socket is quiet.
  static const Duration pollEvery = Duration(seconds: 15);

  @override
  State<BfpAlarmRequestsScreen> createState() => _BfpAlarmRequestsScreenState();
}

class _BfpAlarmRequestsScreenState extends State<BfpAlarmRequestsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final LiveRefresh _live = LiveRefresh(
    agencyChannels('bfp'),
    () => _load(silent: true),
  );
  Timer? _poll;

  List<AlarmRequest> _requests = const [];
  bool _loading = true;
  bool _answered = false;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _live.start();
    _poll = Timer.periodic(
      BfpAlarmRequestsScreen.pollEvery,
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_live.dispose());
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final rows = await _api.getAlarmRequests();
      if (!mounted) return;
      setState(() {
        _requests = [
          for (final r in rows.whereType<Map<String, dynamic>>())
            AlarmRequest(r),
        ];
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep the last good list on a failed refresh; say so only when
        // there is nothing to show.
        if (_requests.isEmpty) {
          _error = e is ApiException
              ? e.message
              : t('Could not load the alarm requests. Check your signal.');
        }
        _loading = false;
      });
    }
  }

  List<AlarmRequest> get _waiting =>
      _ordered(_requests.where((r) => r.waiting));
  List<AlarmRequest> get _done => _requests.where((r) => !r.waiting).toList();

  /// The request a push named first, then the Area's from LIVE, then newest.
  List<AlarmRequest> _ordered(Iterable<AlarmRequest> rows) {
    int weight(AlarmRequest r) => r.id == widget.focusRequestId
        ? 0
        : r.areaId == widget.areaId
        ? 1
        : 2;
    final list = rows.toList();
    list.sort((a, b) {
      final w = weight(a).compareTo(weight(b));
      if (w != 0) return w;
      return (b.askedAt ?? DateTime(0)).compareTo(a.askedAt ?? DateTime(0));
    });
    return list;
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ------------------------------------------------------------ actions ---
  Future<void> _set(AlarmRequest r) async {
    final yes = await showFrameSheet<bool>(
      context,
      builder: (context) => SheetFrame(
        children: [
          SheetTitles(
            eyebrow: t('{areaName} · now at {alarmWord}', {
              'areaName': r.areaName,
              'alarmWord': alarmWord(r.areaLevel),
            }),
            title: t('Set {alarmWord}?', {'alarmWord': alarmWord(r.level)}),
            body: t(
              'Every organization on {areaName} sees the new level at once, and {askedBy} is told.',
              {'areaName': r.areaName, 'askedBy': r.askedBy},
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            t('Set {alarmWord}', {'alarmWord': alarmWord(r.level)}),
            run: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _answer(
      r,
      () => _api.executeAlarmRequest(r.id),
      t('{areaName} is now at {alarmWord}.', {
        'areaName': r.areaName,
        'alarmWord': alarmWord(r.level),
      }),
    );
  }

  Future<void> _decline(AlarmRequest r) async {
    final reason = await showFrameSheet<String>(
      context,
      builder: (context) => _DeclineSheet(request: r),
    );
    if (reason == null || !mounted) return;
    await _answer(
      r,
      () =>
          _api.rejectAlarmRequest(r.id, notes: reason.isEmpty ? null : reason),
      t('Declined. {askedBy} is told {areaName} stays as it is.', {
        'askedBy': r.askedBy,
        'areaName': r.areaName,
      }),
    );
  }

  Future<void> _answer(
    AlarmRequest r,
    Future<Object?> Function() call,
    String done,
  ) async {
    setState(() => _busyId = r.id);
    try {
      await call();
      if (mounted) _toast(done);
    } on ApiException catch (e) {
      // Answered on another phone, or the Area moved on: say what the
      // server said, and show the queue as it is now.
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast(t('Could not send that. Check your signal.'));
    } finally {
      if (mounted) setState(() => _busyId = null);
      await _load(silent: true);
    }
  }

  Future<void> _open(AlarmRequest r) async {
    try {
      final incident = await _api.getIncident(r.areaId);
      if (!mounted) return;
      await openCoordinatorIncident(
        context,
        incident: incident,
        me: StaffAccount.current ?? const {},
        api: _api,
      );
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast(t('Could not open the Area. Check your signal.'));
    }
  }

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(
              eyebrow: t('BFP'),
              title: t('Alarm requests'),
              subtitle: t(
                'Fire Volunteer coordinators ask. Only BFP sets the alarm '
                'level.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: CountSegment(
                        count: _waiting.length,
                        label: t('Waiting'),
                        tone: SegmentTone.attention,
                        selected: !_answered,
                        onTap: () => setState(() => _answered = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CountSegment(
                        count: _done.length,
                        label: t('Answered'),
                        tone: SegmentTone.settled,
                        selected: _answered,
                        onTap: () => setState(() => _answered = true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _requests.isEmpty) {
      return const LoadingView();
    }
    if (_error != null) {
      return EmptyState(
        icon: AppIcons.cloudOff,
        title: t('Requests unavailable'),
        body: _error!,
        action: AppButton.secondary(t('Try again'), onPressed: _load),
      );
    }
    final rows = _answered ? _done : _waiting;
    return RefreshIndicator(
      color: context.pal.accent,
      onRefresh: _load,
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
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: EmptyState(
                  icon: AppIcons.notificationsOff,
                  title: _answered
                      ? t('Nothing answered yet')
                      : t('Nothing waiting'),
                  body: _answered
                      ? t(
                          'Requests move here once BFP sets the level or '
                          'declines, or the coordinator takes one back.',
                        )
                      : t(
                          'A request lands here, with the fire alert, when a '
                          'Fire Volunteer coordinator asks BFP to raise an '
                          "Area's alarm.",
                        ),
                ),
              )
            else
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                _RequestCard(
                  key: ValueKey('alarm-request-${r.id}'),
                  request: r,
                  focused: r.id == widget.focusRequestId,
                  busy: _busyId == r.id,
                  onSet: () => _set(r),
                  onDecline: () => _decline(r),
                  onOpen: () => _open(r),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// One request: the level asked for, the Area (where, how far along, its
/// level now), who asked and when, and — while it waits — Set, Decline and
/// Open Area.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.focused,
    required this.busy,
    required this.onSet,
    required this.onDecline,
    required this.onOpen,
  });

  final AlarmRequest request;
  final bool focused;
  final bool busy;
  final VoidCallback onSet;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final r = request;
    final tone = switch (r.status) {
      'approved' => pal.ok,
      'rejected' || 'cancelled' => pal.muted,
      _ => pal.warn,
    };
    final asked = r.askedAt;
    final who = [
      r.askedBy,
      ?r.organisation,
      if (asked != null) agoText(asked),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: focused || r.waiting ? pal.accent : pal.line,
          width: focused ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconPlate(AppIcons.campaign, tint: r.waiting ? pal.live : tone),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alarmWord(r.level),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.rowTitleLg,
                ),
              ),
              const SizedBox(width: 8),
              Tag(alarmRequestWord(r.status), color: tone, dot: r.waiting),
            ],
          ),
          const SizedBox(height: 12),
          // "Area 1.2 · F. Victor Street, Barangay 76": the street once the
          // geocoder answers, the degrees until then.
          AreaPlace(
            area: r.area,
            builder: (context, place) => Text(
              '${r.areaName} · ${placeLine(r.area, place)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.rowTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('{word} · now at {alarmWord}', {
              'word': LifecycleChip.word(r.areaStatus ?? 'reported'),
              'alarmWord': alarmWord(r.areaLevel),
            }),
            style: context.type.detail.copyWith(color: pal.label),
          ),
          const SizedBox(height: 6),
          Text(
            t('Asked by {who}', {'who': who}),
            style: context.type.detail.copyWith(color: pal.label),
          ),
          if (r.justification != null) ...[
            const SizedBox(height: 8),
            Text(
              '“${r.justification}”',
              style: context.type.bodySm.copyWith(color: pal.textSoft),
            ),
          ],
          if (r.waiting) ...[
            if (!r.stillRaises) ...[
              const SizedBox(height: 12),
              InlineAlert(
                tone: AlertTone.warning,
                body: t(
                  '{areaName} is already at {alarmWord}. Setting this would not raise it: decline it instead.',
                  {'areaName': r.areaName, 'alarmWord': alarmWord(r.areaLevel)},
                ),
              ),
            ],
            const SizedBox(height: 14),
            AppButton(
              t('Set {alarmWord}', {'alarmWord': alarmWord(r.level)}),
              run: true,
              busy: busy,
              onPressed: busy || !r.stillRaises ? null : onSet,
            ),
            const SizedBox(height: 10),
            AppButton.secondary(
              t('Decline'),
              onPressed: busy ? null : onDecline,
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              _answer(r),
              style: context.type.bodySm.copyWith(color: pal.textSoft),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextLink(
              t('Open {areaName}', {'areaName': r.areaName}),
              onTap: onOpen,
            ),
          ),
        ],
      ),
    );
  }

  static String _answer(AlarmRequest r) {
    final at = r.answeredAt;
    final when = at == null ? '' : ' · ${clockText(at)}';
    final by = r.answeredBy == null
        ? ''
        : t(' by {answeredBy}', {'answeredBy': r.answeredBy});
    final notes = r.notes == null ? '' : '\n${r.notes}';
    return switch (r.status) {
      'approved' => t('Set{by}{when}.{notes}', {
        'by': by,
        'when': when,
        'notes': notes,
      }),
      'rejected' => t('Declined{by}{when}.{notes}', {
        'by': by,
        'when': when,
        'notes': notes,
      }),
      'cancelled' => t('Taken back{when}.{notes}', {
        'when': when,
        'notes': notes,
      }),
      _ => '',
    };
  }
}

/// Why BFP declines, optional; the coordinator who asked reads it.
class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet({required this.request});

  final AlarmRequest request;

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    // The sheet rides above the keyboard while the reason is typed.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetFrame(
        children: [
          SheetTitles(
            eyebrow: t('{areaName} · {alarmWord} asked', {
              'areaName': r.areaName,
              'alarmWord': alarmWord(r.level),
            }),
            title: t('Decline this request?'),
            body: t(
              '{areaName} stays at {alarmWord}. {askedBy} is told, with your reason.',
              {
                'areaName': r.areaName,
                'alarmWord': alarmWord(r.areaLevel),
                'askedBy': r.askedBy,
              },
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: t('Reason (optional)'),
            builder: (focus) => TextField(
              controller: _reason,
              focusNode: focus,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: context.type.input,
              decoration: InputDecoration(
                hintText: t('Contained at 1st alarm'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppButton.danger(
            t('Decline'),
            onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            t('Keep it waiting'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
