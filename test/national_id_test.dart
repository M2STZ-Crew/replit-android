import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/notification_router.dart';
import 'package:replit/models/verification_state.dart';
import 'package:replit/screens/id_camera_screen.dart';
import 'package:replit/screens/national_id_screen.dart';
import 'package:replit/screens/verification_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/design.dart';

/// The real screen, with no stand-in for the camera.
Future<void> pumpIdScreenWithoutStandIn(
  WidgetTester tester,
  ApiClient Function(http.Response Function(http.BaseRequest)) api,
) async {
  tester.view.physicalSize = const Size(402, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: NationalIdScreen(api: api((_) => http.Response('{}', 200))),
    ),
  );
  await tester.pump();
}

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
        'On the back of the card. Tap to photograph it.',
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
      expect(
        sent.single.url.path,
        endsWith('/verification/national-id/manual'),
      );
      final body = bodies.single;
      for (final part in ['id_image', 'selfie_image', 'qr_image']) {
        expect(body, contains('name="$part"'));
      }
      expect(body, contains('name="philsys_consent"'));
    });

    testWidgets('says what PSA keeps and that the photos go', (tester) async {
      await pumpIdScreen(tester, api((_) => http.Response('{}', 200)));
      expect(
        find.textContaining('my first name and the result'),
        findsOneWidget,
      );
      expect(find.textContaining('deleted once the review'), findsOneWidget);
    });
  });

  group('the camera', () {
    // The Figma frames' phone: 402 × 874 under a 54 px status bar.
    const figma = Size(402, 874);
    const notch = EdgeInsets.only(top: 54, bottom: 34);

    Future<void> pumpCamera(
      WidgetTester tester,
      IdShot shot, {
      Size size = figma,
      EdgeInsets safe = notch,
      double scale = 1,
      AppPalette ground = AppPalette.dark,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(ground),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: size,
                padding: safe,
                textScaler: TextScaler.linear(scale),
              ),
              child: IdCameraScreen(
                shot: shot,
                preview: const ColoredBox(color: Colors.blueGrey),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    test('the guides are the design\'s, where the design put them', () {
      final card = IdShot.card.guideIn(figma, notch);
      expect(card.width, 330);
      expect(card.height, 208);
      expect(card.left, 36);
      expect(card.tlRadiusX, 16);
      expect(card.top, closeTo(300, 12));

      final face = IdShot.selfie.guideIn(figma, notch);
      expect(face.width, 240);
      expect(face.height, 300);
      expect(face.left, 81);
      expect(face.tlRadiusX, 120);
      expect(face.top, closeTo(250, 12));
    });

    test(
      'the guides shrink on a small phone and stay clear of the shutter',
      () {
        const small = Size(320, 568);
        for (final shot in IdShot.values) {
          final guide = shot.guideIn(small, EdgeInsets.zero);
          expect(guide.left, greaterThanOrEqualTo(36));
          expect(guide.right, lessThanOrEqualTo(small.width - 36));
          expect(guide.top, greaterThanOrEqualTo(116));
          expect(guide.bottom, lessThan(small.height - 164));
          expect(
            guide.width / guide.height,
            closeTo(shot.guide.aspectRatio, 0.01),
          );
        }
      },
    );

    for (final (shot, title, step) in [
      (IdShot.card, 'PHOTO OF YOUR ID', 'STEP 1 OF 3'),
      (IdShot.qr, 'PHOTO OF YOUR QR', 'STEP 2 OF 3'),
      (IdShot.selfie, 'LIVE SELFIE', 'STEP 3 OF 3'),
    ]) {
      testWidgets('$title says what to do and how to leave', (tester) async {
        await pumpCamera(tester, shot);
        expect(find.text(title), findsOneWidget);
        expect(find.text(step), findsOneWidget);
        expect(find.text(shot.hint), findsOneWidget);
        expect(find.textContaining('Camera only'), findsOneWidget);
        expect(find.bySemanticsLabel('Close camera'), findsOneWidget);
        expect(find.bySemanticsLabel('Take the photo'), findsOneWidget);
      });
    }

    testWidgets('nothing overflows on a small phone at large text', (
      tester,
    ) async {
      for (final shot in IdShot.values) {
        await pumpCamera(
          tester,
          shot,
          size: const Size(360, 640),
          safe: const EdgeInsets.only(top: 24),
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('stays dark on the light ground', (tester) async {
      await pumpCamera(tester, IdShot.card, ground: AppPalette.light);
      final title = tester.widget<Text>(find.text('PHOTO OF YOUR ID'));
      expect(title.style?.color, AppPalette.dark.onBackground);
    });

    testWidgets('a phone with no camera plugin says so, and can be closed', (
      tester,
    ) async {
      await pumpIdScreenWithoutStandIn(tester, api);
      await tester.tap(find.text('Tap to take a selfie'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Its spinner never settles, so wait out the failing plugin call itself.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(find.text('LIVE SELFIE'), findsOneWidget);
      expect(find.textContaining('could not start'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close camera'));
      await tester.pumpAndSettle();
      expect(find.text('LIVE SELFIE'), findsNothing);
      expect(find.text('Tap to take a selfie'), findsOneWidget);
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
              return http.Response(
                jsonEncode({'email': 'r@example.test'}),
                200,
              );
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
