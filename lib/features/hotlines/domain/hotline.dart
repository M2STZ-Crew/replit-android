import '../../../core/widgets/design.dart';

/// The emergency directory from the hand-off.
///
/// These are held in the app, not fetched, on purpose: the whole point of the
/// screen is that it works with no data and no session. A hotline that needs
/// the network to load is a hotline that fails in exactly the situation it
/// exists for.
///
/// VERIFY BEFORE RELEASE — the numbers below are transcribed from the design
/// hand-off. Dialling a wrong number during an emergency is a real harm, so
/// someone on the team should confirm each one against the agency's own
/// published contact page before this ships to residents.
class Hotline {
  const Hotline({
    required this.name,
    required this.blurb,
    required this.primary,
    required this.category,
    this.secondary,
    this.art,
    this.tint,
    this.featured = false,
  });

  final String name;
  final String blurb;

  /// The short number people actually dial. Shown as the headline.
  final String primary;

  /// The landline fallback, shown beneath it.
  final String? secondary;
  final HotlineCategory category;
  final String? art;
  final int? tint;
  final bool featured;

  /// Strip spaces and punctuation for the tel: URI; keep a leading +.
  static String dialable(String number) =>
      number.replaceAll(RegExp(r'[^\d+]'), '');
}

enum HotlineCategory {
  all('All'),
  fire('Fire'),
  medical('Medical'),
  police('Police'),
  pasay('Pasay');

  const HotlineCategory(this.label);
  final String label;
}

const kHotlines = <Hotline>[
  Hotline(
    name: 'National emergency',
    blurb: 'Fire, medical or police — anywhere',
    primary: '911',
    category: HotlineCategory.all,
    art: Art.agency911,
    tint: 0xFFFF9066,
    featured: true,
  ),
  Hotline(
    name: 'Bureau of Fire · NCR',
    blurb: 'Direct line to the fire bureau',
    primary: '160',
    secondary: '(02) 8426 0219',
    category: HotlineCategory.fire,
    art: Art.agencyBfp,
    tint: 0xFFFF544E,
  ),
  Hotline(
    name: 'Philippine National Police',
    blurb: 'Crimes in progress, public safety',
    primary: '117',
    secondary: '(02) 8722 0650',
    category: HotlineCategory.police,
    art: Art.agencyPnp,
    tint: 0xFF8A38F5,
  ),
  Hotline(
    name: 'Pasay City DRRMO',
    blurb: 'City rescue and disaster response',
    primary: '0905 493 9111',
    secondary: 'Local 1371',
    category: HotlineCategory.pasay,
    art: Art.evac,
    tint: 0xFFFF9066,
  ),
  Hotline(
    name: 'Philippine Red Cross',
    blurb: 'Ambulance, blood, water rescue',
    primary: '143',
    secondary: '(02) 8790 2300',
    category: HotlineCategory.medical,
    tint: 0xFFFF544E,
  ),
  Hotline(
    name: 'Pasay City General Hospital',
    blurb: 'P. Burgos St. · emergency room',
    primary: '(02) 8551 0121',
    category: HotlineCategory.pasay,
    art: Art.hospital,
    tint: 0xFF22C55E,
  ),
  Hotline(
    name: 'MMDA',
    blurb: 'Road crashes, flooding, clearing',
    primary: '136',
    secondary: '(02) 8882 4151',
    category: HotlineCategory.all,
    art: Art.agencyMmda,
    tint: 0xFFCFCFCF,
  ),
  Hotline(
    name: 'Pasay City Police Station',
    blurb: 'Station 1 · Taft Avenue',
    primary: '(02) 8831 8064',
    category: HotlineCategory.police,
    art: Art.agencyPnp,
    tint: 0xFF8A38F5,
  ),
  Hotline(
    name: 'Philippine Coast Guard',
    blurb: 'Sea rescue along Manila Bay',
    primary: '(02) 8527 8481',
    category: HotlineCategory.all,
    tint: 0xFF6098D6,
  ),
  Hotline(
    name: 'NDRRMC operations centre',
    blurb: 'Typhoons, earthquakes, national alerts',
    primary: '(02) 8911 1406',
    category: HotlineCategory.all,
    art: Art.incident,
    tint: 0xFFEAB308,
  ),
];
