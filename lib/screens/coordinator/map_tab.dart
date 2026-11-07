import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/map_glass.dart';
import '../../widgets/map_marker.dart';
import '../../widgets/map_layers.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/ops_layers.dart';
import '../../widgets/sheet_grip.dart';
import '../../widgets/you_are_here.dart';
import '../responder/responder_status.dart';
import 'area_decision_screen.dart';
import 'coordinator_feed.dart';
import 'coordinator_shell.dart';
import '../../i18n/i18n.dart';

const LatLng _pasay = LatLng(14.5378, 121.0014);

/// The Map tab (06 · C08): every live Area the team can see, over the
/// layers a coordinator plans with — hydrants, shelters, water, risk zones,
/// stations — and a sheet listing the incidents running now.
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
    'fire',
    'police',
  ];

  /// The chip's word: short, as over a map it must be.
  static String _chipLabel(OpsLayer layer) => switch (layer.key) {
    'incidents' => t('Areas'),
    'hydrants' => t('Hydrants'),
    'evac' => t('Shelters'),
    'water' => t('Water'),
    'risk' => t('Risk zones'),
    'fire' => t('Fire stations'),
    'police' => t('Police'),
    _ => layer.label,
  };
  final Set<String> _on = {'incidents', 'hydrants', 'evac'};
  final Map<String, List<OpsPoint>> _cache = {};

  @override
  void initState() {
    super.initState();
    for (final l in _layers) {
      if (_on.contains(l.key)) _fetch(l);
    }
  }

  @override
  void dispose() {
    _follow.dispose();
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
    final markers = <Marker>[
      for (final layer in _layers)
        if (layer.key != 'incidents' && _on.contains(layer.key))
          for (final p in _cache[layer.key] ?? const <OpsPoint>[])
            opsMarker(pal, layer, p),
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
        MarkerLayer(rotate: true, markers: markers),
        YouAreHereLayer(follow: _follow),
        MapLocationButtons(
          follow: _follow,
          alignment: Alignment.topRight,
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 60,
            right: 16,
          ),
        ),
        MapTiles.attribution(),
      ],
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
                      'Nothing is running. New Areas appear here and on the map.',
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
