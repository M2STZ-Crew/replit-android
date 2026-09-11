import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../diagnostics/report_timing.dart';
import '../location/sos_location.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/map_tiles.dart';
import 'area_detail_screen.dart' show kClusterRadiusMetres;
import 'camera_capture_screen.dart';

/// "11 Corroborate — 300 m" from the REPLIT-OVERHAUL Figma: the 300 m
/// neighbourhood alert, as a screen rather than v2's dialog.
///
/// "Yes" is a real report (v10 §2.2): it opens the same photo step as SOS,
/// with the GPS fix already started when this screen opened. "No, and stop
/// asking" is exactly what POST /notifications/respond `ignore` does — it
/// stops further alerts for this area. The alert the server sends is a fire
/// alert ("Alerto sa Sunog"), so the screen says "a fire".
class NeighbourAlertScreen extends StatefulWidget {
  const NeighbourAlertScreen({super.key, required this.areaId, this.api});

  final String areaId;
  final ApiClient? api;

  @override
  State<NeighbourAlertScreen> createState() => _NeighbourAlertScreenState();
}

class _NeighbourAlertScreenState extends State<NeighbourAlertScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final SosLocation _location = SosLocation.instance;

  Map<String, dynamic>? _area;
  String? _street;

  Position? get _me => _location.position.value;

  @override
  void initState() {
    super.initState();
    _location.position.addListener(_rebuild);
    // Whichever way they answer, knowing where they are helps: the distance
    // below, and a head start on the fix if the answer is "yes".
    _location.warmUp();
    _load();
  }

  @override
  void dispose() {
    _location.position.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final area = await _api.getArea(widget.areaId);
      if (!mounted) return;
      setState(() => _area = area);
      final c = _centre;
      if (c == null) return;
      final marks = await geo.placemarkFromCoordinates(c.latitude, c.longitude);
      for (final m in marks) {
        for (final s in [m.thoroughfare, m.street]) {
          final v = s?.trim() ?? '';
          if (v.isNotEmpty && !v.contains('+')) {
            if (mounted) setState(() => _street = v);
            return;
          }
        }
      }
    } catch (_) {
      // Without the area or a geocoder the screen still asks the question.
    }
  }

  LatLng? get _centre {
    final lat = (_area?['centroid_lat'] as num?)?.toDouble();
    final lng = (_area?['centroid_lng'] as num?)?.toDouble();
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  double? get _metresAway {
    final c = _centre;
    final me = _me;
    if (c == null || me == null) return null;
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(me.latitude, me.longitude),
      c,
    );
  }

  String get _sentence {
    final where = _street == null ? 'near you' : 'on $_street';
    final at = DateTime.tryParse('${_area?['reported_at']}')?.toLocal();
    final when = at == null ? '' : ' ${_ago(at)}';
    return 'Someone within 300 metres reported a fire $where$when.';
  }

  static String _ago(DateTime t) {
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'just now';
    if (m == 1) return 'a minute ago';
    if (m < 60) return '$m minutes ago';
    final h = m ~/ 60;
    return h == 1 ? 'an hour ago' : '$h hours ago';
  }

  void _yes() {
    _api.respondToAlert(widget.areaId, 'report');
    ReportTiming.instance.start('neighbour_alert');
    _location.warmUp();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
  }

  void _no() {
    _api.respondToAlert(widget.areaId, 'ignore');
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text("You won't be asked about this one again.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FootedScroll(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          content: [
            Align(alignment: Alignment.centerLeft, child: _alertChip()),
            const SizedBox(height: 24),
            const Text('DO YOU SEE IT TOO?', style: AppText.display),
            const SizedBox(height: 14),
            Text(_sentence, style: AppText.body),
            const SizedBox(height: 26),
            _proximityMap(),
            const SizedBox(height: 26),
            Panel(
              radius: AppRadius.card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Confirming takes you through the same photo step, so '
                      'your answer becomes a real report — not just a tap.',
                      style: AppText.caption.copyWith(color: AppColors.label),
                    ),
                  ),
                ],
              ),
            ),
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton('Yes, I can see it', height: 54, onPressed: _yes),
              const SizedBox(height: 12),
              AppButton.secondary(
                'No, and stop asking about this',
                height: 48,
                onPressed: _no,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertChip() {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.live.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveDot(size: 7),
          const SizedBox(width: 8),
          Text(
            'BARANGAY 76 ALERT',
            style: AppText.tag.copyWith(color: AppColors.live),
          ),
        ],
      ),
    );
  }

  /// The reported area, its 300 m, and you.
  Widget _proximityMap() {
    final c = _centre;
    final me = _me;
    final away = _metresAway;
    return Container(
      height: 226,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.line),
      ),
      child: c == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: c,
                    // ~3 m a pixel: the 300 m circle is ~190 px across.
                    initialZoom: 15.5,
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
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.live,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surfaceSolid,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        if (me != null)
                          Marker(
                            point: LatLng(me.latitude, me.longitude),
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surfaceSolid,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // The distance chip holds the bottom-left corner.
                    MapTiles.attribution(
                      alignment: AttributionAlignment.bottomRight,
                    ),
                  ],
                ),
                if (away != null)
                  Positioned(
                    left: 15,
                    bottom: 17,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEB131313),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text(
                        '${away < 1000 ? '${away.round()} M' : '${(away / 1000).toStringAsFixed(1)} KM'} FROM YOU',
                        style: AppText.tag.copyWith(
                          color: AppColors.onBackground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
