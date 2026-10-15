import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../api/api_client.dart';
import '../../api/live_refresh.dart';
import '../../location/live_position.dart';
import '../../location/responder_tracker.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/map_marker.dart';
import '../../widgets/map_layers.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/you_are_here.dart';
import '../bfp/bfp_alarm_requests_screen.dart';
import '../responder/responder_status.dart';
import '../subadmin/post_incident_report_screen.dart';
import 'area_decision_screen.dart';
import 'coordinator_feed.dart';

/// A unit within this distance of the Area's centre is on scene.
const double _onSceneMetres = 100;

/// How much of the screen LIVE's sheet covers when it opens.
const double _sheetStart = 0.62;

/// "1st alarm" — the alarm level in the words the BFP uses.
String alarmWord(String? level) => switch (level) {
  'positive_fire_alarm' => 'Positive fire alarm',
  'first_alarm' => '1st alarm',
  'second_alarm' => '2nd alarm',
  'third_alarm' => '3rd alarm',
  'fourth_alarm' => '4th alarm',
  'fifth_alarm' => '5th alarm',
  'general_alarm' => 'General alarm',
  _ => 'None yet',
};

/// The LIVE tab (06 · C11): the incident under way.
///
/// Shows the Area the coordinator opened from the queue, else the one they
/// are going to, else the newest on the ground. With more than one under
/// way, chips over the map switch between them.
class LiveTab extends StatelessWidget {
  const LiveTab({
    super.key,
    required this.feed,
    required this.focus,
    required this.visible,
    required this.onFocus,
  });

  final CoordinatorFeed feed;
  final String? focus;

  /// Polls only while showing.
  final bool visible;
  final ValueChanged<String> onFocus;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        feed,
        ResponderTracker.instance.sharingFor,
      ]),
      builder: (context, _) {
        final live = [
          for (final a in feed.active)
            if (a.live) a,
          for (final a in feed.active)
            if (!a.live) a,
        ];
        final chosen = liveFocus(live, focus);
        if (chosen == null) {
          return SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabHeader(eyebrow: 'Live', title: 'Nothing under way'),
                Expanded(
                  child: feed.loaded
                      ? const EmptyState(
                          icon: AppIcons.localFireDepartment,
                          title: 'No incident is live',
                          body:
                              'An Area shows here once it is accepted, with '
                              'the units on their way and on scene. The queue '
                              'has what is waiting on you.',
                        )
                      : Center(
                          child: CircularProgressIndicator(
                            color: context.pal.accent,
                          ),
                        ),
                ),
              ],
            ),
          );
        }
        return LiveIncidentView(
          key: ValueKey(chosen.id),
          areaId: chosen.id,
          me: feed.me,
          api: feed.api,
          active: visible,
          others: live,
          onSwitch: onFocus,
          onChanged: feed.load,
        );
      },
    );
  }
}

/// Which Area LIVE shows: the one asked for, else the one this phone is
/// sharing its location for, else the first.
AreaView? liveFocus(List<AreaView> live, String? focus) {
  if (live.isEmpty) return null;
  final mine = ResponderTracker.instance.sharingFor.value;
  for (final id in [focus, mine]) {
    for (final a in live) {
      if (a.id == id) return a;
    }
  }
  return live.first;
}

/// One live Area: the map with its units, and the sheet over it — status,
/// how many units are responding, the progress rail, each unit, the alarm
/// level, this coordinator's own response, and Mark fire out.
class LiveIncidentView extends StatefulWidget {
  const LiveIncidentView({
    super.key,
    required this.areaId,
    required this.me,
    required this.api,
    this.active = true,
    this.others = const [],
    this.onSwitch,
    this.onChanged,
  });

  final String areaId;
  final Map<String, dynamic> me;
  final ApiClient api;

  /// Polls only while true.
  final bool active;

  /// Every Area under way, for the switcher.
  final List<AreaView> others;
  final ValueChanged<String>? onSwitch;

  /// Something here changed the Area (responded, fire out).
  final Future<void> Function()? onChanged;

  @override
  State<LiveIncidentView> createState() => _LiveIncidentViewState();
}

