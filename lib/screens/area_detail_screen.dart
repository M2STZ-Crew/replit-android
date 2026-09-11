import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../diagnostics/report_timing.dart';
import '../location/sos_location.dart';
import '../models/resident_status.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/map_tiles.dart';
import 'camera_capture_screen.dart';
import 'live_update_screen.dart';

/// Reports join an area only from within this distance of its centre
/// (clustering, Master Context §3.4) — the circle on the map extract.
const double kClusterRadiusMetres = 300;

/// "06 Area detail" from the REPLIT-OVERHAUL Figma: one incident area, what
/// the system believes about it, how far it has got, and — for someone close
/// enough to see it — the way to add their own report.
///
/// Everything comes from GET /areas/{id}. The three confidence bars are the
/// server's own terms (clustering.py): corroboration is reports ÷ 10,
/// spatial agreement is 1 − spread ÷ 300 m, credibility is the reporters'
/// average verification. Two things the frame shows are absent on purpose:
/// the incident kind in the title (an area carries no type, so it is named by
/// its street), and which engine is coming (dispatch detail is staff-only).
class AreaDetailScreen extends StatefulWidget {
  const AreaDetailScreen({
    super.key,
    required this.areaId,
    this.designation,
    this.here,
    this.api,
  });

  final String areaId;

  /// Shown while the area loads.
  final String? designation;

  /// Where the viewer is, when the map already knows.
  final LatLng? here;
  final ApiClient? api;

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  Timer? _poll;

  Map<String, dynamic>? _area;
  String? _error;
  String? _street;
  String? _place;
  bool _geocoded = false;

  /// Whether one of this person's own reports is in the area. Null until
  /// /reports/mine answers.
  bool? _mine;

