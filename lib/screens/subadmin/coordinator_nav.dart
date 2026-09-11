import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import 'post_incident_report_screen.dart';
import 'subadmin_incident_command_screen.dart';
import 'subadmin_incident_report_screen.dart';

/// Where a coordinator — a Fire Volunteer or BFP team captain — goes for an
/// incident (Master Context v10 §2.6.1: both coordinate; only Fire Volunteer
/// verifies, which the review screen enforces):
///
///  * live response (dispatched, en route, on scene) → the command screen;
///  * fire out with the report still owed → the Post-Incident Report;
///  * before the response (pending, verified) → the review screen, where the
///    reports are and where verify / reject / dispatch / fire out are.
///
/// Shared by both captains' dashboards and the "routed to your team" push, so a
/// BFP captain lands in the same place a Fire Volunteer captain does. Returns
/// true if anything changed, so the caller can reload.
Future<bool> openCoordinatorIncident(
  BuildContext context, {
  required Map<String, dynamic> incident,
  required Map<String, dynamic> me,
  required ApiClient api,
}) async {
  final status = (incident['status'] as String?) ?? 'pending';
  final areaId = incident['id'] as String;
  final navigator = Navigator.of(context);

  if (const {'dispatched', 'en_route', 'arrived'}.contains(status)) {
    return await navigator.push<bool>(MaterialPageRoute(
          builder: (_) => SubAdminIncidentCommandScreen(areaId: areaId, me: me, api: api),
        )) ==
        true;
  }
  if (status == 'post_incident_report') {
    return await navigator.push<bool>(MaterialPageRoute(
          builder: (_) => PostIncidentReportScreen(
            areaId: areaId,
            designation: incident['designation'] as String?,
            api: api,
          ),
        )) ==
        true;
  }

  List<dynamic> reports;
  try {
    reports = await api.getIncidentReports(areaId);
  } catch (_) {
    reports = const [];
  }
  if (!context.mounted) return false;
  if (reports.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No reports to review yet.')),
    );
    return false;
  }
  return await navigator.push<bool>(MaterialPageRoute(
        builder: (_) => SubAdminIncidentReportScreen(
          report: (reports.first as Map).cast<String, dynamic>(),
          areaId: areaId,
          status: status,
          agency: me['agency_type'] as String?,
          me: me,
          api: api,
        ),
      )) ==
      true;
}
