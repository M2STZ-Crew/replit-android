/// Which fire codes a responder may press on a fire (v1.12.59, backend
/// v1.12.48; 22 Nov 2026, answered "Coordinators declare"): the server's rule
/// (app/services/fire_code_rules.py), mirrored so the app never offers what
/// the server would refuse.
///
/// - Only on a fire they are on: an active response.
/// - Fire Volunteer and BFP crews: every code.
/// - Other agencies' crews: only FC-7 (more units) and FC-8 (a casualty).
/// - Fire out ends every response, so Overhauling (FC-4) and Returning to
///   station (FC-5) are also open to a fire crew whose response it completed.
///
/// Coordinators are not decided here: Fire Volunteer and BFP ones press every
/// code (CoordinatorPowers.pressesCodes).
library;

/// What any agency's crew may ask for: more units, a casualty.
const Set<String> kCallForHelpCodes = {'FC-7', 'FC-8'};

/// What a crew still reports once the fire is out.
const Set<String> kAfterFireCodes = {'FC-4', 'FC-5'};

bool responderMayPress(
  String? code, {
  required bool fireCrew,
  required bool going,
  required bool finished,
}) {
  if (code == null) return false;
  if (!fireCrew && !kCallForHelpCodes.contains(code)) return false;
  return going || (finished && kAfterFireCodes.contains(code));
}
