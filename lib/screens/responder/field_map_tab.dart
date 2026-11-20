import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../location/live_position.dart';
import '../../models/area_view.dart';
import '../../models/water_source.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/barangay_layer.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/map_glass.dart';
import '../../widgets/map_layers.dart';
import '../../widgets/map_marker.dart';
import '../../widgets/map_tiles.dart';
import '../../widgets/ops_layers.dart';
import '../../widgets/sheet_grip.dart';
import '../../widgets/shelter_sheet.dart';
import '../../widgets/water_source_sheet.dart';
import '../../widgets/you_are_here.dart';
import 'responder_feed.dart';
import 'responder_incident_screen.dart';
import 'responder_shell.dart';
import '../../i18n/i18n.dart';
import '../../widgets/map_layer_gate.dart';

const LatLng _pasay = LatLng(14.5378, 121.0014);

/// The field map (REPLIT (MAIN) 07 · R11): every live Area the agency sees,
/// over what a crew fights a fire with — hydrants, shelters, water, cisterns
/// — and the risk zones and stations, in the same legend as every other map
/// ([MapLayerChip], [MapAreas]). The unit card says whether this phone's
/// location is going out; the sheet lists what is within 500 m.
///
/// A water source, on the map or in the list, opens its sheet (v1.12.55):
/// directions, and for Fire Volunteer and BFP responders a hydrant's
/// status.
class FieldMapTab extends StatefulWidget {
  const FieldMapTab({super.key, required this.feed, required this.shell});

  final ResponderFeed feed;
  final ResponderShellState shell;

  /// How far "Around you" looks.
  static const double aroundMetres = 500;

  @override
  State<FieldMapTab> createState() => _FieldMapTabState();
}

/// The "Around you" sheet's sizes, shared by the sheet and its frozen grip.
const double _sheetMin = 0.16;
const double _sheetMax = 0.7;

class _FieldMapTabState extends State<FieldMapTab> {
  final MapFollow _follow = MapFollow();

  /// The "Around you" sheet, so its frozen grip can drag it.
  final DraggableScrollableController _sheetSize =
      DraggableScrollableController();
  final LivePosition _position = LivePosition.instance;

  /// What this responder may do with water (backend v1.12.43).
  late final WaterPowers _powers = WaterPowers.of(widget.feed.me);

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

  /// The layers whose points are listed under "Around you".
  static const _resources = {'hydrants', 'evac', 'water', 'cisterns'};

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

  /// What one point is, in a row.
  static String _noun(String key) => switch (key) {
    'hydrants' => t('Fire hydrant'),
    'evac' => t('Evacuation site'),
    'water' => t('Body of water'),
    'cisterns' => t('Underground cistern'),
    _ => t('Place'),
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
    _position.acquire();
    _position.here.addListener(_moved);
    for (final l in _layers) {
      if (_on.contains(l.key)) _fetch(l);
    }
    unawaited(_loadBarangays());
  }

  @override
  void dispose() {
    _position.here.removeListener(_moved);
    _position.release();
    _follow.dispose();
    _sheetSize.dispose();
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
              controller: _sheetSize,
              initialChildSize: 0.34,
              minChildSize: _sheetMin,
              maxChildSize: _sheetMax,
              builder: (context, scroll) => _sheet(scroll),
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
                        ? t('Location sharing is on')
                        : t('Location sharing is off'),
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
                  t('Around you'),
                  meta: t('Within {aroundMetres} m', {
                    'aroundMetres': FieldMapTab.aroundMetres.round(),
                  }),
                ),
                const SizedBox(height: 12),
                if (here == null)
                  Text(
                    t(
                      'Hydrants, shelters and water near you are listed here '
                      'once the phone knows where you are.',
                    ),
                    style: context.type.bodySm,
                  )
                else
                  ..._aroundRows(here, run),
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

  List<Widget> _aroundRows(LatLng here, AreaView? run) {
    final near = _around(here);
    if (near.isEmpty) {
      return [
        Text(
          t(
            'Nothing from the layers that are on is within {aroundMetres} m. Turn on Water or Cisterns for more.',
            {'aroundMetres': FieldMapTab.aroundMetres.round()},
          ),
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
          t('{formatDistance} from {name}', {
            'formatDistance': formatDistance(metresBetween(p.point, centre)),
            'name': run!.name,
          }),
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
          onTap: _tapFor(f.layer, f.point),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}
