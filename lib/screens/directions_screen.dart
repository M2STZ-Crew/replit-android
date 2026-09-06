import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import '../widgets/design.dart';

const Color _safeGreen = AppColors.ok;
const Color _youBlue = AppColors.info;

/// In-app turn-by-route directions to an evacuation site (Grab/Foodpanda style)
/// — a draggable CARTO map with the route drawn as a polyline, instead of
/// launching an external maps app.
///
/// The route geometry comes from OSRM's public demo server (free, no API key,
/// no billing). If it's unavailable, the screen falls back to a direct line so
/// it still shows the heading + distance.
class DirectionsScreen extends StatefulWidget {
  const DirectionsScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destName,
    this.originLat,
    this.originLng,
  });

  final double destLat;
  final double destLng;
  final String destName;
  final double? originLat;
  final double? originLng;

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  final MapController _map = MapController();
  final Distance _distance = const Distance();

  late final LatLng _dest = LatLng(widget.destLat, widget.destLng);
  LatLng? _origin;
  List<LatLng> _route = [];
  double? _routeMeters;
  bool _loading = true;
  bool _isApprox = false;

  @override
  void initState() {
    super.initState();
    if (widget.originLat != null && widget.originLng != null) {
      _origin = LatLng(widget.originLat!, widget.originLng!);
    }
    _refineLocationThenRoute();
  }

  Future<void> _refineLocationThenRoute() async {
    // Best-effort: use the freshest GPS as the start point.
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition();
          _origin = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // keep the passed origin
    }
    _origin ??= _dest;
    await _loadRoute();
  }

  Future<void> _loadRoute() async {
    final origin = _origin!;
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${_dest.longitude},${_dest.latitude}'
        '?overview=full&geometries=geojson',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final coords = (route['geometry']['coordinates'] as List<dynamic>)
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          if (mounted) {
            setState(() {
              _route = coords;
              _routeMeters = (route['distance'] as num?)?.toDouble();
              _isApprox = false;
              _loading = false;
            });
            _fitRoute();
            return;
          }
        }
      }
      _fallbackStraightLine();
    } catch (_) {
      _fallbackStraightLine();
    }
  }

  void _fallbackStraightLine() {
    if (!mounted) return;
    setState(() {
      _route = [_origin!, _dest];
      _routeMeters = _distance.as(LengthUnit.Meter, _origin!, _dest);
      _isApprox = true;
      _loading = false;
    });
    _fitRoute();
  }

  void _fitRoute() {
    if (_route.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: _route,
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 220),
        ),
      );
    });
  }

  int get _walkMinutes {
    final m = _routeMeters ?? 0;
    return (m / 1.39 / 60).ceil(); // ~5 km/h walking
  }

  String get _distanceLabel {
    final m = _routeMeters ?? 0;
    return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          if (origin != null)
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [origin, _dest],
                  padding: const EdgeInsets.fromLTRB(60, 120, 60, 220),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.m2stz.replit',
                ),
                if (_route.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route,
                        strokeWidth: 5,
                        color: AppColors.accent,
                        borderStrokeWidth: 1,
                        borderColor: Colors.black54,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(point: origin, width: 26, height: 26, child: _youMarker()),
                    Marker(point: _dest, width: 36, height: 36, child: _destMarker()),
                  ],
                ),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [TextSourceAttribution('© OpenStreetMap, © CARTO, OSRM')],
                ),
              ],
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _backButton(),
                  const SizedBox(width: 12),
                  Expanded(child: _titlePill()),
                ],
              ),
            ),
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
          Positioned(left: 16, right: 16, bottom: 16, child: _routeCard()),
        ],
      ),
    );
  }

  Widget _backButton() {
    return const BackWell();
  }

  Widget _titlePill() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.destName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _youMarker() => Container(
        decoration: BoxDecoration(
          color: _youBlue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x803B82F6), blurRadius: 12)],
        ),
      );

  Widget _destMarker() => Container(
        decoration: BoxDecoration(
          color: _safeGreen,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x9922C55E), blurRadius: 12)],
        ),
        child: const Icon(Icons.home_outlined, color: Colors.white, size: 20),
      );

  Widget _routeCard() {
    return Panel(
      padding: const EdgeInsets.all(20),
      color: AppColors.surfaceSolid.withValues(alpha: 0.94),
      border: _safeGreen.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconWell(
                tint: _safeGreen,
                asset: Art.evac,
                size: 40,
                glyph: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Eyebrow('Route to safety', color: _safeGreen),
                    const SizedBox(height: 6),
                    Text(
                      widget.destName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.straighten,
                  _loading ? '—' : _distanceLabel,
                  'distance',
                ),
              ),
              Expanded(
                child: _metric(
                  Icons.directions_walk,
                  _loading ? '—' : '~$_walkMinutes min',
                  'on foot',
                ),
              ),
            ],
          ),
          if (_isApprox && !_loading) ...[
            const SizedBox(height: 14),
            // Said plainly: this is a straight line, not a route. Someone
            // evacuating needs to know the difference.
            Text(
              'Direct line shown — live routing was unavailable. Follow main '
              'roads toward the marker.',
              style: AppText.meta.copyWith(height: 16 / 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accent, size: 19),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.numeral.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Eyebrow(label, color: AppColors.muted),
            ],
          ),
        ),
      ],
    );
  }
}
