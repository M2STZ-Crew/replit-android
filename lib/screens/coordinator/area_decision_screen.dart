import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../api/live_refresh.dart';
import '../../location/place_names.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/area_map_preview.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../directions_screen.dart';
import 'report_detail_screen.dart';

/// An Area and the decision on it (06 · C04): where it is, how sure the
/// system is and why, the summary, every report, and the one decision —
/// Accept (C05) or Reject (C06).
///
/// Once someone has accepted it the decision is whether to go: "I am going"
/// opens the same unit picker. Once someone is on the way, the live view
/// takes over ([onLive]). Pops true if anything changed.
class AreaDecisionScreen extends StatefulWidget {
  const AreaDecisionScreen({
    super.key,
    required this.areaId,
    required this.me,
    this.api,
    this.onLive,
  });

  final String areaId;
  final Map<String, dynamic> me;
  final ApiClient? api;

  /// Show the Area in LIVE. Null outside the coordinator shell.
  final void Function(String areaId)? onLive;

  @override
  State<AreaDecisionScreen> createState() => _AreaDecisionScreenState();
}

class _AreaDecisionScreenState extends State<AreaDecisionScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final LiveRefresh _live = LiveRefresh([
    incidentChannel(widget.areaId),
  ], _load);

  AreaView? _area;
  List<Map<String, dynamic>> _reports = const [];
  bool _responding = false;
  String? _summary;
  DateTime? _summaryAt;

  /// The server keeps the summary to the teams that responded.
  bool _summaryNotYours = false;
  String? _error;
  bool _busy = false;
  bool _changed = false;

  String get _myId => widget.me['id'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _live.start();
    // Opening the Area is seeing it: no more reminder pings for it.
    if (widget.me['role'] == 'sub_admin') {
      unawaited(_api.markIncidentSeen(widget.areaId));
    }
  }

  @override
  void dispose() {
    unawaited(_live.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getIncident(widget.areaId),
        _api.getIncidentReports(widget.areaId).catchError((_) => <dynamic>[]),
        _api.getDispatches(widget.areaId).catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      final area = AreaView(results[0] as Map<String, dynamic>);
      final dispatches = (results[2] as List).whereType<Map<String, dynamic>>();
      setState(() {
        _area = area;
        _reports = (results[1] as List).cast<Map<String, dynamic>>();
        _responding = dispatches.any(
          (d) => d['responder_id'] == _myId && d['status'] == 'active',
        );
        _error = null;
      });
      // Summaries are written once the fire is out (v1.12.5).
      if (const {
        'fire_out',
        'post_incident_report',
        'closed',
      }.contains(area.status)) {
        _loadSummary();
      }
    } catch (_) {
      if (mounted && _area == null) {
        setState(() => _error = 'Could not load this Area. Check your signal.');
      }
    }
  }

  Future<void> _loadSummary() async {
    try {
      final rows = await _api.getIncidentSummaries(widget.areaId);
      if (rows.isEmpty || !mounted) return;
      final newest = rows.first as Map<String, dynamic>;
      setState(() {
        _summary = newest['summary_text'] as String?;
        _summaryAt = parseTime(newest['generated_at']);
      });
    } on ApiException catch (e) {
      if (e.statusCode == 403 && mounted) {
        setState(() => _summaryNotYours = true);
      }
    } catch (_) {
      // The card says there is none; the reports are the record.
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ----------------------------------------------------------- actions ---

  /// Accept (C05): verify it, and — "I am going too" — respond on a unit.
  Future<void> _accept({required bool alreadyAccepted}) async {
    final area = _area;
    if (area == null) return;
    final choice = await showFrameSheet<GoChoice>(
      context,
      builder: (_) =>
          GoSheet(area: area, api: _api, alreadyAccepted: alreadyAccepted),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (!alreadyAccepted) {
        await _api.verifyIncident(widget.areaId);
        _changed = true;
      }
      if (choice.going) {
        await _api.selfDispatch(widget.areaId, vehicleName: choice.unit);
        _changed = true;
        if (choice.unit != null) await GoSheet.remember(choice.unit!);
        if (!mounted) return;
        _toast('You are responding. Your location is shared while you go.');
        _goLive();
        return;
      }
      if (mounted) _toast('Accepted. Every agency asked for sees it verified.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not accept. Check your connection.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  /// Reject (C06): confirm, with a reason picked from the list.
  Future<void> _reject() async {
    final area = _area;
    if (area == null) return;
    final reason = await showFrameSheet<String>(
      context,
      builder: (_) => RejectSheet(area: area, reports: _reports),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await _api.rejectIncident(widget.areaId, reason);
      if (!mounted) return;
      _toast('${area.name} rejected. It has left the live feed.');
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.message);
        await _load();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not reject. Check your connection.');
      }
    }
  }

  void _goLive() {
    final onLive = widget.onLive;
    Navigator.of(context).pop(true);
    onLive?.call(widget.areaId);
  }

  void _route() {
    final area = _area;
    if (area == null) return;
    openRouteToArea(
      context,
      area,
      markArrived: _responding && area.status == 'en_route'
          ? () => _api.markArrived(widget.areaId)
          : null,
    );
  }

  void _openReport(Map<String, dynamic> report, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report, number: index + 1),
      ),
    );
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final area = _area;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: context.pal.background,
        bottomNavigationBar: area == null ? null : _actions(area),
        body: SafeArea(
          bottom: false,
          child: area == null
              ? Column(
                  children: [
                    DetailHeader(
                      title: 'Area',
                      onBack: () => Navigator.of(context).pop(_changed),
                    ),
                    Expanded(
                      child: Center(
                        child: _error == null
                            ? CircularProgressIndicator(
                                color: context.pal.accent,
                              )
                            : Text(_error!, style: context.type.body),
                      ),
                    ),
                  ],
                )
              : AreaPlace(
                  area: area,
                  builder: (context, place) => _page(area, place),
                ),
        ),
      ),
    );
  }

  Widget _page(AreaView area, PlaceName place) {
    final c = area.centre;
    final eyebrow = [area.name, ?place.place?.split(',').first].join(' · ');
    final subtitle = [
      ?place.line,
      if (c != null) degrees(c.latitude, c.longitude),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeader(
          eyebrow: eyebrow,
          title: place.street ?? area.name,
          subtitle: subtitle.isEmpty ? null : subtitle,
          onBack: () => Navigator.of(context).pop(_changed),
        ),
        Expanded(
          child: ScrollFade(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                24,
                8,
                24,
                kScrollFadeEndPadding + 8,
              ),
              children: _content(area),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _content(AreaView area) {
    final pal = context.pal;
    final bandTone = switch (area.band) {
      'high' => pal.ok,
      'medium' => pal.warn,
      _ => pal.live,
    };
    final n = _reports.isEmpty ? area.reports : _reports.length;
    final gap = const SizedBox(height: 16);
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          LifecycleChip(area.status),
          Tag(n == 1 ? '1 report' : '$n reports', color: pal.textSoft),
          if (area.band != null)
            Tag('${area.bandWord} confidence', color: bandTone, dot: true),
        ],
      ),
      gap,
      if (area.centre != null) ...[
        AreaMapPreview(centres: [area.centre!], label: area.name),
        gap,
      ],
      ConfidenceMeter(area: area),
      gap,
      SummaryCard(
        text: _summary,
        meta: _summaryAt == null ? null : whenText(_summaryAt!),
        empty: _summaryNotYours
            ? 'The summary and the post-incident reports are for the teams '
                  'that responded.'
            : 'No summary yet. The reports below are the full record.',
      ),
      gap,
      SectionHeader('Reports', meta: '$n · photos are staff-only'),
      const SizedBox(height: 12),
      for (final (i, r) in _reports.indexed) ...[
        _reportRow(r, i),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      if (area.status == 'rejected' || area.status == 'merged')
        InlineAlert(
          tone: AlertTone.danger,
          title: area.status == 'merged'
              ? '${area.name} was merged'
              : '${area.name} was rejected',
          body: area.status == 'merged'
              ? 'Its reports joined a neighbouring Area. It has left the live '
                    'feed.'
              : 'Reason: ${(area.raw['rejection_reason'] as String?) ?? 'none given'}. '
                    'It has left the live feed for everyone.',
        )
      else
        LifecycleRail(status: area.status),
    ];
  }

  Widget _reportRow(Map<String, dynamic> r, int i) {
    final pct = (r['user_verified_percent'] as num?)?.toInt() ?? 0;
    final at = parseTime(r['created_at']);
    final photo = r['photo_url'] is String;
    final asked = askedFor(
      ((r['selected_agencies'] as List?) ?? const []).whereType<String>(),
    );
    return ListRow(
      leading: IconPlate(photo ? AppIcons.photo : AppIcons.person),
      title: 'Resident · $pct% verified',
      subtitle: [
        if (at != null) clockText(at),
        if (photo) 'photo',
        if (asked.isNotEmpty) 'asked $asked',
      ].join(' · '),
      chevron: true,
      onTap: () => _openReport(r, i),
    );
  }

  Widget? _actions(AreaView area) {
    switch (area.status) {
      case 'reported':
        return ActionBar(
          children: [
            AppButton(
              'Accept',
              run: true,
              busy: _busy,
              onPressed: _busy ? null : () => _accept(alreadyAccepted: false),
            ),
            AppButton.secondary(
              'Reject this area',
              onPressed: _busy ? null : _reject,
            ),
          ],
        );
      case 'verified':
        return ActionBar(
          children: [
            if (_responding)
              AppButton(
                'Route to the fire',
                run: true,
                icon: AppIcons.directions,
                onPressed: _route,
              )
            else
              AppButton(
                'I am going',
                run: true,
                busy: _busy,
                onPressed: _busy ? null : () => _accept(alreadyAccepted: true),
              ),
            AppButton.secondary(
              'Reject this area',
              onPressed: _busy ? null : _reject,
            ),
          ],
        );
      case 'en_route' || 'arrived':
        return ActionBar(
          children: [
            AppButton(
              'Open live',
              run: true,
              onPressed: widget.onLive == null ? null : _goLive,
            ),
          ],
        );
      default:
        return null;
    }
  }
}

