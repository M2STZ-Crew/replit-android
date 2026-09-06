import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../models/responder_unit.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/incident_map.dart';
import 'directions_screen.dart';

const Color _safeGreen = AppColors.ok;

/// Live tracking of the citizen's active incident. Polls GET /areas/{id} for the
/// real status, and GET /map/evacuation-sites for the nearest safe area.
///
/// Note: responder ETA / distance / count are staff-only on the backend (no
/// citizen access, no routing engine), so the two stat cards show real
/// citizen-accessible data (live STATUS + report CORROBORATION) instead, and the
/// "ADD MORE HELP" action is a placeholder (no citizen add-responders endpoint).
class LiveUpdateScreen extends StatefulWidget {
  const LiveUpdateScreen({
    super.key,
    required this.areaId,
    required this.lat,
    required this.lng,
    this.alreadySelected = const [],
  });

  final String areaId;
  final double lat;
  final double lng;

  /// Agencies the citizen already requested when filing the report; these are
  /// hidden from the "add more help" list so they can't be requested twice.
  final List<String> alreadySelected;

  @override
  State<LiveUpdateScreen> createState() => _LiveUpdateScreenState();
}

class _LiveUpdateScreenState extends State<LiveUpdateScreen> {
  final ApiClient _api = ApiClient();
  Timer? _poll;
  Map<String, dynamic>? _area;
  String? _evacName;
  double? _evacKm;
  double? _evacLat;
  double? _evacLng;
  final List<LatLng> _evacSites = [];
  bool _loading = true;
  bool _adding = false;

  late final List<ResponderUnit> _available;
  final Map<String, bool> _extra = {};

