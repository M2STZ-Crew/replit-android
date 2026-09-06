import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// The one place the app decides what a map is made of.
///
/// Every screen that draws a map — the citizen home, the SOS capture mini-map,
/// live tracking, directions, and all four staff consoles — uses [layer] and
/// [attribution], so the basemap can be changed in one edit rather than eight.
///
/// The app previously drew CARTO's "Dark Matter" tiles, which were free and
/// key-less when that code was written. CARTO now returns an "API KEY
/// REQUIRED" watermark tile instead of map data, so those maps were rendering
/// a grey placeholder. This draws Mapbox's `dark-v11` — the style the design
/// hand-off specifies — and falls back to plain OpenStreetMap when no token is
/// configured, so a clone without one still gets a working map rather than a
/// blank rectangle.
class MapTiles {
  MapTiles._();

  /// Mapbox public access token.
  ///
  /// A `pk.` token is meant to be embedded in a client — it ships inside the
  /// APK either way and Mapbox's own guidance accepts that; the protection is
  /// URL/scope restrictions and watching usage, not secrecy. Override it for a
  /// rotated token without touching source:
  ///
  ///   flutter run --dart-define=MAPBOX_TOKEN=pk.your_token_here
  static const String token = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue:
        'pk.REDACTED_SEE_ENV_JSON'
        '',
  );

  static bool get hasToken => token.isNotEmpty && token.startsWith('pk.');

  /// The design's basemap. `dark-v11` is Mapbox's dark style, which is what
  /// the hand-off draws its maps on.
  static const String _style = 'dark-v11';

  /// Raster tiles rather than vector: `flutter_map` renders raster, and at
  /// `@2x` on a phone the difference from vector is not visible. Going vector
  /// would mean a second map engine in the app for no gain a user would see.
  static String get _mapboxUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/$_style/tiles/256/'
      '{z}/{x}/{y}@2x?access_token=$token';

  static const String _osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static TileLayer layer() => TileLayer(
    urlTemplate: hasToken ? _mapboxUrl : _osmUrl,
    // Both providers' terms require a real identifying agent.
    userAgentPackageName: 'com.m2stz.replit',
    maxNativeZoom: 19,
  );

  /// Attribution is a licence condition for both providers, not decoration.
  static Widget attribution() => RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    attributions: [
      TextSourceAttribution(
        hasToken ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap',
      ),
    ],
  );
}
