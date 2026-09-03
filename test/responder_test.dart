import 'package:flutter_test/flutter_test.dart';

import 'package:replit_mobile/core/constants/app_constants.dart';
import 'package:replit_mobile/features/responder/domain/entities/responder_incident.dart';

ResponderIncident incident(String status, {int dispatches = 0}) =>
    ResponderIncident.fromMap({
      'id': 'i1',
      'designation': 'Area 3',
      'status': status,
      'centroid_lat': 14.5378,
      'centroid_lng': 121.0014,
      'report_count': 2,
      'confidence_score': 0.42,
      'confidence_band': 'medium',
      'active_dispatch_count': dispatches,
    });

void main() {
  group('the responder can only take the next legal step', () {
    // Mirrors ALLOWED_TRANSITIONS on the server: verified -> dispatched ->
    // en_route -> arrived. Offering a step the API refuses would be our bug.
    test('a verified incident is available to accept', () {
      final i = incident(IncidentStatus.verified);
      expect(i.isAvailable, isTrue);
      expect(i.nextAction, 'accept');
    });

    test('a dispatched incident moves to en route', () {
      expect(incident(IncidentStatus.dispatched).nextAction, 'en_route');
    });

    test('an en-route incident moves to arrived', () {
      expect(incident(IncidentStatus.enRoute).nextAction, 'arrived');
    });

    test('nothing is offered once arrived or closed', () {
      for (final status in [
        IncidentStatus.arrived,
        IncidentStatus.resolved,
        IncidentStatus.rejected,
        IncidentStatus.merged,
        IncidentStatus.pending,
      ]) {
        expect(incident(status).nextAction, isNull, reason: status);
      }
    });

    test('pending is never available — it is not verified yet', () {
      expect(incident(IncidentStatus.pending).isAvailable, isFalse);
    });

    test('isUnderway covers exactly the active response window', () {
      expect(incident(IncidentStatus.dispatched).isUnderway, isTrue);
      expect(incident(IncidentStatus.enRoute).isUnderway, isTrue);
      expect(incident(IncidentStatus.arrived).isUnderway, isTrue);
      expect(incident(IncidentStatus.verified).isUnderway, isFalse);
      expect(incident(IncidentStatus.resolved).isUnderway, isFalse);
    });
  });

  group('FireCode.pressableBy', () {
    const responderCode = FireCode(
      id: 'c1',
      codeNumber: 'FC-6',
      name: 'Water Supply Needed',
      targetRole: 'response_team',
    );
    const subAdminCode = FireCode(
      id: 'c2',
      codeNumber: 'FC-9',
      name: 'Coordinator only',
      targetRole: 'sub_admin',
    );

    test('a response team member may press their own code', () {
      expect(responderCode.pressableBy('response_team', 'fire_volunteer'), isTrue);
    });

    test('a response team member may NOT press a coordinator code', () {
      // The server returns 403; the button must be disabled rather than fail.
      expect(subAdminCode.pressableBy('response_team', 'fire_volunteer'), isFalse);
    });

    test('coordinators may broadcast any code', () {
      for (final role in ['admin', 'sub_admin']) {
        expect(responderCode.pressableBy(role, 'fire_volunteer'), isTrue);
        expect(subAdminCode.pressableBy(role, 'fire_volunteer'), isTrue);
      }
    });

    test('an agency-scoped code is refused to the wrong agency', () {
      const bfpOnly = FireCode(
        id: 'c3',
        codeNumber: 'FC-X',
        name: 'BFP only',
        targetRole: 'response_team',
        targetAgency: 'bfp',
      );
      expect(bfpOnly.pressableBy('response_team', 'bfp'), isTrue);
      expect(bfpOnly.pressableBy('response_team', 'fire_volunteer'), isFalse);
    });

    test('an inactive code is never pressable, even by an admin', () {
      const retired = FireCode(
        id: 'c4',
        codeNumber: 'FC-0',
        name: 'Retired',
        targetRole: 'response_team',
        isActive: false,
      );
      expect(retired.pressableBy('admin', null), isFalse);
    });
  });

  group('GPS broadcast cadence', () {
    test('matches the 5-second interval in Section 2.4', () {
      expect(AppConstants.responderGpsInterval, const Duration(seconds: 5));
    });
  });
}
