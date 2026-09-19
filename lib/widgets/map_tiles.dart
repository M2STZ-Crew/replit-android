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

  /// Mapbox public access token, supplied at build time.
  ///
  /// A `pk.` token is meant to be embedded in a client — it ships inside the
  /// APK either way, and Mapbox's guidance accepts that. What it must not do
  /// is sit in a public repository, where scrapers harvest tokens and spend
  /// somebody else's free tier. A web token can be locked to a domain; a
  /// mobile one cannot, so keeping it out of source is the only control there
  /// is.
  ///
  /// It comes from env.json, which is gitignored. Copy env.example.json to
  /// env.json, paste the token in, and run:
  ///
  ///   flutter run   --dart-define-from-file=env.json
  ///   flutter build apk --release --dart-define-from-file=env.json
  ///
  /// Forget the flag and the maps quietly fall back to OpenStreetMap rather
  /// than breaking.
  static const String token = String.fromEnvironment('MAPBOX_TOKEN');

  static bool get hasToken => token.isNotEmpty && token.startsWith('pk.');

  /// The design's basemaps: the hand-off draws its dark frames on Mapbox's
  /// `dark-v11` and its light ones on `light-v11`. A dark map under a light
  /// app is the loudest thing on the screen, so the map follows the ground.
  static const String _darkStyle = 'dark-v11';
  static const String _lightStyle = 'light-v11';

  /// Raster tiles rather than vector: `flutter_map` renders raster, and at
  /// `@2x` on a phone the difference from vector is not visible. Going vector
  /// would mean a second map engine in the app for no gain a user would see.
  static String _mapboxUrl(bool light) =>
      'https://api.mapbox.com/styles/v1/mapbox/'
      '${light ? _lightStyle : _darkStyle}/tiles/256/'
      '{z}/{x}/{y}@2x?access_token=$token';

  static const String _osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// [light] picks the basemap for the palette in force — pass
  /// `context.pal.isLight`. OpenStreetMap's standard tiles are light either
  /// way, which is the right fallback: a missing token should not also mean a
  /// map nobody can read.
  static TileLayer layer({bool light = false}) => TileLayer(
    urlTemplate: hasToken ? _mapboxUrl(light) : _osmUrl,
    // Both providers' terms require a real identifying agent.
    userAgentPackageName: 'com.m2stz.replit',
    maxNativeZoom: 19,
  );

  /// The credit line itself, for a screen that covers the map's corners and
  /// has to show it somewhere else (the citizen map's areas sheet).
  static String get credit =>
      hasToken ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap';

  /// Attribution is a licence condition for both providers, not decoration.
  /// [alignment] moves it off a corner a screen uses for something else.
  static Widget attribution({
    AttributionAlignment alignment = AttributionAlignment.bottomLeft,
  }) => RichAttributionWidget(
    alignment: alignment,
    attributions: [TextSourceAttribution(credit)],
  );
}