  @override
  void initState() {
    super.initState();
    _available = kResponderUnits
        .where((u) => !widget.alreadySelected.contains(u.key))
        .toList();
    for (final u in _available) {
      _extra[u.key] = false;
    }
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_refreshStatus(), _loadNearestEvac()]);
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

  Future<void> _loadNearestEvac() async {
    try {
      final sites = await _api.getEvacuationSites();
      double? best;
      String? bestName;
      double? bestLat;
      double? bestLng;
      final points = <LatLng>[];
      for (final s in sites) {
        final m = s as Map<String, dynamic>;
        final slat = (m['latitude'] as num).toDouble();
        final slng = (m['longitude'] as num).toDouble();
        points.add(LatLng(slat, slng));
        final d = _km(widget.lat, widget.lng, slat, slng);
        if (best == null || d < best) {
          best = d;
          bestName = m['name'] as String?;
          bestLat = slat;
          bestLng = slng;
        }
      }
      if (mounted) {
        setState(() {
          _evacKm = best;
          _evacName = bestName;
          _evacLat = bestLat;
          _evacLng = bestLng;
          _evacSites
            ..clear()
            ..addAll(points);
        });
      }
    } catch (_) {
      // leave evac empty
    }
  }

  double _km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  String get _status => (_area?['status'] as String?) ?? 'pending';
  int get _reportCount => (_area?['report_count'] as num?)?.toInt() ?? 0;

  String get _headline {
    switch (_status) {
      case 'verified':
        return 'Verified. Assigning responders.';
      case 'dispatched':
        return 'A responder is on the way to your location now.';
      case 'en_route':
        return 'Responders are en route to your location.';
      case 'arrived':
        return 'Responders have arrived on scene.';
      case 'resolved':
        return 'Incident resolved. Stay safe.';
      case 'rejected':
        return 'This report has been closed.';
      default:
        return 'Your report is being verified.';
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Open in-app directions to the nearest evacuation site — a draggable map
  /// with the route drawn on it (no external maps app).
  void _showMeTheWay() {
    if (_evacLat == null || _evacLng == null) {
      _toast('No evacuation site location is available yet.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectionsScreen(
          destLat: _evacLat!,
          destLng: _evacLng!,
          destName: _evacName ?? 'Evacuation site',
          originLat: widget.lat,
          originLng: widget.lng,
        ),
      ),
    );
  }

  /// Add more responders to THIS incident — no new photo, no unit picker. Calls
  /// POST /areas/{id}/request-agencies, which appends the chosen agencies to the
  /// citizen's existing report for this area (keeping the ones already
  /// requested) so dispatch can notify the added departments.
  Future<void> _addMoreHelp() async {
    final extras = _extra.entries.where((e) => e.value).map((e) => e.key).toList();
    if (extras.isEmpty) {
      _toast('Select a unit to add first.');
      return;
    }
    setState(() => _adding = true);
    try {
      await _api.requestAreaAgencies(widget.areaId, extras);
      if (!mounted) return;
      setState(() {
        _available.removeWhere((u) => extras.contains(u.key));
        for (final k in extras) {
          _extra.remove(k);
        }
      });
      _refreshStatus();
      final names = extras.map(_titleFor).join(', ');
      _toast('Added: $names. Dispatch has been notified.');
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

  Widget _legend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(AppColors.accent, true, 'Incident'),
          const SizedBox(height: 8),
          _legendRow(_safeGreen, false, 'Evacuation'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, bool circle, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(3),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.of(context).size.height * 0.42;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SizedBox(
            height: mapHeight,
            width: double.infinity,
            child: IncidentMap(
              lat: widget.lat,
              lng: widget.lng,
              interactive: true,
              evacSites: _evacSites,
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: _legend(),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: mapHeight - 28),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  children: [
                    const Center(child: SheetHandle()),
                    Row(
                      children: [
                        const LiveDot(),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Eyebrow('Live', color: AppColors.live),
                              SizedBox(height: 6),
                              Text('HELP IS MOVING', style: AppText.title),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(_headline, style: AppText.body),
                    const SizedBox(height: 22),
                    _statCard(
                      'Status',
                      _status.replaceAll('_', ' ').toUpperCase(),
                      'Updates on its own',
                      highlight: true,
                    ),
                    const SizedBox(height: 10),
                    _statCard(
                      'Corroboration',
                      '$_reportCount ${_reportCount == 1 ? 'REPORT' : 'REPORTS'}',
                      'Neighbours who confirmed it',
                    ),
                    const SizedBox(height: 10),
                    _evacCard(),
                    ..._needMoreHelp(),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: const BackWell(),
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
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    String sub, {
    bool highlight = false,
  }) {
    final tint = highlight
        ? AppColors.forStatus(_status)
        : AppColors.textSoft;
    return Panel(
      padding: const EdgeInsets.all(18),
      color: highlight ? tint.withValues(alpha: 0.08) : AppColors.glassDim,
      border: highlight ? tint.withValues(alpha: 0.4) : AppColors.line,
      child: Row(
        children: [
          IconWell(
            tint: tint,
            asset: highlight ? Art.truck : Art.incident,
            size: 40,
            glyph: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow(label, color: AppColors.muted),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(
                    fontSize: 17,
                    color: highlight ? tint : AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _evacCard() {
    final name = _evacName ?? 'No evacuation site data';
    final dist = _evacKm == null ? '' : '${_evacKm!.toStringAsFixed(1)} km away';
    return Panel(
      padding: const EdgeInsets.all(18),
      color: _safeGreen.withValues(alpha: 0.08),
      border: _safeGreen.withValues(alpha: 0.4),
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
                    const Eyebrow('Where to go', color: _safeGreen),
                    const SizedBox(height: 6),
                    Text(
                      name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dist.isEmpty
                ? 'Head to the nearest safe area.'
                : 'The nearest safe area is $dist.',
            style: AppText.meta.copyWith(height: 16 / 11),
          ),
          const SizedBox(height: 14),
          AppButton(
            'Show me the way',
            height: 46,
            icon: Icons.directions_rounded,
            onPressed: _showMeTheWay,
          ),
        ],
      ),
    );
  }

  /// The "need more help" section — only the units not already requested.
  List<Widget> _needMoreHelp() {
    if (_available.isEmpty) {
      return [
        const SizedBox(height: 24),
        Panel(
          padding: const EdgeInsets.all(18),
          color: AppColors.glassDim,
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, size: 20, color: _safeGreen),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'You have already asked for every unit available on this '
                  'incident.',
                  style: AppText.meta.copyWith(height: 16 / 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton.secondary('Close', onPressed: () => Navigator.of(context).pop()),
      ];
    }
    return [
      const SizedBox(height: 28),
      const Text('NEED MORE HELP?', style: AppText.title),
      const SizedBox(height: 8),
      const Text(
        'Add another kind of responder to this incident. They are told where '
        'it is straight away.',
        style: AppText.body,
      ),
      const SizedBox(height: 18),
      const Eyebrow('Not yet requested', color: AppColors.accent),
      const SizedBox(height: 12),
      ..._available.map(_unitTile),
      const SizedBox(height: 8),
      Row(
        children: [
          SizedBox(
            width: 110,
            child: AppButton.secondary(
              'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              'Add more help',
              busy: _adding,
              onPressed: _adding ? null : _addMoreHelp,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _unitTile(ResponderUnit u) {
    final selected = _extra[u.key] ?? false;
    final tint = AppColors.forAgency(u.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: () => setState(() => _extra[u.key] = !selected),
        color: selected ? tint.withValues(alpha: 0.1) : AppColors.glassDim,
        border: selected ? tint : AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            IconWell(tint: tint, icon: u.icon, size: 44, glyph: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    u.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    u.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? tint : Colors.transparent,
                border: Border.all(
                  color: selected ? tint : AppColors.lineStrong,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppColors.background,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

}
