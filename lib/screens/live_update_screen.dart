import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../api/tracking_socket.dart';
import '../location/live_position.dart';
import '../models/active_report.dart';
import '../models/resident_status.dart';
import '../models/responder_unit.dart';
import '../models/tracking.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/map_tiles.dart';
import 'area_detail_screen.dart' show kClusterRadiusMetres;
import 'directions_screen.dart';

/// White glyph per agency, as on the report screen.
const Map<String, String> _glyphs = {
  'fire_volunteer': Art.agFire,
  'medical': Art.agMedical,
  'police': Art.agPolice,
  'barangay': Art.agBarangay,
};

/// "10 Live tracking" from the REPLIT-OVERHAUL Figma — Track It Live: the
/// resident's own incident, followed live.
///
/// Reported → Verified → On the way → On scene → Fire out, as a labelled rail.
/// Once the incident is on the way, each responding unit is on the map as a
/// moving marker, and in the sheet as "Apollo · On the way · 850 m from the
/// fire". Deliberately no line between truck and fire: the truck's route is
/// its own business, and a drawn road would promise an arrival time nobody
/// computed.
///
/// Where it comes from. The server pushes a fresh snapshot over the socket
/// (`track:<areaId>`, see [TrackingSocket]) after every responder fix and
/// every status change. While the socket is down — no signal, the server
/// waking up — the screen polls GET /areas/{id}/tracking instead, so it never
/// freezes. GET /areas/{id} still supplies what the snapshot does not carry
/// (how many reports, when). The snapshot names units, never people: a
/// truck's name or "Unit 2", and its brigade. Someone who did not report this
/// incident — a neighbour opening it from an alert — is refused the snapshot
/// and sees the status without the trucks.
///
/// A position nobody has updated for a minute is not hidden but greyed and
/// labelled "location lost", and it keeps counting by itself: when a phone
/// goes quiet, no new snapshot arrives to say so.
///
/// Kept from before, below the frame's content, because both work: the way
/// to the nearest shelter, and "add more help" (POST /areas/{id}/
/// request-agencies). Left out on purpose: the frame's "I'm safe — stand
/// down" — no endpoint lets a resident withdraw a report, and a button that
/// looks like it calls off a truck but does not is the worst kind to ship
/// (§2.7.1).
class LiveUpdateScreen extends StatefulWidget {
  const LiveUpdateScreen({
    super.key,
    required this.areaId,
    required this.lat,
    required this.lng,
    this.alreadySelected = const [],
    this.api,
    this.feed,
  });

  final String areaId;

  /// Where the report was sent from.
  final double lat;
  final double lng;

  /// Agencies the citizen already asked for, as far as the caller knows. The
  /// server's record is read too; neither is offered again under "add more
  /// help".
  final List<String> alreadySelected;
  final ApiClient? api;

  /// Where live snapshots come from. The screen opens a [TrackingSocket] when
  /// none is given; tests give their own.
  final TrackingFeed? feed;

  @override
  State<LiveUpdateScreen> createState() => _LiveUpdateScreenState();
}

