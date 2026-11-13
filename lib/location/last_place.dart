import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_position.dart';

/// Where this phone last knew it was, and the street found nearby: the map
/// opens there, not on Pasay, and stays put while a fresh fix is found.
///
/// 13 November 2026: "the map still locates pasay, what if the map stays
/// still where the user is or was. and it has "LOCATING YOU"" (answered:
/// where you last were). Leaving the map for the hotlines and coming back
/// opened it on Pasay City and jumped to the resident a moment later. Now it
/// opens where they were, at street level, and moves only if they have moved.
/// Kept on the phone, so a restart opens there too. Only a phone that has
/// never had a fix starts on Pasay.
abstract final class LastPlace {
  static const String _key = 'last_place.v1';

  /// A new spot is written to the phone once it is this far from the last.
  static const double saveEveryMetres = 25;

  /// A street found here still names a fix this close to where it was found.
  static const double sameStreetMetres = 75;

  static LatLng? _value;
  static String? _street;
  static LatLng? _streetAt;

  /// The last spot, or null on a phone that has never had a fix.
  static LatLng? get value => _value;

  /// The street to show at [here] before the geocoder answers: the one last
  /// found, when [here] is still close to where it was found.
  static String? streetNear(LatLng here) {
    final at = _streetAt;
    if (at == null || _street == null) return null;
    return metresBetween(at, here) <= sameStreetMetres ? _street : null;
  }

  /// Reads the spot kept on the phone (main(), before the first frame).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _value = _point(json['lat'], json['lng']);
      _street = json['street'] as String?;
      _streetAt = _point(json['street_lat'], json['street_lng']);
    } catch (_) {
      // Nothing kept, or unreadable: the map starts on Pasay, as before.
    }
  }

  /// Keeps [here] as the last spot, and [street] as the street found there.
  /// Written to the phone only when the spot has moved [saveEveryMetres] or
  /// a street is new, so a walk does not write on every fix.
  static void remember(LatLng here, {String? street}) {
    final before = _value;
    final moved =
        before == null || metresBetween(before, here) >= saveEveryMetres;
    final named = street != null && street != _street;
    if (moved) _value = here;
    if (street != null) {
      _street = street;
      _streetAt = here;
    }
    if (moved || named) unawaited(_save());
  }

  static LatLng? _point(Object? lat, Object? lng) =>
      lat is num && lng is num ? LatLng(lat.toDouble(), lng.toDouble()) : null;

  static Future<void> _save() async {
    final at = _value;
    if (at == null) return;
    final streetAt = _streetAt;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'lat': at.latitude,
          'lng': at.longitude,
          'street': ?_street,
          'street_lat': ?streetAt?.latitude,
          'street_lng': ?streetAt?.longitude,
        }),
      );
    } catch (_) {
      // Kept for this session only.
    }
  }

  /// Forgets the spot in memory (tests).
  static void reset() {
    _value = null;
    _street = null;
    _streetAt = null;
  }
}
