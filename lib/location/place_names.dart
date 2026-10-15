import 'package:geocoding/geocoding.dart' as geo;

/// Where a point is, in words: its street and the barangay or city around it.
///
/// An Area carries no address and no incident type (the server stores a
/// centroid), so the coordinator screens name an Area by its street, as the
/// resident's Area detail does, and fall back to the degrees (PRD §4.10) when
/// the phone's geocoder knows nothing.
class PlaceName {
  const PlaceName({this.street, this.place});

  /// "F. Victor Street", or null.
  final String? street;

  /// "Barangay 76, Pasay City", or null.
  final String? place;

  static const PlaceName none = PlaceName();

  /// "F. Victor Street, Barangay 76" — whichever parts are known.
  String? get line {
    final parts = [street, place].whereType<String>();
    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// Looks each point up once per run: a queue of a dozen Areas re-read every
/// few seconds must not ask the geocoder a dozen times a poll.
abstract final class PlaceNames {
  static final Map<String, Future<PlaceName>> _cache = {};

  /// How a point is looked up. Replaceable in tests, which have no geocoder.
  static Future<PlaceName> Function(double lat, double lng) lookUp = _geocode;

  static Future<PlaceName> of(double lat, double lng) => _cache.putIfAbsent(
    // ~11 m: an Area's centre moves a little as reports join it.
    '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}',
    () => lookUp(lat, lng).catchError((_) => PlaceName.none),
  );

  /// For tests.
  static void clear() => _cache.clear();

  static Future<PlaceName> _geocode(double lat, double lng) async {
    final marks = await geo.placemarkFromCoordinates(lat, lng);
    if (marks.isEmpty) return PlaceName.none;
    final m = marks.first;
    String? clean(String? s) {
      final v = s?.trim() ?? '';
      // Android answers with a Plus Code where it knows no street.
      return v.isEmpty || v.contains('+') ? null : v;
    }

    final place = [
      clean(m.subLocality),
      clean(m.locality),
    ].whereType<String>().toSet().join(', ');
    return PlaceName(
      street: clean(m.thoroughfare) ?? clean(m.street),
      place: place.isEmpty ? null : place,
    );
  }
}

/// "14.5378° N, 121.0014° E".
String degrees(double lat, double lng) {
  final ns = lat >= 0 ? 'N' : 'S';
  final ew = lng >= 0 ? 'E' : 'W';
  return '${lat.abs().toStringAsFixed(4)}° $ns, '
      '${lng.abs().toStringAsFixed(4)}° $ew';
}
