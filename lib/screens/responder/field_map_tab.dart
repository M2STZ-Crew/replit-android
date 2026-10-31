import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../location/live_position.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/map_glass.dart';
import '../../widgets/map_layers.dart';
import '../../widgets/map_marker.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/ops_layers.dart';
import '../../widgets/you_are_here.dart';
import 'responder_feed.dart';
import 'responder_incident_screen.dart';
import 'responder_shell.dart';

const LatLng _pasay = LatLng(14.5378, 121.0014);

/// The field map (REPLIT (MAIN) 07 · R11): every live Area the agency sees,
/// over what a crew fights a fire with — hydrants, shelters, water, cisterns
/// — and the risk zones and stations, in the same legend as every other map
/// ([MapLayerChip], [MapAreas]). The unit card says whether this phone's
/// location is going out; the sheet lists what is within 500 m.
class FieldMapTab extends StatefulWidget {
  const FieldMapTab({super.key, required this.feed, required this.shell});

  final ResponderFeed feed;
  final ResponderShellState shell;

  /// How far "Around you" looks.
  static const double aroundMetres = 500;

  @override
  State<FieldMapTab> createState() => _FieldMapTabState();
}

class _FieldMapTabState extends State<FieldMapTab> {
  final MapFollow _follow = MapFollow();
  final LivePosition _position = LivePosition.instance;

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

  /// The layers whose points are listed under "Around you".
  static const _resources = {'hydrants', 'evac', 'water', 'cisterns'};

  /// The chip's word: short, as over a map it must be.
  static String _chipLabel(OpsLayer layer) => switch (layer.key) {
    'incidents' => 'Areas',
    'hydrants' => 'Hydrants',
    'evac' => 'Shelters',
    'water' => 'Water',
    'risk' => 'Risk zones',
    'fire' => 'Fire stations',
    'police' => 'Police',
    _ => layer.label,
  };

  /// What one point is, in a row.
  static String _noun(String key) => switch (key) {
    'hydrants' => 'Fire hydrant',
    'evac' => 'Evacuation site',
    'water' => 'Body of water',
    'cisterns' => 'Underground cistern',
    _ => 'Place',
  };

  final Set<String> _on = {'incidents', 'hydrants', 'evac'};
  final Map<String, List<OpsPoint>> _cache = {};

  @override
  void initState() {
    super.initState();
    _position.acquire();
    _position.here.addListener(_moved);
    for (final l in _layers) {
      if (_on.contains(l.key)) _fetch(l);
    }
  }

  @override
  void dispose() {
    _position.here.removeListener(_moved);
    _position.release();
    _follow.dispose();
    super.dispose();
  }

  void _moved() {
    if (mounted) setState(() {});
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
          SnackBar(content: Text('Could not load ${layer.label}.')),
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
    if (a.id == widget.feed.runId) {
      widget.shell.show(ResponderTab.run);
      return;
    }
    final feed = widget.feed;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResponderIncidentScreen(
          incidentId: a.id,
          myId: feed.myId,
          agency: feed.agency,
          orgId: feed.orgId,
          unit: feed.unit,
          api: feed.api,
          tracker: feed.tracker,
        ),
      ),
    );
    await feed.load();
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
                    child: _unitCard(),
                  ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.34,
              minChildSize: 0.16,
              maxChildSize: 0.7,
              builder: (context, scroll) => _sheet(scroll),
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
      // The Areas last, so they sit on top.
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
                selected: a.id == widget.feed.runId,
                onTap: () => _open(a),
              ),
            ),
    ];
    return FlutterMap(
      options: MapOptions(
        initialCenter: _pasay,
        initialZoom: 14,
        backgroundColor: pal.background,
        interactionOptions: kMapGestures,
        onMapEvent: _follow.onMapEvent,
      ),
      children: [
        MapTiles.layer(light: pal.isLight),
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

  /// The unit and whether its location is going out (Glass strong: it
  /// carries a status line).
  Widget _unitCard() {
    final feed = widget.feed;
    final sharing = feed.tracker.isSharing;
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
            const CoralPlate(AppIcons.fireTruck),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feed.unit.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sharing
                        ? 'Location sharing is on'
                        : 'Location sharing is off',
                    style: context.type.caption.copyWith(
                      color: sharing ? context.pal.ok : context.pal.textSoft,
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

  /// What is within [FieldMapTab.aroundMetres] of this phone, nearest first,
  /// from the layers that are on.
  List<({OpsLayer layer, OpsPoint point, double metres})> _around(LatLng here) {
    final found = [
      for (final layer in _layers)
        if (_resources.contains(layer.key) && _on.contains(layer.key))
          for (final p in _cache[layer.key] ?? const <OpsPoint>[])
            (layer: layer, point: p, metres: metresBetween(here, p.point)),
    ]..removeWhere((f) => f.metres > FieldMapTab.aroundMetres);
    found.sort((a, b) => a.metres.compareTo(b.metres));
    return found.take(8).toList();
  }

  Widget _sheet(ScrollController scroll) {
    final pal = context.pal;
    final here = _position.here.value;
    final runId = widget.feed.runId;
    final run = runId == null ? null : widget.feed.byId(runId);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: MapGlass.strong(context),
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          24,
          10,
          24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const Center(child: SheetHandle(margin: EdgeInsets.zero)),
          const SizedBox(height: 16),
          SectionHeader(
            'Around you',
            meta: 'Within ${FieldMapTab.aroundMetres.round()} m',
          ),
          const SizedBox(height: 12),
          if (here == null)
            Text(
              'Hydrants, shelters and water near you are listed here once '
              'the phone knows where you are.',
              style: context.type.bodySm,
            )
          else
            ..._aroundRows(here, run),
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

  List<Widget> _aroundRows(LatLng here, AreaView? run) {
    final near = _around(here);
    if (near.isEmpty) {
      return [
        Text(
          'Nothing from the layers that are on is within '
          '${FieldMapTab.aroundMetres.round()} m. Turn on Water or Cisterns '
          'for more.',
          style: context.type.bodySm,
        ),
      ];
    }
    final pal = context.pal;
    final centre = run?.centre;
    String? line(OpsPoint p) {
      final parts = [
        ?p.name,
        if (centre != null)
          '${formatDistance(metresBetween(p.point, centre))} from ${run!.name}',
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }

    return [
      for (final f in near) ...[
        ListRow(
          leading: IconPlate(
            f.layer.kind?.glyph ?? AppIcons.locationOn,
            tint: f.layer.colour(pal),
          ),
          title: _noun(f.layer.key),
          subtitle: line(f.point),
          trailing: RowValue(formatDistance(f.metres), color: pal.onBackground),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}
