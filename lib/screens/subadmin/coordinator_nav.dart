import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/coordinator_powers.dart';
import 'post_incident_report_screen.dart';
import '../coordinator/area_decision_screen.dart';
import '../coordinator/coordinator_shell.dart';
import '../coordinator/live_incident.dart';

/// Where a coordinator goes for an incident (Master Context v12 §2.5):
///
///  * live response (on the way, on scene) → LIVE: the coordinator shell's
///    tab when it is showing, else the same view on its own screen;
///  * fire out with the report still owed → the Post-Incident Report, for a
///    coordinator who files one (Fire Volunteer, BFP);
///  * anything else (reported, verified, ended) → the Area and its decision.
///
/// Shared by the queue, the map and the "routed to your team" push, so a BFP
/// captain lands in the same place a Fire Volunteer captain does. Returns
/// true if anything changed, so the caller can reload.
Future<bool> openCoordinatorIncident(
  BuildContext context, {
  required Map<String, dynamic> incident,
  required Map<String, dynamic> me,
  required ApiClient api,
}) async {
  final status = (incident['status'] as String?) ?? 'reported';
  final areaId = incident['id'] as String;
  final navigator = Navigator.of(context);

  if (const {'en_route', 'arrived'}.contains(status)) {
    if (CoordinatorShell.showLive(navigator, areaId)) return false;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => LiveIncidentScreen(areaId: areaId, me: me, api: api),
      ),
    );
    return true;
  }
  if (const {'fire_out', 'post_incident_report'}.contains(status) &&
      CoordinatorPowers.of(me).files) {
    return await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => PostIncidentReportScreen(
              areaId: areaId,
              designation: incident['designation'] as String?,
              api: api,
            ),
          ),
        ) ==
        true;
  }
  return await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => AreaDecisionScreen(
            areaId: areaId,
            me: me,
            api: api,
            onLive: (id) => CoordinatorShell.showLive(navigator, id),
          ),
        ),
      ) ==
      true;
}
