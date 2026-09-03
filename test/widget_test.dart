import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit_mobile/core/constants/app_constants.dart';
import 'package:replit_mobile/core/errors/app_exception.dart';
import 'package:replit_mobile/core/network/api_client.dart';
import 'package:replit_mobile/features/auth/domain/entities/app_user.dart';
import 'package:replit_mobile/main.dart';

/// Hermetic tests — no Supabase, no network, no .env required.
void main() {
  group('domain constants match the backend enums', () {
    test('every area_status value is represented', () {
      expect(IncidentStatus.all, hasLength(8));
      expect(
        IncidentStatus.all,
        containsAll(<String>['pending', 'verified', 'dispatched', 'en_route',
            'arrived', 'resolved', 'rejected', 'merged']),
      );
    });

    test('terminal statuses leave the live feed', () {
      expect(IncidentStatus.isActive(IncidentStatus.pending), isTrue);
      expect(IncidentStatus.isActive(IncidentStatus.arrived), isTrue);
      for (final status in IncidentStatus.terminal) {
        expect(IncidentStatus.isActive(status), isFalse, reason: status);
      }
    });

    test('roles use the backend names, not citizen/responder', () {
      expect(UserRole.all, containsAll(<String>['admin', 'sub_admin',
          'response_team', 'general_user']));
      expect(UserRole.isStaff(UserRole.subAdmin), isTrue);
      expect(UserRole.isStaff(UserRole.admin), isTrue);
      expect(UserRole.isStaff(UserRole.generalUser), isFalse);
      expect(UserRole.isStaff(UserRole.responseTeam), isFalse);
    });

    test('verification weights total 100 percent', () {
      const total = VerificationBadge.phonePercent +
          VerificationBadge.nationalIdPercent +
          VerificationBadge.emailPercent;
      expect(total, 100);
    });
  });

  group('AppUser.fromMap', () {
    test('accepts a user with no email or name', () {
      // public.users allows both to be null — a phone-registered citizen has
      // neither. Reading them as non-null used to throw here.
      final user = AppUser.fromMap({
        'id': 'a1b2',
        'role': 'general_user',
        'email': null,
        'full_name': null,
        'phone': '+639171234567',
        'created_at': '2026-09-01T10:00:00Z',
      });

      expect(user.id, 'a1b2');
      expect(user.isGeneralUser, isTrue);
      expect(user.displayName, '+639171234567');
      expect(user.verifiedPercent, 0);
      expect(user.badge, VerificationBadge.yellow);
    });

    test('reads the verification snapshot', () {
      final user = AppUser.fromMap({
        'id': 'c3d4',
        'role': 'sub_admin',
        'agency_type': 'fire_volunteer',
        'full_name': 'J. Marcella',
        'verified_percent': 90,
        'badge': 'green',
        'phone_verified': true,
        'id_verified': true,
      });

      expect(user.displayName, 'J. Marcella');
      expect(user.isStaff, isTrue);
      expect(user.verifiedPercent, 90);
      expect(user.canVerifyPhone, isFalse);
      expect(user.canVerifyId, isFalse);
    });
  });

  group('ApiClient.toException', () {
    Response<dynamic> res(int status, [Object? data]) => Response<dynamic>(
          requestOptions: RequestOptions(path: '/reports/submit'),
          statusCode: status,
          data: data,
        );

    test('surfaces the backend message rather than a status code', () {
      final error = ApiClient.toException(
        Exception('ignored'),
        res(400, {
          'error': 'bad_request',
          'message': 'Photo exceeds the 5 MB limit.',
          'request_id': 'abc123',
        }),
      );

      expect(error, isA<ValidationException>());
      expect(error.message, 'Photo exceeds the 5 MB limit.');
    });

    test('401 becomes an auth error', () {
      final error = ApiClient.toException(
        Exception('ignored'),
        res(401, {'error': 'unauthorized', 'message': 'Session expired.'}),
      );
      expect(error, isA<AuthException>());
    });

    test('reads the stable error code', () {
      expect(
        ApiClient.errorCodeOf(res(403, {'error': 'forbidden', 'message': 'No.'})),
        'forbidden',
      );
    });

    test('an unreachable backend reads as a network problem', () {
      final error = ApiClient.toException(
        DioException(
          requestOptions: RequestOptions(path: '/health'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(error, isA<NetworkException>());
    });
  });

  testWidgets('a failed startup explains itself instead of crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RepLiTApp(startupError: 'Missing in .env: SUPABASE_URL'),
      ),
    );

    expect(find.textContaining("couldn't start"), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
