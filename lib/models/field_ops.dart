/// The presentation models for the PRD v13 field operations that the pass 6
/// design draws (REPLIT (MAIN) 04 · V13 field operations): fire type on
/// arrival, the decline report, on-scene requests, the neighbourhood safety
/// answers, citizen fire-out votes, the CIAR's state and water levels.
///
/// None of these is sent anywhere by this file. The API the app talks to is
/// still the v12 one: `POST /incidents/{id}/arrived` takes no body, there is
/// no decline, admin-request, safety-response, fire-out-vote, water-level or
/// CIAR endpoint (PRD v13 §17.3). The widgets built on these models take a
/// callback for every act, so whoever wires an endpoint owns the call and its
/// result; see docs/FRONTEND_INTEGRATION_HANDOFF.md.
library;

/// What is burning (PRD v13 §4.5.3). The wire values are the PRD's
/// `fire_type` enum (§6.2).
///
/// PRD v14 removed Agricultural from Structural: Pasay has no agricultural
/// land. It is not offered any more; an older report that carries it still
/// reads, because a [FireClassification] keeps its subtype as words.
enum FireType {
  structural('structural', 'Structural', [
    'Residential',
    'Commercial',
    'Industrial',
  ]),
  electrical('electrical', 'Electrical', [
    'High-tension wire',
    'Transformer',
    'Entrance wire',
    'Meter',
  ]),
  vehicular('vehicular', 'Vehicular', [
    'Motorcycle',
    'Tricycle',
    'Sedan',
    'SUV',
    'Truck',
    'E-bike',
    'E-car',
  ]),
  rubbish('rubbish', 'Rubbish', []),
  grass('grass', 'Grass', []),
  chemical('chemical', 'Chemical', []);

  const FireType(this.wire, this.label, this.subtypes);

  final String wire;
  final String label;

  /// The subtypes in the order the sheet lists them; empty when the type is
  /// confirmed directly (Rubbish, Grass, Chemical).
  final List<String> subtypes;

  bool get hasSubtypes => subtypes.isNotEmpty;
}

/// A fire type, and its subtype when it has them.
class FireClassification {
  const FireClassification(this.type, [this.subtype])
    : assert(
        subtype == null || subtype != '',
        'an empty subtype is no subtype',
      );

  final FireType type;
  final String? subtype;

  /// "Structural — Residential", or "Rubbish".
  String get label => subtype == null ? type.label : '${type.label} — $subtype';

  @override
  bool operator ==(Object other) =>
      other is FireClassification &&
      other.type == type &&
      other.subtype == subtype;

  @override
  int get hashCode => Object.hash(type, subtype);
}

/// What a Responder found instead of a fire (PRD v13 §4.5.3, decline report).
enum DeclineCategory {
  prank('prank', 'Prank'),
  alreadyOut('already_extinguished', 'Already extinguished'),
  wrongAddress('wrong_address', 'Wrong address'),
  other('other', 'Other');

  const DeclineCategory(this.wire, this.label);

  final String wire;
  final String label;
}

/// The brief decline report a declined Area needs before it ends.
class DeclineReport {
  const DeclineReport({required this.category, required this.narrative});

  final DeclineCategory category;
  final String narrative;
}

/// The four on-scene requests (PRD v13 §4.5.3, §4.7). On mobile every one
/// goes to the sender's own Admin.
enum FieldRequestType {
  water('Need water'),
  equipment('Need equipment'),
  backup('Need backup'),
  escalation('Alarm escalation');

  const FieldRequestType(this.label);

  final String label;
}

enum Urgency {
  low('Low'),
  medium('Medium'),
  high('High');

  const Urgency(this.label);

  final String label;
}

/// Who a Need backup asks for (PRD v13 §4.5.3).
enum BackupAgency {
  firefighter('Firefighter', 'Fire Volunteer and BFP Admins', 'fire_volunteer'),
  medical('Medical', 'Medical Admins', 'medical'),
  police('Police', 'PNP Pasay Admin', 'police'),
  barangayTanod('Barangay Tanod', 'Barangay Admins', 'barangay');

  const BackupAgency(this.label, this.recipients, this.agency);

  final String label;

  /// Whose Admins the request reaches.
  final String recipients;

  /// The agency_type its plate is drawn for.
  final String agency;
}

/// The alarm levels a Fire Volunteer may propose (PRD v13 §0.3, §19.3). The
/// sheet offers the levels above the current one; BFP alone sets it.
const List<String> kAlarmLevels = [
  '1st Alarm',
  '2nd Alarm',
  '3rd Alarm',
  '4th Alarm',
  '5th Alarm',
  'TF Alpha',
  'TF Bravo',
  'TF Charlie',
  'TF Delta',
  'TF Echo',
  'TF Hotel',
  'TF India',
  'General Alarm',
];

/// One request as the sheet hands it to its caller.
class FieldRequest {
  const FieldRequest.water({required this.amount, required this.urgency})
    : type = FieldRequestType.water,
      equipment = null,
      agency = null,
      level = null;

  const FieldRequest.equipment({required this.equipment, required this.urgency})
    : type = FieldRequestType.equipment,
      amount = null,
      agency = null,
      level = null;

  const FieldRequest.backup({required this.agency, required this.urgency})
    : type = FieldRequestType.backup,
      amount = null,
      equipment = null,
      level = null;

  const FieldRequest.escalation({required this.level})
    : type = FieldRequestType.escalation,
      amount = null,
      equipment = null,
      agency = null,
      urgency = null;

  final FieldRequestType type;

  /// Need water: the estimate as typed ("2,000 litres").
  final String? amount;

  /// Need equipment: what is needed, in the sender's words.
  final String? equipment;

  final BackupAgency? agency;

  /// Alarm escalation: one of [kAlarmLevels].
  final String? level;

  final Urgency? urgency;
}

/// A resident's answer to "Are you safe?" (PRD v13 §4.2). The wire values are
/// the PRD's additions to `neighborhood_response` (§6.2).
enum SafetyAnswer {
  safe('safe'),
  needHelp('need_help'),
  notInArea('not_in_area');

  const SafetyAnswer(this.wire);

  final String wire;
}

/// The Area's safety roll call (PRD v13 §4.2, CIAR Part III).
class SafetyRollCall {
  const SafetyRollCall({
    required this.safe,
    required this.needHelp,
    required this.notInArea,
  });

  final int safe;
  final int needHelp;
  final int notInArea;
}

/// Where the CIAR is (PRD v13 §4.8). There is no regenerate: it is immutable.
enum CiarState { generating, failed, ready }

/// Water levels move in 5 % steps from 0 to 100 (PRD v13 §4.9.6).
abstract final class WaterLevel {
  static const int step = 5;

  static bool isValid(int pct) => pct >= 0 && pct <= 100 && pct % step == 0;

  /// The nearest valid level.
  static int snap(num pct) => ((pct.clamp(0, 100) / step).round() * step);

  /// 0 % marks the source as not usable.
  static bool usable(int pct) => pct > 0;

  /// 5–25 % is low.
  static bool low(int pct) => pct > 0 && pct <= 25;
}