class _LiveIncidentViewState extends State<LiveIncidentView> {
  ApiClient get _api => widget.api;
  late final LiveRefresh _live = LiveRefresh([
    incidentChannel(widget.areaId),
  ], _load);
  final MapFollow _follow = MapFollow();
  final ResponderTracker _tracker = ResponderTracker.instance;
  Timer? _poll;

  AreaView? _area;
  List<Map<String, dynamic>> _dispatches = const [];
  List<Map<String, dynamic>> _locations = const [];
  bool _busy = false;

  String get _myId => widget.me['id'] as String? ?? '';
  String? get _agency => widget.me['agency_type'] as String?;

  Map<String, dynamic>? get _mine {
    for (final d in _dispatches) {
      if (d['responder_id'] == _myId && d['status'] == 'active') return d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _live.start();
    _schedule();
  }

  @override
  void didUpdateWidget(LiveIncidentView old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _schedule();
  }

  void _schedule() {
    _poll?.cancel();
    if (!widget.active) return;
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_live.dispose());
    _follow.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getIncident(widget.areaId),
        _api.getDispatches(widget.areaId),
        _api
            .getResponderLocations(widget.areaId)
            .catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _area = AreaView(results[0] as Map<String, dynamic>);
        _dispatches = (results[1] as List).cast<Map<String, dynamic>>();
        _locations = (results[2] as List).cast<Map<String, dynamic>>();
      });
      _syncSharing();
    } catch (_) {
      // Keep the last good picture; the next poll tries again.
    }
  }

  /// Share this phone's location while this coordinator is going, and stop
  /// when their response ends here.
  void _syncSharing() {
    final dispatchId = _mine?['id'] as String?;
    final live = _area?.live ?? false;
    if (dispatchId != null && live) {
      _tracker.start(incidentId: widget.areaId, dispatchId: dispatchId);
    } else if (_tracker.sharingFor.value == widget.areaId) {
      _tracker.stop();
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _act(Future<void> Function() call, String ok) async {
    setState(() => _busy = true);
    try {
      await call();
      if (mounted) _toast(ok);
      await widget.onChanged?.call();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not do that. Check your connection.');
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go() async {
    final area = _area;
    if (area == null) return;
    final choice = await showFrameSheet<GoChoice>(
      context,
      builder: (_) => GoSheet(area: area, api: _api, alreadyAccepted: true),
    );
    if (choice == null || !choice.going || !mounted) return;
    await _act(() async {
      await _api.selfDispatch(widget.areaId, vehicleName: choice.unit);
      if (choice.unit != null) await GoSheet.remember(choice.unit!);
    }, 'You are responding. Your location is shared while you go.');
  }

  void _arrived() =>
      _act(() => _api.markArrived(widget.areaId), 'Marked on scene.');

  Future<void> _route() async {
    final area = _area;
    if (area == null) return;
    await openRouteToArea(
      context,
      area,
      markArrived: _mine != null && area.status == 'en_route'
          ? () => _api.markArrived(widget.areaId)
          : null,
    );
    await _load();
  }

  /// C12 — confirm, then fire out; the report is offered straight after.
  Future<void> _fireOut() async {
    final area = _area;
    if (area == null) return;
    final units = _units().map((u) => u.name).toList();
    final yes = await showFrameSheet<bool>(
      context,
      builder: (context) => SheetFrame(
        children: [
          SheetTitles(
            eyebrow: 'Confirm · can\'t be undone',
            title: 'Mark ${area.name} fire out?',
            body:
                '${units.isEmpty ? 'Everyone responding' : andList(units)} '
                '${units.length == 1 ? 'stands' : 'stand'} down and '
                '${units.length == 1 ? 'stops' : 'stop'} sharing location. '
                'The Area moves to To file until you submit its '
                'post-incident report.',
          ),
          const SizedBox(height: 16),
          AppButton(
            'Yes, mark fire out',
            run: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            'Not yet, keep it live',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.resolveIncident(widget.areaId);
      if (_tracker.sharingFor.value == widget.areaId) await _tracker.stop();
      if (!mounted) return;
      await offerPostIncidentReport(
        context,
        areaId: widget.areaId,
        designation: area.designation,
        api: _api,
      );
      await widget.onChanged?.call();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not mark fire out. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ask BFP to raise the alarm (Fire Volunteer), or open BFP's queue of
  /// those asks (BFP).
  Future<void> _alarm() async {
    if (_agency == 'bfp') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BfpAlarmRequestsScreen()),
      );
      return;
    }
    const levels = [
      'positive_fire_alarm',
      'first_alarm',
      'second_alarm',
      'third_alarm',
      'general_alarm',
    ];
    String? level;
    final picked = await showFrameSheet<String>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => SheetFrame(
          children: [
            const SheetTitles(
              eyebrow: 'Alarm level',
              title: 'Ask BFP to raise it?',
              body:
                  'BFP sets the alarm level. Your request goes to their queue '
                  'with this Area attached.',
            ),
            const SizedBox(height: 16),
            for (final l in levels)
              RadioRow(
                label: alarmWord(l),
                selected: l == level,
                onTap: () => set(() => level = l),
              ),
            const SizedBox(height: 12),
            AppButton(
              'Send request',
              run: true,
              onPressed: level == null
                  ? null
                  : () => Navigator.of(context).pop(level),
            ),
            const SizedBox(height: 10),
            AppButton.secondary(
              'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _act(
      () => _api.createAlarmRequest(areaId: widget.areaId, alarmLevel: picked),
      'Request sent to BFP.',
    );
  }

  /// C06 — straight to the reject sheet: why, then reject. The Area's
  /// details are their own row ([_details]).
  Future<void> _reject() async {
    final area = _area;
    if (area == null) return;
    List<Map<String, dynamic>> reports;
    try {
      reports = (await _api.getIncidentReports(
        widget.areaId,
      )).cast<Map<String, dynamic>>();
    } catch (_) {
      reports = const [];
    }
    if (!mounted) return;
    final reason = await showFrameSheet<String>(
      context,
      builder: (_) => RejectSheet(area: area, reports: reports),
    );
    if (reason == null || !mounted) return;
    await _act(
      () => _api.rejectIncident(widget.areaId, reason),
      '${area.name} rejected. It has left the live feed.',
    );
  }

  /// The Area's details — where it is, how sure, the summary, every report.
  Future<void> _details() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AreaDecisionScreen(areaId: widget.areaId, me: widget.me, api: _api),
      ),
    );
    if (changed == true) await widget.onChanged?.call();
    await _load();
  }

  // -------------------------------------------------------------- units ---
  List<_Unit> _units() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final d in _dispatches) {
      if (d['status'] != 'active') continue;
      final vehicle = (d['vehicle_name'] as String?)?.trim();
      final name = vehicle == null || vehicle.isEmpty
          ? ((d['responder_name'] as String?)?.trim() ?? 'Responder')
          : vehicle;
      groups.putIfAbsent(name, () => []).add(d);
    }
    final byResponder = {
      for (final l in _locations) l['responder_id'] as String?: l,
    };
    return [
      for (final MapEntry(key: name, value: crew) in groups.entries)
        _Unit(
          name: name,
          crew: crew,
          fix: _newestFix([
            for (final d in crew) ?byResponder[d['responder_id']],
          ]),
        ),
    ];
  }

  static Map<String, dynamic>? _newestFix(List<Map<String, dynamic>> fixes) {
    Map<String, dynamic>? best;
    for (final f in fixes) {
      final at = parseTime(f['captured_at']);
      final bestAt = best == null ? null : parseTime(best['captured_at']);
      if (best == null ||
          (at != null && bestAt != null && at.isAfter(bestAt))) {
        best = f;
      }
    }
    return best;
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final area = _area;
    final centre = area?.centre;
    if (area == null || centre == null) {
      return Center(
        child: CircularProgressIndicator(color: context.pal.accent),
      );
    }
    final units = _units();
    return Stack(
      children: [
        Positioned.fill(child: _map(centre, units)),
        // The top veil keeps the status bar and the chips readable.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 180,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.pal.background.withValues(alpha: 0.92),
                    context.pal.background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.others.length > 1)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: FilterChips(
                options: [for (final a in widget.others) a.name],
                selected: area.name,
                onSelect: (name) {
                  for (final a in widget.others) {
                    if (a.name == name) widget.onSwitch?.call(a.id);
                  }
                },
              ),
            ),
          ),
        DraggableScrollableSheet(
          initialChildSize: _sheetStart,
          minChildSize: 0.3,
          maxChildSize: 0.94,
          builder: (context, scroll) => _sheet(area, units, scroll),
        ),
      ],
    );
  }

  Widget _map(LatLng centre, List<_Unit> units) {
    // Framed on the Area's radius in the strip the sheet leaves open, so the
    // fire is in view rather than under the sheet.
    final size = MediaQuery.sizeOf(context);
    const geo = Distance();
    final area = LatLngBounds(
      geo.offset(centre, kAreaRadiusMetres * 3, 315),
      geo.offset(centre, kAreaRadiusMetres * 3, 135),
    );
    return FlutterMap(
      options: MapOptions(
        initialCenter: centre,
        initialZoom: 15.5,
        initialCameraFit: CameraFit.bounds(
          bounds: area,
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.paddingOf(context).top + 24,
            24,
            size.height * _sheetStart + 16,
          ),
        ),
        backgroundColor: context.pal.background,
        interactionOptions: kMapGestures,
        onMapEvent: _follow.onMapEvent,
      ),
      children: [
        MapTiles.layer(light: context.pal.isLight),
        CircleLayer(
          circles: [
            MapAreas.incidentRadius(
              context.pal,
              centre,
              metres: kAreaRadiusMetres,
            ),
          ],
        ),
        MarkerLayer(
          rotate: true,
          markers: [
            for (final u in units)
              if (u.at != null)
                Marker(
                  point: u.at!,
                  width: MapMarker.target,
                  height: MapMarker.target,
                  child: MapMarker(kind: MapMarkerKind.unit, label: u.name),
                ),
            // Last, so a truck parked at the fire never hides it.
            Marker(
              point: centre,
              width: MapMarker.target,
              height: MapMarker.target,
              child: MapMarker(
                kind: MapMarkerKind.incident,
                label: _area!.name,
                selected: true,
                live: true,
              ),
            ),
          ],
        ),
        YouAreHereLayer(follow: _follow),
        MapLocationButtons(
          follow: _follow,
          alignment: Alignment.topRight,
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 64,
            right: 16,
          ),
        ),
        MapTiles.attribution(),
      ],
    );
  }

  Widget _sheet(AreaView area, List<_Unit> units, ScrollController scroll) {
    final pal = context.pal;
    final accepted = area.at('verified_at');
    final mine = _mine;
    final going = units.length;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pal.glassStrong,
            border: Border(top: BorderSide(color: pal.line)),
          ),
          child: ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(
              24,
              14,
              24,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              const Center(child: SheetHandle(margin: EdgeInsets.zero)),
              const SizedBox(height: 12),
              Row(
                children: [
                  LifecycleChip(area.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      [
                        area.name,
                        if (accepted != null) 'accepted ${agoText(accepted)}',
                      ].join(' · '),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption.copyWith(color: pal.label),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  going == 0
                      ? 'NOBODY GOING YET'
                      : going == 1
                      ? '1 UNIT RESPONDING'
                      : '$going UNITS RESPONDING',
                  style: context.type.title,
                ),
              ),
              if (routingLabel(
                    area.raw,
                    agency: _agency,
                    orgId: widget.me['primary_org_id'] as String?,
                  )
                  case final routed?) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tag(routed, color: pal.ok, dot: true),
                ),
              ],
              const SizedBox(height: 12),
              LifecycleRail(status: area.status),
              const SizedBox(height: 12),
              for (final u in units) ...[
                _unitRow(u, area),
                const SizedBox(height: 12),
              ],
              ListRow(
                leading: const IconPlate(AppIcons.warning),
                title: 'Alarm level',
                subtitle: _agency == 'bfp'
                    ? 'Set by BFP · requests wait in your queue'
                    : 'Set by BFP · read-only for Fire Volunteer',
                trailing: RowValue(alarmWord(area.alarmLevel)),
                chevron: true,
                onTap: _busy ? null : _alarm,
              ),
              const SizedBox(height: 12),
              ListRow(
                leading: const IconPlate(AppIcons.description),
                title: 'Area details',
                subtitle: 'Where it is, confidence, summary and reports',
                chevron: true,
                onTap: _details,
              ),
              const SizedBox(height: 12),
              ..._myActions(area, mine),
              AppButton.secondary(
                'Mark fire out',
                busy: _busy,
                onPressed: _busy ? null : _fireOut,
              ),
              if (area.status == 'en_route' || area.status == 'verified')
                Center(
                  child: TextLink(
                    'Reject this Area',
                    color: pal.live,
                    onTap: _reject,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _myActions(AreaView area, Map<String, dynamic>? mine) {
    if (mine == null) {
      return [
        AppButton(
          'I am going',
          run: true,
          busy: _busy,
          onPressed: _busy ? null : _go,
        ),
        const SizedBox(height: 10),
      ];
    }
    return [
      if (area.status != 'arrived') ...[
        AppButton(
          'Mark arrived',
          run: true,
          busy: _busy,
          onPressed: _busy ? null : _arrived,
        ),
        const SizedBox(height: 10),
      ],
      AppButton.secondary(
        'Route to the fire',
        icon: AppIcons.directions,
        onPressed: _route,
      ),
      const SizedBox(height: 10),
    ];
  }

  Widget _unitRow(_Unit u, AreaView area) {
    final pal = context.pal;
    final centre = area.centre!;
    final at = u.at;
    final away = at == null ? null : metresBetween(at, centre);
    final onScene =
        (away != null && away <= _onSceneMetres) ||
        (at == null && area.status == 'arrived');
    final fixAt = parseTime(u.fix?['captured_at']);
    final stale =
        fixAt != null && DateTime.now().difference(fixAt).inSeconds > 30;
    final moving = ((u.fix?['speed_mps'] as num?)?.toDouble() ?? 0) > 1;
    final crew = u.crew.length;
    final String subtitle;
    if (onScene) {
      subtitle = away == null
          ? 'The Area is marked on scene'
          : 'Within ${_onSceneMetres.round()} m of the fire';
    } else if (away == null) {
      subtitle = 'No location yet';
    } else {
      subtitle = [
        '${formatDistance(away)} away',
        if (stale) 'last seen ${agoText(fixAt)}' else if (moving) 'moving',
        if (!stale) 'updates every 5 s',
      ].join(' · ');
    }
    final tone = onScene ? pal.ok : (away == null ? pal.label : pal.info);
    return ListRow(
      leading: IconPlate(
        AppIcons.fireTruck,
        tint: away == null && !onScene ? null : tone,
      ),
      title: crew > 1 ? '${u.name} · $crew crew' : u.name,
      subtitle: subtitle,
      trailing: RowValue(onScene ? 'On scene' : 'En route', color: tone),
    );
  }
}

class _Unit {
  _Unit({required this.name, required this.crew, required this.fix});

  final String name;
  final List<Map<String, dynamic>> crew;

  /// The crew's newest GPS fix, if any.
  final Map<String, dynamic>? fix;

  LatLng? get at {
    final f = fix;
    if (f == null) return null;
    return LatLng((f['lat'] as num).toDouble(), (f['lng'] as num).toDouble());
  }
}

/// LIVE for one Area, opened over everything (from a notification, when the
/// coordinator shell is not showing): the same view, with a Back.
class LiveIncidentScreen extends StatelessWidget {
  const LiveIncidentScreen({
    super.key,
    required this.areaId,
    required this.me,
    this.api,
  });

  final String areaId;
  final Map<String, dynamic> me;
  final ApiClient? api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: Stack(
        children: [
          LiveIncidentView(areaId: areaId, me: me, api: api ?? ApiClient()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BackWell(),
            ),
          ),
        ],
      ),
    );
  }
}