class _LiveUpdateScreenState extends State<LiveUpdateScreen>
    with WidgetsBindingObserver {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final TrackingFeed _feed =
      widget.feed ?? TrackingSocket(widget.areaId, api: _api);
  StreamSubscription<Map<String, dynamic>>? _feedSub;
  Timer? _poll;
  int _ticks = 0;
  Map<String, dynamic>? _area;
  bool _loading = true;

  /// The status as last heard, from the snapshot or the area read.
  String? _rawStatus;
  TrackingSnapshot? _snap;

  /// The server will not show this account the units (it did not report
  /// this incident). The status still shows.
  bool _trackingDenied = false;

  final MapController _camera = MapController();
  bool _mapReady = false;

  /// Whether the camera has been moved to take in the trucks. Once only: after
  /// that the resident decides where the map looks.
  bool _framed = false;

  Map<String, dynamic>? _shelter;
  double? _shelterMetres;
  final List<LatLng> _shelters = [];

  /// Every agency already asked for on this incident. Null until the
  /// server has said, so "add more help" never flashes up with one that was
  /// added on an earlier visit and then takes it away again.
  Set<String>? _asked;

  List<ResponderUnit> get _available => [
    for (final u in kResponderUnits)
      if (!(_asked ?? const {}).contains(u.key)) u,
  ];
  final Set<String> _extra = {};
  bool _adding = false;

  LatLng get _from => LatLng(widget.lat, widget.lng);

  LatLng? get _centre {
    final snap = _snap;
    if (snap != null) return snap.centre;
    final lat = (_area?['centroid_lat'] as num?)?.toDouble();
    final lng = (_area?['centroid_lng'] as num?)?.toDouble();
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  String get _status => residentStatus(_rawStatus);
  int get _reports => (_area?['report_count'] as num?)?.toInt() ?? 0;

  /// The units to draw. The server sends none outside On the way and On scene.
  List<TrackedUnit> get _units =>
      _trackingDenied ? const [] : (_snap?.units ?? const []);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedSub = _feed.snapshots.listen(_onSnapshot);
    _feed.live.addListener(_rebuild);
    _feed.denied.addListener(_onFeedDenied);
    _feed.start();
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _feed.live.removeListener(_rebuild);
    _feed.denied.removeListener(_onFeedDenied);
    unawaited(_feedSub?.cancel());
    // The screen closes only the socket it opened; a feed handed in belongs
    // to whoever handed it in.
    if (widget.feed == null) unawaited(_feed.dispose());
    _camera.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _tick());
  }

  /// In the background there is nobody to show a truck to: close the socket
  /// and stop polling, and catch up at once on the way back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _feed.pause();
      _poll?.cancel();
      _poll = null;
    } else if (state == AppLifecycleState.resumed && _poll == null) {
      if (!_trackingDenied) _feed.resume();
      _startPolling();
      _tick(catchUp: true);
    }
  }

  /// Every six seconds. With the socket live the snapshots arrive by
  /// themselves, so this only re-reads the area now and then and lets "last
  /// seen" count on. With it down, this is how the screen keeps moving.
  void _tick({bool catchUp = false}) {
    _ticks++;
    final live = _feed.live.value;
    if (!_trackingDenied && (!live || catchUp)) unawaited(_refreshTracking());
    if (_trackingDenied || catchUp || _ticks % (live ? 5 : 2) == 0) {
      unawaited(_refreshStatus());
    } else if (_units.isNotEmpty) {
      _rebuild();
    }
  }

  Future<void> _load() async {
    await Future.wait([
      _refreshStatus(),
      _refreshTracking(),
      _loadNearestShelter(),
      _loadAsked(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshTracking() async {
    if (_trackingDenied) return;
    try {
      _onSnapshot(await _api.getTracking(widget.areaId));
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) _deny();
    } catch (_) {
      // No signal: keep what is on screen; the next tick tries again.
    }
  }

  void _onFeedDenied() {
    if (_feed.denied.value) _deny();
  }

  void _deny() {
    if (_trackingDenied || !mounted) return;
    _feed.pause();
    setState(() => _trackingDenied = true);
  }

  void _onSnapshot(Map<String, dynamic> json) {
    final snap = TrackingSnapshot.tryParse(json);
    if (snap == null || !mounted) return;
    setState(() {
      _snap = snap;
      _adopt(snap.status);
    });
    _frameOnce();
  }

  /// Take a status from either source — but never a step back along the
  /// rail: an area read that set out before the socket's snapshot must not
  /// undo it when it lands.
  void _adopt(String? raw) {
    if (raw == null) return;
    final next = kResidentRail.indexOf(residentStatus(raw));
    final now = kResidentRail.indexOf(residentStatus(_rawStatus));
    if (_rawStatus != null && next >= 0 && now >= 0 && next < now) return;
    _rawStatus = raw;
  }

  /// Bring the trucks into view the first time there are any to see.
  void _frameOnce() {
    final snap = _snap;
    final centre = _centre;
    if (!_mapReady || _framed || !mounted || snap == null || centre == null) {
      return;
    }
    final points = [
      centre,
      for (final u in _units)
        if (!snap.isStale(u)) u.position!,
    ];
    if (points.length < 2) return;
    _framed = true;
    final height = MediaQuery.sizeOf(context).height;
    try {
      _camera.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          // The sheet covers the lower part of the map; frame what is left.
          padding: EdgeInsets.fromLTRB(56, 130, 56, height * 0.56 + 40),
          maxZoom: 16.5,
        ),
      );
    } catch (_) {
      // A screen too small to frame into: the map stays on the fire.
    }
  }

  void _focus(TrackedUnit unit) {
    final at = unit.position;
    if (at == null || !_mapReady) return;
    _camera.move(at, 16.2);
  }

  /// "Hercules Fire Brigade · On the way · 850 m from the fire".
  String _unitLine(TrackedUnit u) {
    final snap = _snap!;
    final org = u.organization?.trim() ?? '';
    final String state;
    final at = u.position;
    if (at == null) {
      state = 'Waiting for its location';
    } else if (snap.isStale(u)) {
      final age = snap.ageOf(u);
      state = age == null
          ? 'Location lost'
          : 'Location lost · last seen ${_since(age)}';
    } else {
      final d = metresBetween(at, snap.centre);
      state = d <= snap.arrivalRadiusMetres
          ? 'On scene'
          : 'On the way · ${formatDistance(d)} from the fire';
    }
    return org.isEmpty ? state : '$org · $state';
  }

  static String _since(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }

  /// What was asked for on this incident: at the SOS, and on any visit here
  /// since — the server appends those to the resident's own report.
  Future<void> _loadAsked() async {
    final asked = {...widget.alreadySelected};
    try {
      for (final raw in await _api.getMyReports()) {
        final r = raw as Map<String, dynamic>;
        if (r['area_id'] != widget.areaId) continue;
        asked.addAll([
          for (final a in (r['selected_agencies'] as List? ?? const [])) '$a',
        ]);
      }
    } catch (_) {
      // What the caller passed is all there is to go on.
    }
    if (mounted) setState(() => _asked = asked);
  }

  Future<void> _refreshStatus() async {
    try {
      final area = await _api.getArea(widget.areaId);
      if (!mounted) return;
      setState(() {
        _area = area;
        _adopt(area['status'] as String?);
      });
    } catch (_) {
      // keep the last known status
    }
  }

  Future<void> _loadNearestShelter() async {
    try {
      final sites = (await _api.getEvacuationSites())
          .cast<Map<String, dynamic>>()
          .where((s) => s['latitude'] != null && s['longitude'] != null)
          .toList();
      Map<String, dynamic>? best;
      double? bestM;
      for (final s in sites) {
        final m = const Distance().as(
          LengthUnit.Meter,
          _from,
          LatLng(
            (s['latitude'] as num).toDouble(),
            (s['longitude'] as num).toDouble(),
          ),
        );
        if (s['is_active'] != false && (bestM == null || m < bestM)) {
          best = s;
          bestM = m;
        }
      }
      if (!mounted) return;
      setState(() {
        _shelter = best;
        _shelterMetres = bestM;
        _shelters
          ..clear()
          ..addAll(
            sites.map(
              (s) => LatLng(
                (s['latitude'] as num).toDouble(),
                (s['longitude'] as num).toDouble(),
              ),
            ),
          );
      });
    } catch (_) {
      // leave the shelter row out
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// In-app directions to the nearest shelter — a map with the route drawn
  /// on it, no external maps app.
  void _showMeTheWay() {
    final s = _shelter;
    if (s == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectionsScreen(
          destLat: (s['latitude'] as num).toDouble(),
          destLng: (s['longitude'] as num).toDouble(),
          destName: (s['name'] as String?) ?? 'Evacuation site',
          originLat: widget.lat,
          originLng: widget.lng,
        ),
      ),
    );
  }

  /// Add more responders to THIS incident — no new photo, no unit picker.
  /// POST /areas/{id}/request-agencies appends the chosen agencies to the
  /// citizen's own report in this area, so dispatch can tell them.
  Future<void> _addMoreHelp() async {
    if (_extra.isEmpty) return;
    final extras = _extra.toList();
    setState(() => _adding = true);
    try {
      final result = await _api.requestAreaAgencies(widget.areaId, extras);
      final now = [
        ...extras,
        for (final a in (result['agencies'] as List? ?? const [])) '$a',
      ];
      // Remembered on the phone too, for the next time this screen opens.
      await ActiveReportStore.addAgencies(widget.areaId, now);
      if (!mounted) return;
      setState(() {
        _asked = {...?_asked, ...now};
        _extra.clear();
      });
      _refreshStatus();
      final names = extras.map(_titleFor).join(', ');
      _toast('Added: $names. Dispatch has been told.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not add responders. Check your connection.');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  String _titleFor(String key) {
    for (final u in kResponderUnits) {
      if (u.key == key) return u.title;
    }
    return key;
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
  }

  String _next(String status) => switch (status) {
    'reported' =>
      'Barangay 76 has your location and photo. A Fire Volunteer coordinator '
          'confirms it next. Stay somewhere safe — this screen updates as the '
          'incident moves.',
    'verified' =>
      'Accepted. A crew is being sent now. Stay somewhere safe and keep this '
          'screen open — it updates as the incident moves.',
    'en_route' =>
      'Responders are on the way. Keep the street clear and stay somewhere '
          'safe.${_units.isEmpty ? '' : ' The map shows where they are.'}',
    'arrived' => 'Responders are at the fire. Follow their instructions.',
    'fire_out' =>
      'Resolved. Thank you for reporting — it is how help found '
          'the place.',
    'rejected' =>
      'Closed — a coordinator could not confirm it. If it is still happening, '
          'report again or call a hotline.',
    'merged' => 'Joined to a neighbouring area — the same responders have it.',
    _ => '',
  };

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final sheetTop = MediaQuery.sizeOf(context).height * 0.44;
    return Scaffold(
      backgroundColor: context.pal.background,
      body: Stack(
        children: [
          Positioned.fill(child: _map()),
          const Positioned.fill(child: IgnorePointer(child: _Vignette())),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    const BackWell(),
                    const SizedBox(width: 12),
                    Expanded(child: _banner()),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: sheetTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: _sheet(),
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _map() {
    final centre = _centre;
    final status = _status;
    final units = _units;
    return FlutterMap(
      mapController: _camera,
      options: MapOptions(
        initialCenter: centre ?? _from,
        initialZoom: 15.4,
        onMapReady: () {
          _mapReady = true;
          _frameOnce();
        },
        backgroundColor: context.pal.background,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        MapTiles.layer(light: context.pal.isLight),
        if (centre != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: centre,
                radius: kClusterRadiusMetres,
                useRadiusInMeter: true,
                color: context.pal.live.withValues(alpha: 0.08),
                borderColor: context.pal.live.withValues(alpha: 0.45),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final s in _shelters)
              Marker(
                point: s,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.pal.background.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.pal.ok.withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(Art.evac, width: 15, height: 15),
                ),
              ),
            if (centre != null)
              Marker(
                point: centre,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.pal.forStatus(status),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color: context.pal.surfaceSolid.withValues(alpha: 0.9),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(Art.incident, width: 17, height: 17),
                ),
              ),
            // Where the report was sent from.
            Marker(
              point: _from,
              width: 34,
              height: 34,
              child: Container(
                decoration: BoxDecoration(
                  color: context.pal.accent.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: context.pal.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.pal.surfaceSolid,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Above the fire and the resident, so a truck is never hidden under
        // them. No polyline: see the class comment.
        if (units.isNotEmpty && _snap != null)
          _UnitsLayer(units: units, snapshot: _snap!),
        MapTiles.attribution(),
      ],
    );
  }

  /// "Your report is live" — or, once it is over, what became of it.
  Widget _banner() {
    final status = _status;
    final over = residentOver(status);
    final tone = over ? residentTone(status, context.pal) : context.pal.live;
    final designation = (_area?['designation'] as String?) ?? 'Your area';
    final shape = BorderRadius.circular(AppRadius.card);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.16),
            borderRadius: shape,
            border: Border.all(color: tone.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              if (over)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const LiveDot(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      over
                          ? 'YOUR REPORT IS ${residentWord(status).toUpperCase()}'
                          : 'YOUR REPORT IS LIVE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.cardTitleSm,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      designation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption.copyWith(
                        color: context.pal.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                over ? residentWord(status).toUpperCase() : 'LIVE',
                style: context.type.tag.copyWith(color: tone),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheet() {
    final status = _status;
    final at = kResidentRail.indexOf(status);
    final reported = DateTime.tryParse('${_area?['reported_at']}')?.toLocal();
    final others = _reports > 0 ? _reports - 1 : 0;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: context.pal.surfaceSolid.withValues(alpha: 0.9),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.pal.label.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Eyebrow('Status', color: context.pal.muted),
                const SizedBox(height: 10),
                // A Wrap, not a Row: at a large font scale the two do not fit
                // side by side, and a Row squeezed the status to a column one
                // letter wide. Here the time drops under it instead.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      residentWord(status).toUpperCase(),
                      style: context.type.heading2,
                    ),
                    if (reported != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Reported ${_ago(reported)}',
                          style: context.type.caption,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _rail(at),
                ..._responders(status),
                const SizedBox(height: 22),
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('What happens next', color: context.pal.muted),
                      const SizedBox(height: 12),
                      Text(
                        _next(status),
                        style: context.type.bodySm.copyWith(
                          color: context.pal.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _Row(
                  tint: context.pal.ok,
                  icon: Icons.how_to_reg_outlined,
                  title: others == 0
                      ? 'No neighbours have confirmed yet'
                      : '$others ${others == 1 ? 'neighbour' : 'neighbours'} confirmed',
                  line: 'Asked within 300 m of the area',
                ),
                if (_shelter != null) ...[
                  const SizedBox(height: 10),
                  _Row(
                    tint: context.pal.ok,
                    asset: Art.evac,
                    title: (_shelter!['name'] as String?) ?? 'Evacuation site',
                    line: _shelterMetres == null
                        ? 'Nearest open shelter'
                        : 'Nearest open shelter · ${_shelterMetres! < 1000 ? '${_shelterMetres!.round()} m' : '${(_shelterMetres! / 1000).toStringAsFixed(1)} km'}',
                    trailing: 'WAY',
                    onTap: _showMeTheWay,
                  ),
                ],
                if (!residentOver(status) &&
                    _asked != null &&
                    _available.isNotEmpty)
                  ..._moreHelp(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The five steps, each named, the current one in full colour.
  Widget _rail(int at) {
    return Semantics(
      label: at < 0
          ? residentWord(_status)
          : 'Step ${at + 1} of ${kResidentRail.length}: '
                '${residentWord(kResidentRail[at])}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < kResidentRail.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= at
                          ? context.pal.accent
                          : context.pal.lineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    residentWord(kResidentRail[i]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.meta.copyWith(
                      color: i == at
                          ? context.pal.onBackground
                          : context.pal.muted,
                      fontWeight: i == at ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Each responding unit, or — on the way but no position yet — a line
  /// saying the crew will appear.
  List<Widget> _responders(String status) {
    final snap = _snap;
    if (_trackingDenied || snap == null) return const [];
    final units = _units;
    if (units.isEmpty) {
      if (status != 'en_route') return const [];
      return [
        const SizedBox(height: 18),
        _Row(
          tint: context.pal.accent,
          icon: Icons.fire_truck,
          title: 'A crew is on the way',
          line: 'You will see the truck here when it shares its location.',
        ),
      ];
    }
    return [
      const SizedBox(height: 22),
      Eyebrow('Responders', color: context.pal.muted),
      const SizedBox(height: 10),
      for (final u in units) ...[
        _Row(
          tint: snap.isStale(u)
              ? context.pal.muted
              : context.pal.forAgency(u.agency),
          icon: Icons.fire_truck,
          title: u.label,
          line: _unitLine(u),
          onTap: u.position == null ? null : () => _focus(u),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _moreHelp() {
    return [
      const SizedBox(height: 24),
      Eyebrow('Need more help?', color: context.pal.accent),
      const SizedBox(height: 8),
      Text(
        'Add another kind of responder. They are told where it is straight '
        'away — no new photo.',
        style: context.type.bodySm,
      ),
      const SizedBox(height: 12),
      for (final u in _available) ...[
        _AgencyToggle(
          label: u.title,
          glyph: _glyphs[u.key],
          icon: u.icon,
          color: context.pal.forAgency(u.key),
          on: _extra.contains(u.key),
          onTap: () => setState(() {
            if (!_extra.remove(u.key)) _extra.add(u.key);
          }),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 6),
      AppButton.secondary(
        _extra.isEmpty ? 'Choose who to add' : 'Add more help',
        height: 48,
        busy: _adding,
        onPressed: _adding || _extra.isEmpty ? null : _addMoreHelp,
      ),
    ];
  }
}

/// The responding units on the map, gliding from one fix to the next rather
/// than jumping five seconds at a time.
class _UnitsLayer extends StatefulWidget {
  const _UnitsLayer({required this.units, required this.snapshot});

  final List<TrackedUnit> units;
  final TrackingSnapshot snapshot;

  @override
  State<_UnitsLayer> createState() => _UnitsLayerState();
}

class _UnitsLayerState extends State<_UnitsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  final Map<String, LatLng> _from = {};
  final Map<String, LatLng> _to = {};

  @override
  void initState() {
    super.initState();
    _retarget();
  }

  @override
  void didUpdateWidget(_UnitsLayer old) {
    super.didUpdateWidget(old);
    _retarget();
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  /// Start each marker from wherever it is drawn now, so a fix that lands
  /// mid-glide bends the path instead of snapping back.
  void _retarget() {
    final t = Curves.easeInOut.transform(_glide.value);
    final drawn = {for (final k in _to.keys) k: _at(k, t)};
    _from.clear();
    _to.clear();
    var moved = false;
    for (final u in widget.units) {
      final p = u.position;
      if (p == null) continue;
      final start = drawn[u.key] ?? p;
      _from[u.key] = start;
      _to[u.key] = p;
      moved = moved || start != p;
    }
    if (moved) {
      _glide.forward(from: 0);
    } else {
      _glide.value = 1;
    }
  }

  LatLng _at(String key, double t) {
    final a = _from[key]!;
    final b = _to[key]!;
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glide,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_glide.value);
        return MarkerLayer(
          markers: [
            for (final u in widget.units)
              if (_to.containsKey(u.key))
                Marker(
                  point: _at(u.key, t),
                  width: 38,
                  height: 38,
                  child: _UnitMarker(
                    label: u.label,
                    colour: widget.snapshot.isStale(u)
                        ? context.pal.muted
                        : context.pal.forAgency(u.agency),
                    stale: widget.snapshot.isStale(u),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _UnitMarker extends StatelessWidget {
  const _UnitMarker({
    required this.label,
    required this.colour,
    required this.stale,
  });

  final String label;
  final Color colour;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: stale ? '$label, location lost' : label,
      child: Opacity(
        opacity: stale ? 0.6 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(color: context.pal.surfaceSolid, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.fire_truck, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          context.pal.background.withValues(alpha: 0.82),
          context.pal.background.withValues(alpha: 0),
          context.pal.background.withValues(alpha: 0),
          context.pal.background.withValues(alpha: 0.9),
        ],
        stops: [0, 0.24, 0.52, 1],
      ),
    ),
  );
}

/// A 64px row in the sheet: tinted well, two lines, an optional action word.
class _Row extends StatelessWidget {
  const _Row({
    required this.tint,
    required this.title,
    required this.line,
    this.icon,
    this.asset,
    this.trailing,
    this.onTap,
  });

  final Color tint;
  final String title;
  final String line;
  final IconData? icon;
  final String? asset;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppRadius.card,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          IconWell(tint: tint, icon: icon, asset: asset, size: 36, glyph: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.type.rowTitleLg),
                const SizedBox(height: 5),
                Text(line, style: context.type.caption),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(
              trailing!,
              style: context.type.tag.copyWith(color: context.pal.ok),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.pal.ok),
          ],
        ],
      ),
    );
  }
}

/// One agency that can still be added, as a toggle.
class _AgencyToggle extends StatelessWidget {
  const _AgencyToggle({
    required this.label,
    required this.color,
    required this.on,
    required this.onTap,
    this.glyph,
    this.icon,
  });

  final String label;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  final String? glyph;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: on,
      label: label,
      excludeSemantics: true,
      child: Panel(
        radius: AppRadius.card,
        onTap: onTap,
        color: on ? color.withValues(alpha: 0.16) : context.pal.glass,
        border: on ? color : context.pal.line,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              alignment: Alignment.center,
              child: glyph != null
                  ? Image.asset(glyph!, width: 19, height: 19)
                  : Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.cardTitleSm.copyWith(
                  color: on ? context.pal.onBackground : context.pal.textSoft,
                ),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? color : context.pal.muted,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: on
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
