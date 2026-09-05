import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../domain/entities/map_entities.dart';
import '../providers/map_provider.dart';

/// The home screen from the hand-off: real Pasay City streets, three layers,
/// a translucent sheet of what is nearby, and the SOS button floating over it.
///
/// Two things the design shows are not drawn, because nothing produces them:
/// which units are on scene (dispatch detail is staff-only, and rightly so),
/// and the street name for an incident (there is no geocoder in the system, so
/// a cluster is identified by its designation, not an address).
class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key, required this.onSos, this.onProfile});

  final VoidCallback onSos;
  final VoidCallback? onProfile;

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  final _map = MapController();
  bool _centredOnce = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(mapSnapshotProvider);
    final position = ref.watch(devicePositionProvider).valueOrNull;
    final layers = ref.watch(activeLayersProvider);
    final online = ref.watch(connectivityStreamProvider).valueOrNull ?? true;
    final top = MediaQuery.paddingOf(context).top;

    final me = position == null
        ? null
        : LatLng(position.latitude, position.longitude);

    // Recentre once, the first time a fix arrives. Doing it on every rebuild
    // would fight the user every time they panned.
    if (me != null && !_centredOnce) {
      _centredOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(me, 15.2);
      });
    }

    final snap = snapshot.valueOrNull ?? const MapSnapshot();
    final nearby = buildNearby(snap, position);

    return Stack(
      children: [
        Positioned.fill(child: _buildMap(snap, layers, me, online)),

        // ── header ────────────────────────────────────────────────────────
        Positioned(
          left: 24,
          right: 24,
          top: top + 8,
          child: Row(
            children: [
              Expanded(
                child: online
                    ? _LocationCard(position: position)
                    : const _OfflineCard(),
              ),
              const SizedBox(width: 12),
              AvatarWell(onTap: widget.onProfile),
            ],
          ),
        ),

        // ── layer toggles ─────────────────────────────────────────────────
        Positioned(
          left: 24,
          right: 24,
          top: top + 72,
          child: SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final layer in MapLayer.values) ...[
                  _LayerChip(
                    layer: layer,
                    on: layers.contains(layer),
                    count: layer == MapLayer.incidents
                        ? snap.incidents.length
                        : snap.placesFor(layer).length,
                    onTap: () {
                      final next = {...layers};
                      if (!next.remove(layer)) next.add(layer);
                      ref.read(activeLayersProvider.notifier).state = next;
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),

        // ── SOS ───────────────────────────────────────────────────────────
        Positioned(
          right: 24,
          bottom: _sheetHeight(nearby) + 24,
          child: _SosButton(onTap: widget.onSos),
        ),

        // ── nearby sheet ──────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _NearbySheet(
            items: nearby,
            loading: snapshot.isLoading,
            failed: snap.failed,
            hasFix: position != null,
            height: _sheetHeight(nearby),
            onRefresh: () => ref.invalidate(mapSnapshotProvider),
          ),
        ),
      ],
    );
  }

  double _sheetHeight(List<NearbyItem> items) {
    final rows = items.isEmpty ? 1 : items.length.clamp(1, 3);
    return 78 + rows * 64;
  }

  Widget _buildMap(
    MapSnapshot snap,
    Set<MapLayer> layers,
    LatLng? me,
    bool online,
  ) {
    final markers = <Marker>[
      if (layers.contains(MapLayer.shelters))
        for (final p in snap.shelters) _placeMarker(p, AppColors.ok, Art.evac),
      if (layers.contains(MapLayer.hydrants))
        for (final p in snap.hydrants)
          _placeMarker(
            p,
            p.ok ? AppColors.textSoft : AppColors.live,
            Art.hydrant,
          ),
      if (layers.contains(MapLayer.risks))
        for (final p in snap.risks)
          _placeMarker(p, AppColors.statusPending, Art.incident),
      if (layers.contains(MapLayer.incidents))
        for (final i in snap.incidents) _incidentMarker(i),
      if (me != null)
        Marker(
          point: me,
          width: 26,
          height: 26,
          child: const _MeDot(),
        ),
    ];

    return ColorFiltered(
      // The design's map is the real street layer pulled toward the theme:
      // desaturated and darkened so coral markers carry all the colour. When
      // offline it desaturates completely — that is the status message.
      colorFilter: ColorFilter.matrix(
        online ? _kNightMatrix : _kGreyMatrix,
      ),
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: me ??
              const LatLng(
                AppConstants.defaultMapLat,
                AppConstants.defaultMapLng,
              ),
          initialZoom: 15.2,
          minZoom: 11,
          maxZoom: 18,
          backgroundColor: AppColors.bg,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            // OpenStreetMap's tile policy requires a real identifying agent.
            userAgentPackageName: 'ph.pasay.replit',
            maxNativeZoom: 19,
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  Marker _placeMarker(MapPlace place, Color tint, String art) => Marker(
    point: LatLng(place.lat, place.lng),
    width: 30,
    height: 30,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        shape: BoxShape.circle,
        border: Border.all(color: tint, width: 1.5),
      ),
      padding: const EdgeInsets.all(5),
      child: Image.asset(art, fit: BoxFit.contain),
    ),
  );

  Marker _incidentMarker(MapIncident incident) {
    final color = AppColors.forStatus(incident.status);
    return Marker(
      point: LatLng(incident.lat, incident.lng),
      width: 36,
      height: 36,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '${incident.reportCount}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// Desaturate to ~35% and pull the whole image down — OSM's daylight tiles are
/// far too bright to sit under a #131313 UI.
const List<double> _kNightMatrix = <double>[
  0.42, 0.28, 0.10, 0, -14,
  0.36, 0.34, 0.10, 0, -14,
  0.33, 0.28, 0.19, 0, -12,
  0, 0, 0, 1, 0,
];

/// Fully grey — the offline state.
const List<double> _kGreyMatrix = <double>[
  0.26, 0.26, 0.15, 0, -22,
  0.26, 0.26, 0.15, 0, -22,
  0.26, 0.26, 0.15, 0, -22,
  0, 0, 0, 1, 0,
];

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.accent,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.bg, width: 3),
      boxShadow: [
        BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 16),
      ],
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({this.position});

  final dynamic position;

  @override
  Widget build(BuildContext context) {
    final accuracy = position?.accuracy as double?;
    return Panel(
      radius: AppRadius.card,
      color: AppColors.surfaceSolid.withValues(alpha: 0.86),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const LiveDot(color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  position == null ? 'LOCATING YOU' : "YOU'RE HERE",
                  style: AppText.cardTitle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  position == null
                      ? 'Showing Pasay City until a fix arrives'
                      : accuracy == null
                          ? 'Location on'
                          : 'Accurate to ${accuracy.round()} m',
                  style: AppText.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) => Panel(
    radius: AppRadius.card,
    color: AppColors.accent.withValues(alpha: 0.12),
    border: AppColors.accent.withValues(alpha: 0.45),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_rounded, size: 17, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NO SIGNAL', style: AppText.cardTitle.copyWith(fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                'Map is showing tiles already on this phone',
                style: AppText.meta.copyWith(color: AppColors.textSoft),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LayerChip extends StatelessWidget {
  const _LayerChip({
    required this.layer,
    required this.on,
    required this.count,
    required this.onTap,
  });

  final MapLayer layer;
  final bool on;
  final int count;
  final VoidCallback onTap;

  static const _tints = {
    MapLayer.incidents: AppColors.accent,
    MapLayer.shelters: AppColors.ok,
    MapLayer.hydrants: AppColors.textSoft,
    MapLayer.risks: AppColors.statusPending,
  };

  @override
  Widget build(BuildContext context) {
    final tint = _tints[layer]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on
              ? tint.withValues(alpha: 0.14)
              : AppColors.surfaceSolid.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: on ? tint.withValues(alpha: 0.55) : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              '${layer.label.toUpperCase()}${count > 0 ? '  $count' : ''}',
              style: AppText.tag.copyWith(
                letterSpacing: 1,
                color: on ? tint : AppColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send an SOS',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.sosGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 32,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'SOS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppColors.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbySheet extends StatelessWidget {
  const _NearbySheet({
    required this.items,
    required this.loading,
    required this.failed,
    required this.hasFix,
    required this.height,
    required this.onRefresh,
  });

  final List<NearbyItem> items;
  final bool loading;
  final List<String> failed;
  final bool hasFix;
  final double height;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Column(
        children: [
          const SheetHandle(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Eyebrow('Nearby right now', color: AppColors.accent),
              const Spacer(),
              GestureDetector(
                onTap: onRefresh,
                child: Eyebrow(
                  loading
                      ? 'Loading…'
                      : hasFix
                          ? 'Within 1.5 km'
                          : 'Citywide',
                  color: AppColors.faint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      loading
                          ? 'Checking what is happening around you…'
                          : failed.isNotEmpty
                              ? 'Could not load ${failed.join(', ')}. Pull the label above to retry.'
                              : hasFix
                                  ? 'Nothing active within 1.5 km. That is the good outcome.'
                                  : 'No active incidents in Pasay City right now.',
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _NearbyRow(item: items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.item});

  final NearbyItem item;

  @override
  Widget build(BuildContext context) {
    final live = item.layer == MapLayer.incidents;
    final tint = live
        ? AppColors.forStatus(item.incident?.status ?? 'pending')
        : item.layer == MapLayer.shelters
            ? AppColors.ok
            : AppColors.textSoft;

    return Panel(
      radius: AppRadius.control,
      color: live ? AppColors.surface : AppColors.surfaceDim,
      border: live ? tint.withValues(alpha: 0.3) : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          IconWell(
            tint: tint,
            size: 32,
            glyph: 16,
            asset: switch (item.layer) {
              MapLayer.incidents => Art.agencyBfp,
              MapLayer.shelters => Art.evac,
              MapLayer.hydrants => Art.hydrant,
              MapLayer.risks => Art.incident,
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta,
                ),
              ],
            ),
          ),
          if (live) ...[
            const SizedBox(width: 8),
            Text(
              'LIVE',
              style: AppText.tag.copyWith(color: tint, letterSpacing: 0.8),
            ),
          ],
        ],
      ),
    );
  }
}
