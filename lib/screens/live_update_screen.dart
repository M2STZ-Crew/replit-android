import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../models/resident_status.dart';
import '../models/responder_unit.dart';
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

/// "10 Live tracking" from the REPLIT-OVERHAUL Figma: the resident's own
/// incident, followed live. Polls GET /areas/{id} for the real status and
/// GET /map/evacuation-sites for the nearest safe place.
///
/// Kept from before, below the frame's content, because both work: the way
/// to the nearest shelter, and "add more help" (POST /areas/{id}/
/// request-agencies). Left out on purpose: the frame's "I'm safe — stand
/// down" — no endpoint lets a resident withdraw a report, and a button that
/// looks like it calls off a truck but does not is the worst kind to ship
/// (§2.7.1). Responder ETAs and unit names are staff-only, so the sheet shows
/// the status, the corroboration and what happens next instead.
class LiveUpdateScreen extends StatefulWidget {
  const LiveUpdateScreen({
    super.key,
    required this.areaId,
    required this.lat,
    required this.lng,
    this.alreadySelected = const [],
    this.api,
  });

  final String areaId;

  /// Where the report was sent from.
  final double lat;
  final double lng;

  /// Agencies the citizen already requested when filing the report; these are
  /// hidden from the "add more help" list so they can't be requested twice.
  final List<String> alreadySelected;
  final ApiClient? api;

  @override
  State<LiveUpdateScreen> createState() => _LiveUpdateScreenState();
}

class _LiveUpdateScreenState extends State<LiveUpdateScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  Timer? _poll;
  Map<String, dynamic>? _area;
  bool _loading = true;

  Map<String, dynamic>? _shelter;
  double? _shelterMetres;
  final List<LatLng> _shelters = [];

  late final List<ResponderUnit> _available = kResponderUnits
      .where((u) => !widget.alreadySelected.contains(u.key))
      .toList();
  final Set<String> _extra = {};
  bool _adding = false;

  LatLng get _from => LatLng(widget.lat, widget.lng);

  LatLng? get _centre {
    final lat = (_area?['centroid_lat'] as num?)?.toDouble();
    final lng = (_area?['centroid_lng'] as num?)?.toDouble();
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  String get _status => residentStatus(_area?['status'] as String?);
  int get _reports => (_area?['report_count'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_refreshStatus(), _loadNearestShelter()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshStatus() async {
    try {
      final area = await _api.getArea(widget.areaId);
      if (mounted) setState(() => _area = area);
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
      await _api.requestAreaAgencies(widget.areaId, extras);
      if (!mounted) return;
      setState(() {
        _available.removeWhere((u) => extras.contains(u.key));
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

  static String _next(String status) => switch (status) {
    'pending' =>
      'Barangay 76 has your location and photo. A Fire Volunteer coordinator '
          'confirms it next. Stay somewhere safe — this screen updates as the '
          'incident moves.',
    'verified' =>
      'Confirmed. Responders are being assigned now. Stay somewhere safe and '
          'keep this screen open — it updates as the incident moves.',
    'dispatched' =>
      'A crew has been sent. Stay somewhere safe and keep this screen open — '
          'it updates as the incident moves.',
    'en_route' =>
      'Responders are on their way. Keep the street clear and stay somewhere '
          'safe.',
    'arrived' => 'Responders are on scene. Follow their instructions.',
    'resolved' =>
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
      backgroundColor: AppColors.background,
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
    return FlutterMap(
      options: MapOptions(
        initialCenter: centre ?? _from,
        initialZoom: 15.4,
        backgroundColor: AppColors.background,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        MapTiles.layer(),
        if (centre != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: centre,
                radius: kClusterRadiusMetres,
                useRadiusInMeter: true,
                color: AppColors.live.withValues(alpha: 0.08),
                borderColor: AppColors.live.withValues(alpha: 0.45),
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
                    color: const Color(0xEB131313),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.ok.withValues(alpha: 0.4),
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
                    color: AppColors.forStatus(status),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: const Color(0xE6171717)),
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
                  color: AppColors.accent.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceSolid, width: 3),
                  ),
                ),
              ),
            ),
          ],
        ),
        MapTiles.attribution(),
      ],
    );
  }

  /// "Your report is live" — or, once it is over, what became of it.
  Widget _banner() {
    final status = _status;
    final over = residentOver(status);
    final tone = over ? residentTone(status) : AppColors.live;
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
                      style: AppText.cardTitleSm,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      designation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                over ? residentWord(status).toUpperCase() : 'LIVE',
                style: AppText.tag.copyWith(color: tone),
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
          color: const Color(0xE6171717),
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
                      color: AppColors.label.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Eyebrow('Status', color: AppColors.muted),
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
                      style: AppText.heading2,
                    ),
                    if (reported != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Reported ${_ago(reported)}',
                          style: AppText.caption,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < kResidentRail.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= at
                                ? AppColors.accent
                                : AppColors.lineStrong,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow(
                        'What happens next',
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _next(status),
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _Row(
                  tint: AppColors.ok,
                  icon: Icons.how_to_reg_outlined,
                  title: others == 0
                      ? 'No neighbours have confirmed yet'
                      : '$others ${others == 1 ? 'neighbour' : 'neighbours'} confirmed',
                  line: 'Asked within 300 m of the area',
                ),
                if (_shelter != null) ...[
                  const SizedBox(height: 10),
                  _Row(
                    tint: AppColors.ok,
                    asset: Art.evac,
                    title: (_shelter!['name'] as String?) ?? 'Evacuation site',
                    line: _shelterMetres == null
                        ? 'Nearest open shelter'
                        : 'Nearest open shelter · ${_shelterMetres! < 1000 ? '${_shelterMetres!.round()} m' : '${(_shelterMetres! / 1000).toStringAsFixed(1)} km'}',
                    trailing: 'WAY',
                    onTap: _showMeTheWay,
                  ),
                ],
                if (!residentOver(status) && _available.isNotEmpty)
                  ..._moreHelp(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _moreHelp() {
    return [
      const SizedBox(height: 24),
      const Eyebrow('Need more help?', color: AppColors.accent),
      const SizedBox(height: 8),
      const Text(
        'Add another kind of responder. They are told where it is straight '
        'away — no new photo.',
        style: AppText.bodySm,
      ),
      const SizedBox(height: 12),
      for (final u in _available) ...[
        _AgencyToggle(
          label: u.title,
          glyph: _glyphs[u.key],
          icon: u.icon,
          color: AppColors.forAgency(u.key),
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

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xD1131313),
          Color(0x00131313),
          Color(0x00131313),
          Color(0xE6131313),
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
                Text(title, style: AppText.rowTitleLg),
                const SizedBox(height: 5),
                Text(line, style: AppText.caption),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing!, style: AppText.tag.copyWith(color: AppColors.ok)),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.ok,
            ),
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
        color: on ? color.withValues(alpha: 0.16) : AppColors.glass,
        border: on ? color : AppColors.line,
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
                style: AppText.cardTitleSm.copyWith(
                  color: on ? AppColors.onBackground : AppColors.textSoft,
                ),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? color : AppColors.muted,
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
