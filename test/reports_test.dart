import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:replit_mobile/core/constants/app_constants.dart';
import 'package:replit_mobile/features/reports/domain/entities/report.dart';
import 'package:replit_mobile/features/reports/presentation/providers/sos_provider.dart';

Position _fix({double accuracy = 12}) => Position(
      latitude: 14.5378,
      longitude: 121.0014,
      timestamp: DateTime.utc(2026, 9, 2),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 90,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('SosState.canSubmit', () {
    test('a fresh state cannot submit', () {
      expect(const SosState().canSubmit, isFalse);
    });

    test('needs a photo as well as a location', () {
      final located = SosState(stage: SosStage.ready, position: _fix());
      expect(located.canSubmit, isFalse, reason: 'photo is mandatory');
    });

    test('needs at least one agency selected', () {
      final noAgency = SosState(
        stage: SosStage.ready,
        position: _fix(),
        photo: File('fire.jpg'),
        agencies: const {},
      );
      expect(noAgency.canSubmit, isFalse);
    });

    test('is satisfied by location + photo + agency', () {
      final ready = SosState(
        stage: SosStage.ready,
        position: _fix(),
        photo: File('fire.jpg'),
      );
      expect(ready.canSubmit, isTrue);
    });

    test('cannot double-submit while an upload is in flight', () {
      final sending = SosState(
        stage: SosStage.submitting,
        position: _fix(),
        photo: File('fire.jpg'),
      );
      expect(sending.isBusy, isTrue);
      expect(sending.canSubmit, isFalse);
    });

    test('defaults to alerting Fire Volunteers', () {
      expect(const SosState().agencies, {AgencyType.fireVolunteer});
    });
  });

  group('SosState.copyWith', () {
    test('clearError wipes the message so a retry starts clean', () {
      const failed = SosState(
        stage: SosStage.failed,
        errorMessage: 'No GPS fix.',
      );
      expect(failed.copyWith(clearError: true).errorMessage, isNull);
    });

    test('an unrelated update keeps the existing error visible', () {
      const failed = SosState(errorMessage: 'No GPS fix.');
      expect(failed.copyWith(notes: 'third floor').errorMessage, 'No GPS fix.');
    });
  });

  group('ReportSubmission.fromMap', () {
    test('reads the clustering outcome', () {
      final submission = ReportSubmission.fromMap({
        'id': 'r1',
        'area_id': 'a1',
        'area_designation': 'Area 7.2',
        'has_exif': true,
        'gps_discrepancy_flag': false,
        'gps_discrepancy_m': 12.4,
        'message': 'Device and EXIF GPS agree.',
        'created_at': '2026-09-02T08:15:00Z',
      });

      expect(submission.areaDesignation, 'Area 7.2');
      expect(submission.gpsDiscrepancyFlag, isFalse);
      expect(submission.createdAt, isNotNull);
    });

    test('survives a response with the optional fields absent', () {
      final submission = ReportSubmission.fromMap({
        'id': 'r2',
        'area_id': 'a2',
        'has_exif': false,
        'gps_discrepancy_flag': true,
      });

      expect(submission.gpsDiscrepancyM, isNull);
      expect(submission.areaDesignation, 'Area');
      expect(submission.message, isNotEmpty);
    });
  });

  group('MyReport.fromMap', () {
    test('labels the selected agencies for display', () {
      final report = MyReport.fromMap({
        'id': 'r3',
        'device_lat': 14.5378,
        'device_lng': 121.0014,
        'has_exif': true,
        'gps_discrepancy_flag': false,
        'user_verified_percent': 40,
        'selected_agencies': ['fire_volunteer', 'medical'],
        'created_at': '2026-09-02T08:15:00Z',
      });

      expect(report.agenciesLabel, 'Fire Volunteers, Medical');
      expect(report.userVerifiedPercent, 40);
    });

    test('carries the clustered incident status for the progress view', () {
      final report = MyReport.fromMap({
        'id': 'r5',
        'device_lat': 14.5378,
        'device_lng': 121.0014,
        'has_exif': true,
        'gps_discrepancy_flag': false,
        'user_verified_percent': 40,
        'area_id': 'a5',
        'area_designation': 'Area 3',
        'area_status': 'en_route',
        'area_confidence_band': 'medium',
      });

      expect(report.areaDesignation, 'Area 3');
      expect(report.statusLabel, 'Responders en route');
      expect(report.isActive, isTrue);
    });

    test('a resolved incident is no longer active', () {
      final report = MyReport.fromMap({
        'id': 'r6',
        'device_lat': 14.5,
        'device_lng': 121.0,
        'has_exif': false,
        'gps_discrepancy_flag': false,
        'user_verified_percent': 0,
        'area_status': 'resolved',
      });

      expect(report.isActive, isFalse);
      expect(report.statusLabel, 'Resolved');
    });

    test('an unclustered report still shows something sensible', () {
      // area_* are null in the window between insert and clustering.
      final report = MyReport.fromMap({
        'id': 'r7',
        'device_lat': 14.5,
        'device_lng': 121.0,
        'has_exif': false,
        'gps_discrepancy_flag': false,
        'user_verified_percent': 0,
      });

      expect(report.areaStatus, isNull);
      expect(report.statusLabel, 'Received');
      expect(report.isActive, isTrue, reason: 'not yet closed');
    });

    test('an unsigned photo URL is tolerated, not fatal', () {
      // The backend returns null when a storage object cannot be signed, rather
      // than failing the whole listing.
      final report = MyReport.fromMap({
        'id': 'r4',
        'device_lat': 14.5,
        'device_lng': 121.0,
        'has_exif': false,
        'gps_discrepancy_flag': false,
        'user_verified_percent': 0,
        'photo_url': null,
      });

      expect(report.photoUrl, isNull);
      expect(report.agenciesLabel, 'No agency selected');
    });
  });
}
