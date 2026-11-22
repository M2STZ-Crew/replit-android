import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/area_view.dart';
import '../../models/water_source.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/barangay_layer.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/fire_ripple.dart';
import '../../widgets/design.dart';
import '../../widgets/map_glass.dart';
import '../../widgets/map_marker.dart';
import '../../widgets/map_layers.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/ops_layers.dart';
import '../../widgets/sheet_grip.dart';
import '../../widgets/shelter_sheet.dart';
import '../../widgets/water_source_sheet.dart';
import '../../widgets/you_are_here.dart';
import '../responder/responder_status.dart';
import 'area_decision_screen.dart';
import 'coordinator_feed.dart';
import 'coordinator_shell.dart';
import '../../i18n/i18n.dart';
import '../../widgets/map_layer_gate.dart';
import '../../widgets/alarm_status_banner.dart';

const LatLng _pasay = LatLng(14.5378, 121.0014);

/// The Map tab (06 · C08): every live Area the team can see, over the
/// layers a coordinator plans with — hydrants, shelters, water, risk zones,
/// stations — and a sheet listing the incidents running now.
///
/// A water source opens its sheet when tapped (v1.12.55): directions for
/// everyone, and for Fire Volunteer and BFP coordinators its status, edits
/// and switching it off; their + adds one at a pin.
class MapTab extends StatefulWidget {
  const MapTab({super.key, required this.feed, required this.shell});

  final CoordinatorFeed feed;
  final CoordinatorShellState shell;

  @override
  State<MapTab> createState() => _MapTabState();
}

/// The incidents sheet's sizes, shared by the sheet and its frozen grip.
const double _sheetMin = 0.16;
const double _sheetMax = 0.8;

class _MapTabState extends State<MapTab> {
  final MapFollow _follow = MapFollow();
  final MapController _mapController = MapController();

  /// What this coordinator may do with water (backend v1.12.43).
  late final WaterPowers _powers = WaterPowers.of(widget.feed.me);

  /// Placing a new water source: the map moves under a pin at its centre.
  bool _pinning = false;

  /// The incidents sheet, so its frozen grip can drag it.
  final DraggableScrollableController _sheetSize =
      DraggableScrollableController();

  /// The staff layers in the design's chip order: Areas, then what a crew
  /// fights a fire with, then the rest.
  late final List<OpsLayer> _layers = [
    for (final key in _order)
      ...opsLayers(widget.feed.api).where((l) => l.key == key),
  ];

  static const _order = [
    'incidents',
    'hydrants',
    'evac',
    'water',
    'cisterns',
    'risk',
    kFireRiskLayer,
    kBarangaysLayer,
    'fire',
    'police',
  ];

  /// The chip's word: short, as over a map it must be.
  static String _chipLabel(OpsLayer layer) => switch (layer.key) {
    'incidents' => t('Fires'),
    'hydrants' => t('Hydrants'),
    'evac' => t('Shelters'),
    'water' => t('Water'),
    'risk' => t('Risk zones'),
    kFireRiskLayer => t('High fire risk'),
    kBarangaysLayer => t('Barangays'),
    'fire' => t('Fire stations'),
    'police' => t('Police'),
    _ => layer.label,
  };
  final Set<String> _on = {'incidents', 'hydrants', 'evac', kFireRiskLayer};

  /// The barangay layer's polygons (v1.12.57), read once either chip is on.
  List<Map<String, dynamic>> _barangayRows = const [];
  BarangayShapes _barangayShapes = BarangayShapes.empty;
  Brightness? _barangayShade;
  bool _barangaysAsked = false;

