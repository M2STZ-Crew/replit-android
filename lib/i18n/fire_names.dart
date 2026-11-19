/// A fire's name (v1.12.53, 18 Nov 2026: "instead of area, it will be called
/// 'Near [street]' or the street itself because 'Area #1' is not appropriate
/// or overwhelming to citizens and to all"; answered "Corner, else Near", and
/// the area number "Nowhere on screen").
///
/// The server names each fire after the streets around it and sends that name
/// as the area's designation (backend app/services/place_names.py): "Taft
/// Avenue corner Gil Puyat Avenue" when two streets meet within 30 m, else
/// "Near F. Victor Street", with " (2)" for a second live fire of the same
/// name, or its coordinates when no street is near. The Area number is kept
/// for the PDF report only. Tagalog says "Malapit sa F. Victor Street"; a
/// corner reads the same in both, the way Metro Manila says it.
library;

import 'i18n.dart';

const String _near = 'Near ';

/// The fire's name in the app's language: "Malapit sa F. Victor Street" in
/// Tagalog. Empty when the fire has none yet.
String fireName(String? designation) {
  final text = (designation ?? '').trim();
  if (LanguageChoice.tagalog && text.startsWith(_near)) {
    return 'Malapit sa ${text.substring(_near.length)}';
  }
  return text;
}

/// [fireName], or [fallback] while the fire has no name.
String fireNameOr(String? designation, String fallback) {
  final name = fireName(designation);
  return name.isEmpty ? fallback : name;
}

/// The fire inside a sentence: "the fire near F. Victor Street", "the fire at
/// Taft Avenue corner Gil Puyat Avenue"; in Tagalog "sunog malapit sa ...",
/// "sunog sa ...". Without a name, "the fire" / "sunog".
String fireAt(String? designation) {
  final text = (designation ?? '').trim();
  final near = text.startsWith(_near);
  final rest = near ? text.substring(_near.length) : text;
  if (LanguageChoice.tagalog) {
    if (text.isEmpty) return 'sunog';
    return near ? 'sunog malapit sa $rest' : 'sunog sa $rest';
  }
  if (text.isEmpty) return 'the fire';
  return near ? 'the fire near $rest' : 'the fire at $rest';
}
