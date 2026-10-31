import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/models/verification_state.dart';
import 'package:replit/screens/national_id_screen.dart';
import 'package:replit/screens/verification_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

/// National ID: three live photos and the holder's consent, for an
/// administrator's PhilSys Check, and the answer coming back to the resident.
void main() {
  // A one-pixel PNG: enough for Image.memory to draw something.
  final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  late List<http.BaseRequest> sent;
  late List<String> bodies;

  setUp(() {
    sent = [];
    bodies = [];
  });

  ApiClient api(http.Response Function(http.BaseRequest) server) => ApiClient(
    client: MockClient((req) async {
      sent.add(req);
      bodies.add(latin1.decode(req.bodyBytes));
      return server(req);
    }),
  );

  Future<void> pumpIdScreen(WidgetTester tester, ApiClient client) async {
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: NationalIdScreen(
          api: client,
          camera: () async => Uint8List.fromList(photo),
        ),
      ),
    );
    await tester.pump();
  }

  Finder submit() => find.byType(AppButton);

  bool enabled(WidgetTester tester) =>
      tester.widget<AppButton>(submit()).onPressed != null;

  group('the National ID screen', () {
    testWidgets('asks for the PhilSys ID, not any government ID', (
      tester,
    ) async {
      await pumpIdScreen(tester, api((_) => http.Response('{}', 200)));
      expect(find.textContaining('PhilID card or ePhilID'), findsOneWidget);
      expect(find.textContaining('government ID'), findsNothing);
      expect(find.text('QR CODE'), findsOneWidget);
    });

    testWidgets('submits only with all three photos and the consent', (
      tester,
    ) async {
      await pumpIdScreen(
        tester,
        api(
          (_) => http.Response(
            jsonEncode({
              'verified': false,
              'verified_percent': 10,
              'badge': 'yellow',
            }),
            200,
          ),
        ),
      );
      expect(enabled(tester), isFalse);

      for (final slot in [
        'Tap to photograph the side with your picture',
        'On the back of the card. Fill the photo with it.',
        'Tap to take a selfie',
      ]) {
        await tester.tap(find.text(slot));
        await tester.pump();
      }
      expect(enabled(tester), isFalse, reason: 'no consent yet');

      await tester.tap(find.textContaining('I agree to an administrator'));
      await tester.pump();
      expect(enabled(tester), isTrue);

      await tester.tap(submit());
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single.url.path, endsWith('/verification/national-id/manual'));
      final body = bodies.single;
      for (final part in ['id_image', 'selfie_image', 'qr_image']) {
        expect(body, contains('name="$part"'));
      }
      expect(body, contains('name="philsys_consent"'));
    });

    testWidgets('says what PSA keeps and that the photos go', (tester) async {
      await pumpIdScreen(tester, api((_) => http.Response('{}', 200)));
      expect(find.textContaining('my first name and the result'), findsOneWidget);
      expect(find.textContaining('deleted once the review'), findsOneWidget);
    });
  });

  group('the answer', () {
    Map<String, dynamic> status(String state, [String? notes]) => {
      'verified_percent': 10,
      'badge': 'yellow',
      'channels': [
        {
          'type': 'national_id',
          'status': state,
          'percent_awarded': 0,
          'review_notes': notes,
        },
      ],
    };

    test('a refused ID carries the reviewer\'s reason', () {
      final s = VerificationState.fromJson(
        status('rejected', 'Take the QR photo again.'),
      );
      expect(
        s.refusalReason(VerifyChannel.nationalId),
        'Take the QR photo again.',
      );
    });

    test('an ID under review has no reason to show', () {
      final s = VerificationState.fromJson(status('manual_review', 'Old note'));
      expect(s.refusalReason(VerifyChannel.nationalId), isNull);
    });

    testWidgets('the resident reads why it came back', (tester) async {
      tester.view.physicalSize = const Size(402, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: VerificationScreen(
            api: api((req) {
              if (req.url.path.endsWith('/verification/status')) {
                return http.Response(
                  jsonEncode(status('rejected', 'Take the QR photo again.')),
                  200,
                );
              }
              return http.Response(jsonEncode({'email': 'r@example.test'}), 200);
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Take the QR photo again.'), findsOneWidget);
    });

    test('the notification opens the verification screen, for anyone', () {
      expect(
        targetFor('national_id_reviewed', const {'role': 'general_user'}),
        NotificationTarget.verification,
      );
      expect(canOpen('national_id_reviewed', const {}), isTrue);
    });
  });
}
