import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/network/api_client.dart';
import '../../reports/data/report_api.dart' show apiClientProvider;
import '../domain/entities/map_entities.dart';

final mapApiProvider = Provider<MapApi>(
  (ref) => MapApi(ref.watch(apiClientProvider)),
);

/// Reads the citizen-visible map layers.
///
/// Every endpoint here is `CurrentUser` on the server — any signed-in account
/// may read them. The staff-only GET /incidents is deliberately not used: it
/// carries dispatch counts and agency scoping that a resident should not see,
/// and it would 403 for them anyway.
class MapApi {
  MapApi(this._client);

  final ApiClient _client;

  /// GET /areas — active incident clusters citywide.
  Future<Result<List<MapIncident>>> incidents() async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/areas',
        queryParameters: {'active_only': true},
      );
      if (response.statusCode == 200 && response.data != null) {
        return Success([
          for (final row in response.data!)
            MapIncident.fromMap(row as Map<String, dynamic>),
        ]);
      }
      return Failure(ApiClient.toException(StateError('areas'), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }

  /// GET /map/evacuation-sites — the design calls these "shelters", which is
  /// what a resident calls them; the API name is kept out of the UI.
  Future<Result<List<MapPlace>>> shelters() async {
    return _places('/map/evacuation-sites', (m) {
      final capacity = (m['capacity'] as num?)?.toInt();
      return MapPlace(
        id: m['id'] as String,
        kind: MapLayer.shelters,
        name: m['name'] as String? ?? 'Evacuation site',
        lat: (m['latitude'] as num).toDouble(),
        lng: (m['longitude'] as num).toDouble(),
        detail: [
          if (m['address'] != null) m['address'] as String,
          if (capacity != null) 'space for $capacity',
        ].join(' · '),
        ok: m['is_active'] as bool? ?? true,
      );
    });
  }

  /// GET /map/hydrants.
  Future<Result<List<MapPlace>>> hydrants() async {
    return _places('/map/hydrants', (m) {
      // effective_status is the ground-truth override where a responder has
      // set one, otherwise the BFP feed. It is the only status worth showing.
      final status = m['effective_status'] as String? ?? 'unknown';
      return MapPlace(
        id: m['id'] as String,
        kind: MapLayer.hydrants,
        name: m['code'] as String? ?? 'Hydrant',
        lat: (m['latitude'] as num).toDouble(),
        lng: (m['longitude'] as num).toDouble(),
        detail: [
          if (m['address'] != null) m['address'] as String,
          status.replaceAll('_', ' '),
        ].join(' · '),
        ok: status == 'operational',
      );
    });
  }

  /// GET /map/risk-zones — centroid only; the polygon is not exposed.
  Future<Result<List<MapPlace>>> riskZones() async {
    return _places('/map/risk-zones', (m) {
      final lat = m['centroid_lat'] ?? m['latitude'];
      final lng = m['centroid_lng'] ?? m['longitude'];
      return MapPlace(
        id: m['id'] as String,
        kind: MapLayer.risks,
        name: m['name'] as String? ?? 'Risk area',
        lat: (lat as num).toDouble(),
        lng: (lng as num).toDouble(),
        detail: m['risk_level'] as String?,
        ok: false,
      );
    });
  }

  Future<Result<List<MapPlace>>> _places(
    String path,
    MapPlace Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await _client.get<List<dynamic>>(path);
      if (response.statusCode == 200 && response.data != null) {
        final out = <MapPlace>[];
        for (final row in response.data!) {
          final map = row as Map<String, dynamic>;
          // A layer row with no coordinates cannot be drawn; skipping it beats
          // taking the whole layer down with a cast error.
          if (map['latitude'] == null && map['centroid_lat'] == null) continue;
          out.add(parse(map));
        }
        return Success(out);
      }
      return Failure(ApiClient.toException(StateError(path), response));
    } catch (error) {
      return Failure(ApiClient.toException(error));
    }
  }
}
