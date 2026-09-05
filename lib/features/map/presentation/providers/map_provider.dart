import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../data/map_api.dart';
import '../../domain/entities/map_entities.dart';

/// The user's current position, or null when it cannot be read.
///
/// Null is a first-class state here rather than an error: the map still works
/// centred on Pasay City, and the hotlines and guides tabs do not need it at
/// all. Refusing to draw a map because permission was denied would be the
/// wrong trade in an emergency app.
final devicePositionProvider = FutureProvider<Position?>((ref) async {
  final result = await ref.watch(locationServiceProvider).getCurrentPosition();
  return result.when(success: (p) => p, failure: (_) => null);
});

/// Everything the map draws, fetched together.
class MapSnapshot {
  const MapSnapshot({
    this.incidents = const [],
    this.shelters = const [],
    this.hydrants = const [],
    this.risks = const [],
    this.failed = const [],
  });

  final List<MapIncident> incidents;
  final List<MapPlace> shelters;
  final List<MapPlace> hydrants;
  final List<MapPlace> risks;

  /// Layers that could not be loaded, named so the UI can say which — a map
  /// silently missing its hydrants is worse than one that admits it.
  final List<String> failed;

  List<MapPlace> placesFor(MapLayer layer) => switch (layer) {
    MapLayer.shelters => shelters,
    MapLayer.hydrants => hydrants,
    MapLayer.risks => risks,
    MapLayer.incidents => const [],
  };
}

final mapSnapshotProvider = FutureProvider<MapSnapshot>((ref) async {
  final api = ref.watch(mapApiProvider);
  final failed = <String>[];

  final results = await Future.wait([
    api.incidents(),
    api.shelters(),
    api.hydrants(),
    api.riskZones(),
  ]);

  List<T> take<T>(int i, String name) => results[i].when(
    success: (value) => value as List<T>,
    failure: (_) {
      failed.add(name);
      return <T>[];
    },
  );

  return MapSnapshot(
    incidents: take<MapIncident>(0, 'incidents'),
    shelters: take<MapPlace>(1, 'shelters'),
    hydrants: take<MapPlace>(2, 'hydrants'),
    risks: take<MapPlace>(3, 'risk areas'),
    failed: failed,
  );
});

/// Which layers are drawn. Incidents are on by default, matching the design.
final activeLayersProvider = StateProvider<Set<MapLayer>>(
  (ref) => {MapLayer.incidents, MapLayer.shelters},
);

/// Anything within this radius counts as "nearby right now" in the sheet.
const kNearbyRadiusMetres = 1500.0;

/// An entry in the bottom sheet, already measured against the user.
class NearbyItem {
  const NearbyItem({
    required this.title,
    required this.subtitle,
    required this.metres,
    required this.layer,
    this.incident,
    this.place,
  });

  final String title;
  final String subtitle;
  final double? metres;
  final MapLayer layer;
  final MapIncident? incident;
  final MapPlace? place;
}

/// Builds the "nearby right now" list: live incidents first, then the closest
/// shelter and hydrant. Distances are computed here because no endpoint takes
/// a radius — the server returns the city and the phone measures.
List<NearbyItem> buildNearby(MapSnapshot snap, Position? me) {
  double? distanceTo(double lat, double lng) => me == null
      ? null
      : metresBetween(me.latitude, me.longitude, lat, lng);

  final out = <NearbyItem>[];

  final incidents = [
    for (final i in snap.incidents)
      (incident: i, metres: distanceTo(i.lat, i.lng)),
  ]..sort((a, b) => (a.metres ?? 1e9).compareTo(b.metres ?? 1e9));

  for (final entry in incidents.take(3)) {
    final i = entry.incident;
    if (entry.metres != null && entry.metres! > kNearbyRadiusMetres) continue;
    out.add(
      NearbyItem(
        title: i.designation,
        subtitle: [
          if (entry.metres != null) formatDistance(entry.metres!),
          IncidentStatus.label(i.status),
          '${i.reportCount} report${i.reportCount == 1 ? '' : 's'}',
        ].join(' · '),
        metres: entry.metres,
        layer: MapLayer.incidents,
        incident: i,
      ),
    );
  }

  MapPlace? closest(List<MapPlace> places) {
    if (places.isEmpty) return null;
    if (me == null) return places.first;
    final sorted = [...places]
      ..sort(
        (a, b) => metresBetween(me.latitude, me.longitude, a.lat, a.lng)
            .compareTo(metresBetween(me.latitude, me.longitude, b.lat, b.lng)),
      );
    return sorted.first;
  }

  for (final place in [closest(snap.shelters), closest(snap.hydrants)]) {
    if (place == null) continue;
    final metres = distanceTo(place.lat, place.lng);
    out.add(
      NearbyItem(
        title: place.kind == MapLayer.shelters
            ? 'Shelter · ${place.name}'
            : 'Nearest hydrant${metres == null ? '' : ' · ${formatDistance(metres)}'}',
        subtitle: [
          if (metres != null && place.kind == MapLayer.shelters)
            formatDistance(metres),
          if (place.detail != null && place.detail!.isNotEmpty) place.detail!,
        ].join(' · '),
        metres: metres,
        layer: place.kind,
        place: place,
      ),
    );
  }

  return out;
}