/// Road directions to an Area (06 · C09), named as the route sheet says it:
/// "Area 1.2, F. Victor Street", or the Area alone when the street is not
/// known.
///
/// [markArrived] is given only to someone responding: it puts Mark arrived
/// on the run panel (C10).
Future<void> openRouteToArea(
  BuildContext context,
  AreaView area, {
  Future<void> Function()? markArrived,
}) async {
  final c = area.centre;
  if (c == null) return;
  final place = await PlaceNames.of(c.latitude, c.longitude);
  if (!context.mounted) return;
  await openRouteToFire(
    context,
    lat: c.latitude,
    lng: c.longitude,
    name: place.street == null ? area.name : '${area.name}, ${place.street}',
    run: FireRun(
      areaId: area.id,
      areaName: area.name,
      place: place.line,
      markArrived: markArrived,
    ),
  );
}

/// What the Accept sheet decided: whether this coordinator is going, and on
/// which unit.
class GoChoice {
  const GoChoice({required this.going, this.unit});

  final bool going;
  final String? unit;
}

/// C05 — Accept Area 1.2? The toggle "I am going too" responds with this
/// Accept, on the unit picked below it; the last unit used comes first.
class GoSheet extends StatefulWidget {
  const GoSheet({
    super.key,
    required this.area,
    required this.api,
    required this.alreadyAccepted,
  });

