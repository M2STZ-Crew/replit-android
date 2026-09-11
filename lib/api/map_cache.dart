import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The last copy of each citizen map layer, kept on the phone so the map
/// still shows shelters, hydrants and water with no signal — "Map layers
/// cached · Ready" in the REPLIT-OVERHAUL offline frame.
///
/// Only the reference layers are kept. Incident areas are not: an active
/// incident read from a days-old copy would be a lie on the map. The basemap
/// tiles are not either — the markers draw over a blank ground offline.
///
/// Each layer carries its own timestamp. Shelters are re-saved every time the
/// map opens; one shared stamp would make three-day-old hydrants look fresh.
class MapCache {
  MapCache._();

  static final MapCache instance = MapCache._();

  static const String _prefix = 'map_cache_v1_';

  /// Layer keys, matching the endpoints: evac, risk, hydrants, water, cisterns.
  static const List<String> layers = [
    'evac',
    'risk',
    'hydrants',
    'water',
    'cisterns',
  ];

  /// How old a layer may get before the map refreshes it in the background,
  /// whether or not its chip is on.
  static const Duration refreshAfter = Duration(hours: 24);

  Future<void> put(String layer, List<dynamic> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$layer', jsonEncode(rows));
    await prefs.setString(
      '$_prefix${layer}_at',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<List<Map<String, dynamic>>?> get(String layer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$layer');
      if (raw == null) return null;
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> _at(SharedPreferences prefs, String layer) async {
    final raw = prefs.getString('$_prefix${layer}_at');
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  /// When the stalest saved layer was downloaded — the honest answer to
  /// "how old is what the map shows offline". Null when nothing is saved.
  Future<DateTime?> savedAt() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime? oldest;
    for (final layer in layers) {
      final at = await _at(prefs, layer);
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
    }
    return oldest;
  }

  /// Layers with no copy, or one older than [refreshAfter].
  Future<List<String>> stale() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final out = <String>[];
    for (final layer in layers) {
      final at = await _at(prefs, layer);
      if (at == null || now.difference(at) > refreshAfter) out.add(layer);
    }
    return out;
  }
}
