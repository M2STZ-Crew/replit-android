import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/models/verification_state.dart';
import 'package:replit/screens/profile_screen.dart';
import 'package:replit/screens/verification_screen.dart';
import 'package:replit/theme.dart';

/// "15 Profile" and "16 Verification": every channel says where it really
/// stands, and no setting is shown that does nothing.
void main() {
  ApiClient api({String idStatus = '', String emailStatus = 'verified'}) =>
      ApiClient(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/verification/status')) {
            return http.Response(
              jsonEncode({
                'verified_percent': emailStatus == 'verified' ? 60 : 50,
                'badge': 'light_green',
                'channels': [
                  if (idStatus.isNotEmpty)
                    {'type': 'national_id', 'status': idStatus},
                  {'type': 'email', 'status': emailStatus},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'u1',
              'email': 'm.reyes@gmail.com',
              'full_name': 'Maria Antonette Reyes',
              'role': 'general_user',
              'verified_percent': 60,
              'badge': 'light_green',
              'mobile': null,
            }),
            200,
          );
        }),
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('profile', () {
    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('reads the account, at ${scale}x', (tester) async {
        await pump(tester, ProfileScreen(api: api()), scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('YOUR PROFILE'), findsOneWidget);
        expect(find.text('MARIA ANTONETTE REYES'), findsOneWidget);
        expect(find.text('60% VERIFIED'), findsOneWidget);
        expect(find.text('Add your National ID for +50%'), findsOneWidget);
        expect(find.text('VERIFIED'), findsOneWidget, reason: 'the email');
        expect(find.text('Not added yet'), findsOneWidget);
        expect(find.text('ADD'), findsOneWidget);
        expect(find.text('Barangay alerts'), findsOneWidget);
        // Switches with nothing behind them are not drawn (§2.7.1).
        expect(find.text('Share location always'), findsNothing);
        expect(find.text('Language'), findsNothing);
      });
    }

    testWidgets('an ID in review is not asked for again', (tester) async {
      await pump(tester, ProfileScreen(api: api(idStatus: 'manual_review')));
      expect(find.text('Add your National ID for +50%'), findsNothing);
      expect(find.text('Your National ID is being checked'), findsOneWidget);
    });
  });

  group('verification', () {
    for (final scale in <double>[1.0, 1.5]) {
      testWidgets('each channel says where it stands, at ${scale}x', (
        tester,
      ) async {
        await pump(
          tester,
          VerificationScreen(api: api(idStatus: 'manual_review')),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('VERIFY YOUR ACCOUNT'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);
        expect(find.text('LIGHT GREEN'), findsOneWidget);
        expect(
          find.text('Unavailable while we change SMS provider'),
          findsOneWidget,
          reason: 'phone verification is paused (§10.3)',
        );
        expect(
          find.text('Submitted — an administrator is checking it'),
          findsOneWidget,
        );
        // Below the fold at a large font scale.
        await tester.scrollUntilVisible(
          find.text('UNDER 50'),
          200,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text('m.reyes@gmail.com'), findsOneWidget);
        expect(find.text('UNDER 50'), findsOneWidget);
      });
    }

    testWidgets('a refused ID can be taken again', (tester) async {
      await pump(tester, VerificationScreen(api: api(idStatus: 'rejected')));
      expect(find.text('Not accepted — take the photos again'), findsOneWidget);
    });

    test('the paused phone channel is never the next step', () {
      final s = VerificationState.fromJson({
        'verified_percent': 60,
        'badge': 'light_green',
        'channels': [
          {'type': 'national_id', 'status': 'verified'},
          {'type': 'email', 'status': 'verified'},
        ],
      });
      expect(kPhoneVerificationOpen, isFalse);
      expect(s.nextStep, isNull);
    });
  });
}
