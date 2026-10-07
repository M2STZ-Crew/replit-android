import 'package:flutter/material.dart';

import '../screens/bfp/bfp_alarm_requests_screen.dart';
import '../screens/live_update_screen.dart';
import '../screens/neighbour_alert_screen.dart';
import '../screens/responder/responder_incident_screen.dart';
import '../screens/subadmin/coordinator_nav.dart';
import 'api_client.dart';

/// Where a notification leads (v1.12.6).
///
/// One answer for all three ways a notification is opened: tapped in the
/// phone's notification shade (app closed or in the background), the banner
/// shown while the app is open, and a row in the Alerts list behind the bell.
enum NotificationTarget {
  /// "Do you see it too?" — a resident near a reported fire.
  nearbyFire,

  /// The live tracker of the resident's own report.
  myReport,

  /// The incident itself, where staff verify and respond.
  staffIncident,

  /// BFP's queue of alarm escalation requests.
  alarmRequests,

  /// Nothing to open: a test push, or a phone whose work is on the web.
  none,
}

/// Notification types that say there is a fire. They ring the fire alarm when
/// they arrive with the app open; with it closed the server sends them to the
/// "Fire alerts" channel, which rings the same sound.
const fireAlertTypes = {
  'incident_new',
  'neighborhood_alert',
  'fire_alert',
  'alarm_request',
};

/// Whoever works incidents in this app: every responder, and Fire Volunteer
/// and BFP coordinators. Police, medical and barangay coordinators work from
/// the Observer Console on the web.
bool worksIncidentsInApp(Map<String, dynamic>? me) {
  final role = me?['role'];
  if (role == 'response_team') return true;
  return role == 'sub_admin' &&
      const {'fire_volunteer', 'bfp'}.contains(me?['agency_type']);
}

/// Where a notification of [type] leads for the signed-in account [me].
NotificationTarget targetFor(String? type, Map<String, dynamic>? me) {
  final staff = worksIncidentsInApp(me);
  switch (type) {
    // A new fire, and the v10 types a phone may still hold in its Alerts.
    case 'incident_new':
    case 'responder_dispatch':
    case 'incident_routed':
    case 'alarm_executed':
      return staff ? NotificationTarget.staffIncident : NotificationTarget.none;
    case 'alarm_request':
      final bfp = me?['role'] == 'sub_admin' && me?['agency_type'] == 'bfp';
      if (bfp) return NotificationTarget.alarmRequests;
      return staff ? NotificationTarget.staffIncident : NotificationTarget.none;
    // A fire near you: a resident is asked whether they see it; staff, who
    // can act on it, go to the incident.
    case 'neighborhood_alert':
    case 'fire_alert':
      return staff
          ? NotificationTarget.staffIncident
          : NotificationTarget.nearbyFire;
    // News about a report the resident made.
    case 'incident_update':
      return staff
          ? NotificationTarget.staffIncident
          : NotificationTarget.myReport;
    default:
      return NotificationTarget.none;
  }
}

/// Whether a notification has anything to open, before knowing who is asking:
/// it names an incident, or it is an alarm request.
bool canOpen(String? type, Map<String, dynamic>? data) =>
    data?['area_id'] is String || type == 'alarm_request';

/// Opens what a notification is about.
class NotificationRouter {
  NotificationRouter({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Open the screen for a notification of [type] carrying [data]. Returns
  /// false when there is nothing to open for this account, or it could not be
  /// loaded — never throws: a notification that will not open must not crash
  /// the app it was meant to bring someone into.
  Future<bool> open(
    NavigatorState nav, {
    required String? type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final me = await _api.getMe();
      final target = targetFor(type, me);
      final areaId = data['area_id'] as String?;
      if (target == NotificationTarget.none) return false;
      if (target != NotificationTarget.alarmRequests && areaId == null) {
        return false;
      }
      switch (target) {
        case NotificationTarget.nearbyFire:
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) => NeighbourAlertScreen(areaId: areaId!),
            ),
          );
        case NotificationTarget.myReport:
          final area = await _api.getArea(areaId!);
          final lat = (area['centroid_lat'] as num?)?.toDouble();
          final lng = (area['centroid_lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return false;
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  LiveUpdateScreen(areaId: areaId, lat: lat, lng: lng),
            ),
          );
        case NotificationTarget.staffIncident:
          return await _openStaffIncident(nav, areaId!, me);
        case NotificationTarget.alarmRequests:
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) => const BfpAlarmRequestsScreen(),
            ),
          );
        case NotificationTarget.none:
          return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A responder lands on the incident, where Verify, Respond, En route and
  /// Arrived are; a coordinator where their dashboard would send them for its
  /// current state (review, command, or the report owed).
  Future<bool> _openStaffIncident(
    NavigatorState nav,
    String areaId,
    Map<String, dynamic> me,
  ) async {
    if (me['role'] == 'response_team') {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ResponderIncidentScreen(
            incidentId: areaId,
            myId: me['id'] as String? ?? '',
            agency: me['agency_type'] as String?,
            orgId: me['primary_org_id'] as String?,
          ),
        ),
      );
      return true;
    }
    final incident = await _api.getIncident(areaId);
    if (!nav.mounted) return false;
    await openCoordinatorIncident(
      nav.context,
      incident: incident,
      me: me,
      api: _api,
    );
    return true;
  }
}