  final AreaView area;
  final ApiClient api;

  /// Someone has accepted it already: the only question is going.
  final bool alreadyAccepted;

  static const String _lastUnitKey = 'coordinator.last_unit';

  static Future<void> remember(String unit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUnitKey, unit);
    } catch (_) {
      // Only the order of the list is lost.
    }
  }

  @override
  State<GoSheet> createState() => GoSheetState();
}

class GoSheetState extends State<GoSheet> {
  /// Equipment-register categories that are units (as the report uses).
  static const Set<String> _unitCategories = {'fire_truck', 'vehicle', 'truck'};

  late bool _going = widget.alreadyAccepted;
  List<String>? _units;
  String? _last;
  String? _unit;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    String? last;
    try {
      last = (await SharedPreferences.getInstance()).getString(
        GoSheet._lastUnitKey,
      );
    } catch (_) {}
    List<String> units;
    try {
      final rows = (await widget.api.getEquipment())
          .whereType<Map<String, dynamic>>();
      units = [
        for (final e in rows)
          if (_unitCategories.contains(e['category']) &&
              (e['status'] == null || e['status'] == 'available'))
            ((e['name'] as String?) ?? 'Unit').trim(),
      ];
    } catch (_) {
      units = const [];
    }
    if (last != null && units.remove(last)) units.insert(0, last);
    if (!mounted) return;
    setState(() {
      _units = units;
      _last = last;
      _unit = units.isEmpty ? null : units.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final asked = askedFor(area.requested);
    final units = _units;
    return SheetFrame(
      children: [
        SheetTitles(
          eyebrow: '${area.name} — ${LifecycleChip.word(area.status)}',
          title: widget.alreadyAccepted
              ? 'Go to ${area.name}?'
              : 'Accept ${area.name}?',
          body: widget.alreadyAccepted
              ? 'It is verified already. Going puts it on the way for the '
                    'reporter and shares your location until you arrive.'
              : 'Accepting verifies the Area. Every agency the reporter asked '
                    'for${asked.isEmpty ? '' : ' — $asked —'} sees it as '
                    'verified.',
        ),
        const SizedBox(height: 16),
        if (!widget.alreadyAccepted) ...[
          ListRow(
            title: 'I am going too',
            subtitle: 'Dispatch a unit with this Accept',
            trailing: Switch(
              value: _going,
              onChanged: (v) => setState(() => _going = v),
            ),
            onTap: () => setState(() => _going = !_going),
          ),
          const SizedBox(height: 16),
        ],
        if (_going) ...[
          SectionHeader('Unit', meta: _last == null ? null : 'Last used first'),
          const SizedBox(height: 8),
          if (units == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (units.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No unit is available in your team\'s register. You can still '
                'go; the report records the truck afterwards.',
                style: context.type.bodySm,
              ),
            )
          else
            for (final u in units)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RadioRow(
                  label: u == _last ? '$u · last used' : u,
                  selected: u == _unit,
                  onTap: () => setState(() => _unit = u),
                ),
              ),
          const SizedBox(height: 12),
        ],
        AppButton(
          _going
              ? (widget.alreadyAccepted ? 'I am going' : 'Accept and go')
              : 'Accept',
          run: true,
          onPressed: _going && units == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop(GoChoice(going: _going, unit: _going ? _unit : null)),
        ),
        const SizedBox(height: 10),
        AppButton.secondary(
          'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// C06 — Reject Area 2.1? Destructive and final, so it says what the Area
/// is, what rejecting does, and asks why (the server keeps the reason).
class RejectSheet extends StatefulWidget {
  const RejectSheet({super.key, required this.area, required this.reports});

  final AreaView area;
  final List<Map<String, dynamic>> reports;

  @override
  State<RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<RejectSheet> {
  static const _reasons = [
    'False alarm — no fire found',
    'Duplicate of another Area',
    'Not an emergency',
    'Prank or misuse',
  ];

  String? _reason;

  String _describe() {
    final area = widget.area;
    final reported = area.reportedAt;
    final people = widget.reports
        .map((r) => r['reporter_id'] ?? r['id'])
        .toSet()
        .length;
    final who = people <= 1 ? 'by 1 person' : 'by $people people';
    return [
      '${area.name}, reported ${reported == null ? '' : '${agoText(reported)} '}'
          '$who. ${area.bandWord} confidence.',
      'A rejected Area leaves the live feed for everyone and cannot be '
          'reopened or versioned.',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    return SheetFrame(
      children: [
        SheetTitles(
          eyebrow: 'Confirm · can\'t be undone',
          eyebrowColour: context.pal.live,
          title: 'Reject ${area.name}?',
          body: _describe(),
        ),
        const SizedBox(height: 16),
        const InlineAlert(
          body:
              'Only Fire Volunteer and BFP coordinators can reject. Observers '
              'and Admin cannot.',
        ),
        const SizedBox(height: 16),
        const SectionHeader('Why'),
        const SizedBox(height: 8),
        for (final r in _reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RadioRow(
              label: r,
              selected: r == _reason,
              onTap: () => setState(() => _reason = r),
            ),
          ),
        const SizedBox(height: 12),
        AppButton.danger(
          'Reject ${area.name}',
          run: true,
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop(_reason),
        ),
        const SizedBox(height: 10),
        AppButton.secondary(
          'Keep it',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