  @override
  void initState() {
    super.initState();
    _load();
    _checkMine();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final area = await _api.getArea(widget.areaId);
      if (!mounted) return;
      setState(() {
        _area = area;
        _error = null;
      });
      if (!_geocoded) _lookUpPlace();
    } catch (_) {
      if (mounted && _area == null) {
        setState(() => _error = 'Could not load this area. Check your signal.');
      }
    }
  }

  Future<void> _checkMine() async {
    try {
      final mine = await _api.getMyReports();
      final hit = mine.cast<Map<String, dynamic>>().any(
        (r) => r['area_id'] == widget.areaId,
      );
      if (mounted) setState(() => _mine = hit);
    } catch (_) {
      if (mounted) setState(() => _mine = false);
    }
  }

  Future<void> _lookUpPlace() async {
    final c = _centre;
    if (c == null) return;
    _geocoded = true;
    try {
      final marks = await geo.placemarkFromCoordinates(c.latitude, c.longitude);
      if (marks.isEmpty) return;
      final m = marks.first;
      String? clean(String? s) {
        final v = s?.trim() ?? '';
        // Android answers with a Plus Code where it knows no street.
        return v.isEmpty || v.contains('+') ? null : v;
      }

      final street = clean(m.thoroughfare) ?? clean(m.street);
      final place = [
        clean(m.subLocality),
        clean(m.locality),
      ].whereType<String>().join(', ');
      if (mounted) {
        setState(() {
          _street = street;
          _place = place.isEmpty ? null : place;
        });
      }
    } catch (_) {
      // No geocoder or no signal — the area keeps its designation as its name.
    }
  }

  LatLng? get _centre {
    final lat = (_area?['centroid_lat'] as num?)?.toDouble();
    final lng = (_area?['centroid_lng'] as num?)?.toDouble();
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  double? get _metresAway {
    final c = _centre;
    final me = widget.here;
    if (c == null || me == null) return null;
    return const Distance().as(LengthUnit.Meter, me, c);
  }

  String get _status => residentStatus(_area?['status'] as String?);

  bool get _over => residentOver(_status);

  int get _reports => (_area?['report_count'] as num?)?.toInt() ?? 0;

  static String _distance(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  static String _meaning(String status) => switch (status) {
    'pending' => 'Waiting for a Fire Volunteer coordinator to confirm it.',
    'verified' => 'Confirmed. Responders are being assigned.',
    'dispatched' => 'A crew has been sent.',
    'en_route' => 'Responders are on the way.',
    'arrived' => 'Responders are on scene.',
    'resolved' => 'Resolved. Responders have finished here.',
    'rejected' => 'Closed — it could not be confirmed as an incident.',
    'merged' => 'Joined to a neighbouring area.',
    _ => '',
  };

  void _addMyReport() {
    ReportTiming.instance.start('corroborate');
    SosLocation.instance.warmUp();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CameraCaptureScreen()));
  }

  void _followMine() {
    final c = _centre;
    if (c == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveUpdateScreen(
          areaId: widget.areaId,
          lat: c.latitude,
          lng: c.longitude,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    final designation =
        (_area?['designation'] as String?) ?? widget.designation ?? 'Area';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          content: [
            Row(
              children: [
                const BackWell(),
                const SizedBox(width: 16),
                Expanded(child: Eyebrow(designation, color: AppColors.accent)),
              ],
            ),
            const SizedBox(height: 20),
            if (_area == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: _error == null
                    ? const Center(child: CircularProgressIndicator())
                    : Text(_error!, style: AppText.body),
              )
            else
              ..._details(),
          ],
          footer: _footer(),
        ),
      ),
    );
  }

  List<Widget> _details() {
    final away = _metresAway;
    final tone = residentTone(_status);
    return [
      Text((_street ?? 'Incident area').toUpperCase(), style: AppText.heading1),
      const SizedBox(height: 6),
      Text(_place ?? 'Pasay City', style: AppText.body),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Fact(residentWord(_status), tone: tone),
          _Fact('$_reports ${_reports == 1 ? 'report' : 'reports'}'),
          if (away != null) _Fact('${_distance(away)} away'),
        ],
      ),
      const SizedBox(height: 16),
      _mapExtract(),
      const SizedBox(height: 20),
      _confidence(),
      const SizedBox(height: 20),
      _progress(),
    ];
  }

  /// The area's centre and the 300 m it gathers reports from.
  Widget _mapExtract() {
    final c = _centre!;
    return Container(
      height: 140,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.line),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: c,
          // ~5 m a pixel here, so the 300 m circle is ~120 px across.
          initialZoom: 14.9,
          backgroundColor: AppColors.canvas,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          MapTiles.layer(),
          CircleLayer(
            circles: [
              CircleMarker(
                point: c,
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
              Marker(
                point: c,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.live,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceSolid, width: 3),
                  ),
                ),
              ),
            ],
          ),
          MapTiles.attribution(),
        ],
      ),
    );
  }

  Widget _confidence() {
    final band = _area?['confidence_band'] as String?;
    final n = (_area?['n_score'] as num?)?.toDouble() ?? 0;
    final s = (_area?['s_score'] as num?)?.toDouble() ?? 0;
    final v = (_area?['v_score'] as num?)?.toDouble() ?? 0;
    final filled = switch (band) {
      'high' => 3,
      'medium' => 2,
      'low' => 1,
      _ => 0,
    };
    final spread = _reports < 2
        ? 'One report — no spread yet'
        : s <= 0
        ? 'Spread over 300 m'
        : 'Spread ${((1 - s) * kClusterRadiusMetres).round()} m';
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Eyebrow('Confidence', color: AppColors.muted),
              ),
              if (band != null) ...[
                Eyebrow(band, color: AppColors.accent),
                const SizedBox(width: 8),
              ],
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Container(
                  width: 12,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < filled ? AppColors.accent : AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Score(
            'Corroboration',
            _reports >= 10
                ? '$_reports reports — full weight'
                : '$_reports of 10 reports',
            n,
          ),
          const SizedBox(height: 14),
          _Score('Spatial agreement', spread, s),
          const SizedBox(height: 14),
          _Score(
            'Source credibility',
            'Reporters average ${(v * 100).round()}%',
            v,
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    final at = kResidentRail.indexOf(_status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Progress', color: AppColors.muted),
        const SizedBox(height: 12),
        Semantics(
          label: 'Step ${at + 1} of ${kResidentRail.length}',
          excludeSemantics: true,
          child: Row(
            children: [
              for (var i = 0; i < kResidentRail.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= at ? AppColors.accent : AppColors.lineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(residentWord(_status).toUpperCase(), style: AppText.subtitle),
        const SizedBox(height: 5),
        Text(_meaning(_status), style: AppText.detail),
      ],
    );
  }

  /// The one action, and when it is not offered, why not.
  Widget _footer() {
    if (_area == null || _over) return const SizedBox.shrink();
    if (_mine == true) {
      return AppButton.secondary(
        'You reported this — follow it',
        height: 54,
        onPressed: _followMine,
      );
    }
    final away = _metresAway;
    if (away != null && away > kClusterRadiusMetres) {
      // A report joins an area only from within 300 m. From farther off it
      // would open a new incident where the reporter stands — not this one.
      return Text(
        "You're ${_distance(away)} away. A report joins this area only from "
        'within 300 m — if you can see something where you are, use SOS.',
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: AppColors.label),
      );
    }
    return AppButton(
      'I see it too — add my report',
      height: 54,
      onPressed: _addMyReport,
    );
  }
}

/// A 28px fact chip under the title: status (tinted), reports, distance.
class _Fact extends StatelessWidget {
  const _Fact(this.text, {this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t == null ? AppColors.glass : t.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: t == null ? AppColors.line : t.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppText.tag.copyWith(color: t ?? AppColors.textSoft),
      ),
    );
  }
}

/// One confidence component: its name, the plain-language figure, the bar.
class _Score extends StatelessWidget {
  const _Score(this.label, this.value, this.fraction);

  final String label;
  final String value;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.label.copyWith(color: AppColors.textSoft),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppText.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 4,
            backgroundColor: AppColors.lineStrong,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
