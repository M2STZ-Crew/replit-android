/// Reference locations for fire and police stations around Pasay City.
///
/// The backend has no fire-/police-station GIS layer (only hydrants, evacuation
/// sites, risk zones, bodies of water, cisterns), so these are static reference
/// points shown on the map. Coordinates are approximate — replace with surveyed
/// values or a backend layer when available.
library;

enum FacilityKind { fire, police }

class Facility {
  const Facility(this.name, this.subtitle, this.kind, this.lat, this.lng);

  final String name;
  final String subtitle;
  final FacilityKind kind;
  final double lat;
  final double lng;
}

const List<Facility> kFireStations = [
  Facility('Pasay City Central Fire Station', 'BFP — F.B. Harrison St', FacilityKind.fire,
      14.5377, 120.9969),
  Facility('Tramo Fire Sub-Station', 'BFP — Tramo, Pasay', FacilityKind.fire, 14.5440, 121.0005),
  Facility('NAIA Fire Station', 'BFP — Airport district', FacilityKind.fire, 14.5110, 121.0130),
];

const List<Facility> kPoliceStations = [
  Facility('Pasay City Police Station', 'PNP — City Headquarters', FacilityKind.police,
      14.5402, 120.9958),
  Facility('Police Station 1 — Malibay', 'PNP — Malibay', FacilityKind.police, 14.5455, 120.9990),
  Facility('Police Station 2 — Maricaban', 'PNP — Maricaban', FacilityKind.police, 14.5300,
      121.0050),
];
