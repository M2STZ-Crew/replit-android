/// What a coordinator may do, as the server decides it — the app only
/// mirrors it, so it never offers what the server would refuse.
///
/// PRD v14 §4.6: there is no Observer tier any more. Every organisation's
/// Coordinators (Fire Volunteer Captain, BFP Chief, Medical Lead, Police
/// Chief, Kagawad) work from the coordinator app (06 · C01P: a PNP
/// Coordinator's queue). What each may do still comes from the server:
///
/// - **Every coordinator** acknowledges (Accept) the Areas that asked for its
///   agency, decides overlaps, follows Areas on LIVE and the map, makes its
///   team's Responder accounts and reports a fire.
/// - **Fire Volunteer and BFP coordinators** also reject, go to the scene,
///   mark fire out, press fire codes and file the Post-Incident Report
///   (app/services/incident.py: `is_coordinator`, `can_respond`,
///   `assert_team_captain`; fire_codes.py) and ask BFP to raise the alarm
///   (alarm_requests.py `_may_request`).
/// - **BFP** sets the alarm level; **Fire Volunteer** updates water levels.
///
/// Widening what Police, Medical and Barangay coordinators may do is a
/// server change first; this follows it.
class CoordinatorPowers {
  const CoordinatorPowers._(this.agency);

  factory CoordinatorPowers.of(Map<String, dynamic>? me) =>
      CoordinatorPowers._(me?['agency_type'] as String?);

  /// The agencies whose coordinators run the response (the server's
  /// COORDINATING_AGENCIES).
  static const Set<String> coordinatingAgencies = {'fire_volunteer', 'bfp'};

  final String? agency;

  /// Reject, fire out, dispatch: changing an Area's state.
  bool get coordinates => coordinatingAgencies.contains(agency);

  /// Go to the scene ("I am going"), then Mark arrived and the route.
  bool get responds => coordinates;

  /// Reject an Area that is clearly not a fire.
  bool get rejects => coordinates;

  /// Mark fire out.
  bool get marksFireOut => coordinates;

  /// Press fire codes on an incident.
  bool get pressesCodes => coordinates;

  /// File the Post-Incident Report for the team.
  bool get files => coordinates;

  /// Ask BFP to raise the alarm.
  bool get requestsAlarm => coordinates;

  /// Set the alarm level from those requests.
  bool get decidesAlarm => agency == 'bfp';

  /// Change a water resource's level.
  bool get updatesWater => agency == 'fire_volunteer';
}