  Future<void> _loadBarangays() async {
    if (_barangaysAsked) return;
    _barangaysAsked = true;
    try {
      final rows = (await widget.feed.api.getBarangays())
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _barangayRows = rows);
    } catch (_) {
      _barangaysAsked = false; // try again when a chip is next turned on
    }
  }

  BarangayShapes _shapes(AppPalette pal) {
    final shade = pal.isLight ? Brightness.light : Brightness.dark;
    if (_barangayShade != shade ||
        (_barangayShapes.outlines.isEmpty && _barangayRows.isNotEmpty)) {
      _barangayShade = shade;
      _barangayShapes = BarangayShapes.from(_barangayRows, pal);
    }
    return _barangayShapes;
  }
  final Map<String, List<OpsPoint>> _cache = {};

  @override
  void initState() {
    super.initState();
    for (final l in _layers) {
      if (_on.contains(l.key)) _fetch(l);
    }
    unawaited(_loadBarangays());
  }

  @override
  void dispose() {
    _follow.dispose();
    _mapController.dispose();
    _sheetSize.dispose();
    super.dispose();
  }

  Future<void> _fetch(OpsLayer layer) async {
    final load = layer.load;
    if (load == null || _cache.containsKey(layer.key)) return;
    try {
      final points = await load();
      if (mounted) setState(() => _cache[layer.key] = points);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Could not load {label}.', {'label': layer.label})),
          ),
        );
      }
    }
  }

  void _toggle(OpsLayer layer) {
    setState(() {
      if (!_on.remove(layer.key)) _on.add(layer.key);
    });
    if (_on.contains(layer.key)) _fetch(layer);
    if (_on.contains(kFireRiskLayer) || _on.contains(kBarangaysLayer)) {
      unawaited(_loadBarangays());
    }
  }

  /// A water source's or shelter's sheet, on a tap (v1.12.55, v1.12.56);
  /// risk zones and stations open nothing.
  VoidCallback? _tapFor(OpsLayer layer, OpsPoint p) {
    final kind = WaterKind.ofLayer(layer.key);
    final row = p.row;
    if (layer.key == 'evac' && row != null) {
      return () => openStaffShelter(context, row);
    }
    final source = kind == null || row == null
        ? null
        : WaterSource.from(kind, row);
    if (source == null) return null;
    return () => _openWater(layer, source);
  }

  Future<void> _openWater(OpsLayer layer, WaterSource source) async {
    final changed = await openWaterSource(
      context,
      source: source,
      powers: _powers,
      api: widget.feed.api,
    );
    if (changed) await _reload(layer);
  }

  /// Reads a layer again, keeping what is drawn until the new points come:
  /// a status just saved shows at once.
  Future<void> _reload(OpsLayer layer) async {
    final load = layer.load;
    if (load == null) return;
    try {
      final points = await load();
      if (mounted) setState(() => _cache[layer.key] = points);
    } catch (_) {
      // What was drawn stays.
    }
  }

  /// The + : the map holds still under a pin, close enough to place it.
  void _startPin() {
    _follow.release();
    final camera = _mapController.camera;
    if (camera.zoom < 17) _mapController.move(camera.center, 17);
    setState(() => _pinning = true);
  }

  Future<void> _usePin() async {
    final point = _mapController.camera.center;
    setState(() => _pinning = false);
    final sent = await proposeWaterSource(
      context,
      point: point,
      api: widget.feed.api,
    );
    if (!sent && mounted) setState(() => _pinning = true);
  }

  Future<void> _open(AreaView a) async {
    if (a.live) {
      widget.shell.showLive(a.id);
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AreaDecisionScreen(
          areaId: a.id,
          me: widget.feed.me,
          api: widget.feed.api,
          onLive: widget.shell.showLive,
        ),
      ),
    );
    await widget.feed.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.feed,
      builder: (context, _) {
        final areas = widget.feed.areas;
        return Stack(
          children: [
            Positioned.fill(child: _map(areas)),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(height: 44, child: _chips()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 80, 0),
                    child: _teamCard(areas),
                  ),
                ],
              ),
            ),
            if (_pinning) ...[
              const IgnorePointer(child: _Pin()),
              _pinPanel(),
            ] else
              DraggableScrollableSheet(
                controller: _sheetSize,
                initialChildSize: 0.36,
                minChildSize: _sheetMin,
                maxChildSize: _sheetMax,
                builder: (context, scroll) => _sheet(areas, scroll),
              ),
          ],
        );
      },
    );
  }

  Widget _map(List<AreaView> areas) {
    final pal = context.pal;
    // The layers' points, drawn from street level in (v1.12.50).
    final layerMarkers = <Marker>[
      for (final layer in _layers)
        if (layer.key != 'incidents' && _on.contains(layer.key))
          for (final p in _cache[layer.key] ?? const <OpsPoint>[])
            opsMarker(pal, layer, p, onTap: _tapFor(layer, p)),
    ];
    final markers = <Marker>[
      if (_on.contains('incidents'))
        for (final a in areas)
          if (a.centre != null)
            Marker(
              point: a.centre!,
              width: MapMarker.target,
              height: MapMarker.target,
              child: MapMarker(
                kind: MapMarkerKind.incident,
                label: a.name,
                live: a.live,
                onTap: () => _open(a),
              ),
            ),
    ];
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _pasay,
        initialZoom: 14,
        backgroundColor: context.pal.background,
        interactionOptions: kMapGestures,
        onMapEvent: _follow.onMapEvent,
      ),
      children: [
        MapTiles.layer(light: pal.isLight),
        // Risk zones in red, as on the resident's map; the marker is the
        // zone's handle.
        if (_on.contains('risk'))
          PolygonLayer(
            polygons: [
              for (final p in _cache['risk'] ?? const <OpsPoint>[])
                ...MapAreas.riskZone(pal, p.area),
            ],
          ),
        if (_on.contains('incidents'))
          CircleLayer(
            circles: [
              for (final a in areas)
                if (a.centre != null)
                  MapAreas.incidentRadius(
                    pal,
                    a.centre!,
                    metres: kAreaRadiusMetres,
                  ),
            ],
          ),
        if (_on.contains('incidents'))
          FireRipple(centres: [for (final a in areas) ?a.centre]),
        if (_on.contains(kBarangaysLayer) || _on.contains(kFireRiskLayer))
          BarangayLayer(
            shapes: _shapes(pal),
            outlines: _on.contains(kBarangaysLayer),
            risk: _on.contains(kFireRiskLayer),
          ),
        ZoomGatedMarkers(markers: layerMarkers),
        MarkerLayer(rotate: true, markers: markers),
        YouAreHereLayer(follow: _follow),
        MapLocationButtons(
          follow: _follow,
          alignment: Alignment.topRight,
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 60,
            right: 16,
          ),
          extra: [
            if (_powers.propose && !_pinning)
              MapControlButton(
                label: t('Add a water source'),
                onTap: _startPin,
                child: Icon(AppIcons.add, size: 22, color: pal.water),
              ),
          ],
        ),
        MapTiles.attribution(),
      ],
    );
  }

  /// While placing a new water source: what to do, and the two ways out.
  Widget _pinPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MapGlass.strong(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.pal.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Move the map until the pin is on the water source.'),
                style: context.type.bodySm,
              ),
              const SizedBox(height: 12),
              AppButton(t('Use this spot'), onPressed: _usePin),
              const SizedBox(height: 10),
              AppButton.secondary(
                t('Cancel'),
                onPressed: () => setState(() => _pinning = false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _layers.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final layer = _layers[i];
        return MapLayerChip(
          label: _chipLabel(layer),
          tone: layer.colour(context.pal),
          on: _on.contains(layer.key),
          onTap: () => _toggle(layer),
        );
      },
    );
  }

  Widget _teamCard(List<AreaView> areas) {
    final me = widget.feed.me;
    final team = (me['organization_name'] as String?)?.trim();
    final live = areas.where((a) => a.live).length;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MapGlass.strong(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.pal.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoralPlate(AppIcons.locationOn),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (team == null || team.isEmpty
                            ? responderAgencyLabel(widget.feed.agency)
                            : team)
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('Monitoring Pasay · {value}', {
                      'value': live == 0
                          ? t('nothing on the ground')
                          : t('{live} on the ground', {'live': live}),
                    }),
                    style: context.type.caption.copyWith(
                      color: context.pal.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(List<AreaView> areas, ScrollController scroll) {
    final pal = context.pal;
    final running = areas.length;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: MapGlass.strong(context),
        border: Border(top: BorderSide(color: pal.line)),
      ),
      // The grip is frozen above the list: the rows scroll under it.
      child: Column(
        children: [
          SheetGrip(
            sheet: _sheetSize,
            minSize: _sheetMin,
            maxSize: _sheetMax,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                SectionHeader(
                  t('Live incidents'),
                  meta: running == 1
                      ? t('1 running now')
                      : t('{running} running now', {'running': running}),
                ),
                const SizedBox(height: 12),
                if (areas.isEmpty)
                  Text(
                    t(
                      'Nothing is running. New incidents appear here and on the map.',
                    ),
                    style: context.type.bodySm,
                  ),
                for (final a in areas) ...[
                  AreaPlace(
                    area: a,
                    builder: (context, place) => ListRow(
                      leading: const AgencyPlate(),
                      title: place.street == null
                          ? a.name
                          : '${a.name} · ${place.street}',
                      subtitle: [
                        if (place.place != null) place.place!.split(',').first,
                        if (place.street == null && place.place == null)
                          placeLine(a, place),
                        if (a.requested.isNotEmpty) askedFor(a.requested),
                      ].join(' · '),
                      trailing: _Standing(area: a),
                      onTap: () => _open(a),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      child: MapGlass.blurs(context)
          ? BackdropFilter(filter: MapGlass.blur, child: body)
          : body,
    );
  }
}

/// The pin a new water source goes at: its point on the map's centre.
class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Icon(
          AppIcons.locationOn,
          size: 40,
          color: context.pal.water,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    );
  }
}

/// A live incident's standing at the end of its row: the status word, the
/// report count and the confidence band as three short bars.
class _Standing extends StatelessWidget {
  const _Standing({required this.area});

  final AreaView area;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final filled = switch (area.band) {
      'high' => 3,
      'medium' => 2,
      'low' => 1,
      _ => 0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Eyebrow(
          LifecycleChip.word(area.status),
          color: pal.forStatus(area.status),
        ),
        const SizedBox(height: 4),
        if (area.alarm.known) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: AlarmBadge(area.alarm),
          ),
          const SizedBox(height: 4),
        ],
        Eyebrow(
          area.reports == 1
              ? t('1 report')
              : t('{reports} reports', {'reports': area.reports}),
          color: pal.label,
        ),
        const SizedBox(height: 4),
        Semantics(
          label: t('{bandWord} confidence', {'bandWord': area.bandWord}),
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Container(
                  width: 8,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < filled ? pal.accent : pal.lineStrong,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
