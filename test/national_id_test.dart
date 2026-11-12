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

/// National ID, as the Figma frames take it (12 November 2026: "the national
/// id verification screen (based on figma) is not consistent in the system
/// itself so fix it based on figma"): 16 Start, the three photos (20, 20C,
/// 20B), 20D Check your photos, 21 Sent for review. Then the answer coming
/// back to the resident.
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

  /// The photos asked of the camera stand-in, in order.
  late List<IdShot> asked;

  /// Opens the screen with a camera that answers [answer] for each photo
  /// (null: closed without one).
  Future<void> pumpIdScreen(
    WidgetTester tester,
    ApiClient client, {
    Uint8List? Function(IdShot shot)? answer,
    int? percent,
  }) async {
    asked = [];
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: NationalIdScreen(
          api: client,
          percent: percent,
          camera: (shot) async {
            asked.add(shot);
            return answer == null ? Uint8List.fromList(photo) : answer(shot);
          },
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    // Each photo is a round trip to the camera stand-in.
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  http.Response ok(http.BaseRequest _) => http.Response(
    jsonEncode({'verified': false, 'verified_percent': 50, 'badge': 'yellow'}),
    200,
  );

  group('the National ID screen', () {
    testWidgets('starts as 16 does: what it takes, for the PhilSys ID', (
      tester,
    ) async {
      await pumpIdScreen(tester, api(ok));
      expect(tester.takeException(), isNull);
      expect(find.text('NATIONAL ID · +50%'), findsOneWidget);
      expect(find.text('VERIFY WITH YOUR ID'), findsOneWidget);
      expect(find.text('WHAT YOU NEED'), findsOneWidget);
      for (final need in [
        'Your National ID card',
        'Good light',
        'About two minutes',
      ]) {
        expect(find.text(need), findsOneWidget);
      }
      expect(find.textContaining('PhilID card or ePhilID'), findsOneWidget);
      expect(find.textContaining('government ID'), findsNothing);
      expect(find.text('TAKE ID PHOTO'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(asked, isEmpty, reason: 'nothing is taken until asked');
    });

    testWidgets('takes the front, the back and the face, then shows them', (
      tester,
    ) async {
      await pumpIdScreen(tester, api(ok));
      await tap(tester, 'TAKE ID PHOTO');
      expect(asked, [IdShot.front, IdShot.back, IdShot.face]);
      expect(find.text('CHECK YOUR PHOTOS'), findsOneWidget);
      for (final shot in IdShot.values) {
        await tester.ensureVisible(
          find.byKey(ValueKey('preview-${shot.name}')),
        );
        expect(find.text(shot.title), findsOneWidget);
      }
      expect(find.text('Retake'), findsNWidgets(3));
      expect(find.text('SEND FOR REVIEW'), findsOneWidget);
      expect(sent, isEmpty, reason: 'nothing is sent until asked');
    });

    testWidgets('closing a camera keeps what was taken for the next go', (
      tester,
    ) async {
      var closeOnBack = true;
      await pumpIdScreen(
        tester,
        api(ok),
        answer: (shot) => shot == IdShot.back && closeOnBack
            ? null
            : Uint8List.fromList(photo),
      );
      await tap(tester, 'TAKE ID PHOTO');
      expect(asked, [IdShot.front, IdShot.back]);
      expect(find.text('VERIFY WITH YOUR ID'), findsOneWidget);

      closeOnBack = false;
      asked.clear();
      await tap(tester, 'TAKE ID PHOTO');
      expect(asked, [IdShot.back, IdShot.face], reason: 'the front is kept');
      expect(find.text('CHECK YOUR PHOTOS'), findsOneWidget);
    });

    testWidgets('Retake replaces only that photo', (tester) async {
      await pumpIdScreen(tester, api(ok));
      await tap(tester, 'TAKE ID PHOTO');
      asked.clear();
      final back = find.descendant(
        of: find.byKey(const ValueKey('preview-back')),
        matching: find.text('Retake'),
      );
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pump();
      expect(asked, [IdShot.back]);
      expect(find.text('CHECK YOUR PHOTOS'), findsOneWidget);
    });

    testWidgets('the face shows mirrored, as the camera showed it', (
      tester,
    ) async {
      await pumpIdScreen(tester, api(ok));
      await tap(tester, 'TAKE ID PHOTO');
      final face = find.byKey(const ValueKey('framed-face'));
      final flip = tester.widget<Transform>(
        find.descendant(of: face, matching: find.byType(Transform)).first,
      );
      expect(flip.transform.entry(0, 0), -1);
      for (final shot in [IdShot.front, IdShot.back]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('framed-${shot.name}')),
            matching: find.byType(Transform),
          ),
          findsNothing,
          reason: '${shot.name} is shown as it is',
        );
      }
    });

    testWidgets('says what sending agrees to, and that the photos go', (
      tester,
    ) async {
      await pumpIdScreen(tester, api(ok));
      await tap(tester, 'TAKE ID PHOTO');
      final consent = find.textContaining("PSA's PhilSys Check, where PSA");
      await tester.ensureVisible(consent);
      expect(consent, findsOneWidget);
      expect(
        find.textContaining('your first name and the result'),
        findsOneWidget,
      );
      expect(find.textContaining('deleted once it is decided'), findsOneWidget);
    });

    testWidgets('sends the three photos, then says it is in review', (
      tester,
    ) async {
      await pumpIdScreen(tester, api(ok), percent: 50);
      await tap(tester, 'TAKE ID PHOTO');
      await tester.tap(find.text('SEND FOR REVIEW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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

      // 21 · Sent for review.
      expect(find.text('NATIONAL ID · IN REVIEW'), findsOneWidget);
      expect(find.text('SENT FOR REVIEW'), findsOneWidget);
      expect(find.textContaining('stays at 50% until then'), findsOneWidget);
      expect(find.text('Photo of your ID'), findsOneWidget);
      expect(find.text('Live selfie'), findsOneWidget);
      expect(find.text('Waiting for an admin'), findsOneWidget);
      expect(find.text('BACK TO PROFILE'), findsOneWidget);
    });

    testWidgets('a refused send says why and keeps the photos', (tester) async {
      await pumpIdScreen(
        tester,
        api(
          (_) => http.Response(
            jsonEncode({
              'error': 'already_submitted',
              'message': 'Your National ID is already waiting for review.',
            }),
            409,
          ),
        ),
      );
      await tap(tester, 'TAKE ID PHOTO');
      await tester.tap(find.text('SEND FOR REVIEW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Not sent'), findsOneWidget);
      expect(find.textContaining('already waiting for review'), findsOneWidget);
      expect(find.text('CHECK YOUR PHOTOS'), findsOneWidget);
      expect(find.byKey(const ValueKey('preview-face')), findsOneWidget);
    });
  });

  group('the camera', () {
    // The Figma frames' phone: 402 × 874 under a 54 px status bar.
    const figma = Size(402, 874);
    const notch = EdgeInsets.only(top: 54, bottom: 34);

    Future<void> pumpCamera(
      WidgetTester tester,
      IdShot shot, {
      Set<IdShot> taken = const {},
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
                taken: taken,
                preview: const ColoredBox(color: Colors.blueGrey),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    test('the guides are the design\'s, where the design put them', () {
      for (final shot in [IdShot.front, IdShot.back]) {
        final card = shot.guideIn(figma, notch);
        expect(card.width, 330);
        expect(card.height, closeTo(208, 0.5));
        expect(card.left, 36);
        expect(card.top, closeTo(306, 1));
      }
      final face = IdShot.face.guideIn(figma, notch);
      expect(face.width, 240);
      expect(face.height, 300);
      expect(face.left, 81);
      expect(face.top, closeTo(260, 1));
    });

    test(
      'the card is the width less 36 each side; the oval 60% when narrower',
      () {
        const safe = EdgeInsets.only(top: 54, bottom: 34);
        final small = IdShot.front.guideIn(const Size(360, 800), safe);
        expect(small.width, 288);
        expect(small.height, closeTo(182, 0.5));
        final large = IdShot.front.guideIn(const Size(430, 932), safe);
        expect(large.width, 358);
        expect(large.height, closeTo(226, 0.5));
        final face = IdShot.face.guideIn(const Size(360, 800), safe);
        expect(face.width, 216);
        expect(face.height, 270);
      },
    );

    test(
      'the guides shrink on a short phone and stay clear of the shutter',
      () {
        const small = Size(320, 568);
        for (final shot in IdShot.values) {
          final guide = shot.guideIn(small, EdgeInsets.zero);
          expect(guide.left, greaterThanOrEqualTo(36));
          expect(guide.right, lessThanOrEqualTo(small.width - 36));
          expect(guide.top, greaterThanOrEqualTo(118));
          expect(guide.bottom, lessThan(small.height - 140));
          expect(guide.width / guide.height, closeTo(shot.aspect, 0.01));
        }
      },
    );

    for (final (shot, title, step) in [
      (IdShot.front, 'ID FRONT', 'STEP 1 OF 3'),
      (IdShot.back, 'ID BACK', 'STEP 2 OF 3'),
      (IdShot.face, 'YOUR FACE', 'STEP 3 OF 3'),
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

    testWidgets('the chips tick what is taken and mark what is being taken', (
      tester,
    ) async {
      await pumpCamera(tester, IdShot.back, taken: {IdShot.front});
      expect(find.bySemanticsLabel('ID front, taken'), findsOneWidget);
      expect(find.bySemanticsLabel('ID back, now'), findsOneWidget);
      expect(find.bySemanticsLabel('Your face'), findsOneWidget);
    });

    testWidgets('nothing overflows on a small phone at large text', (
      tester,
    ) async {
      for (final shot in IdShot.values) {
        await pumpCamera(
          tester,
          shot,
          taken: {IdShot.front},
          size: const Size(360, 640),
          safe: const EdgeInsets.only(top: 24),
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('stays dark on the light ground', (tester) async {
      await pumpCamera(tester, IdShot.front, ground: AppPalette.light);
      final title = tester.widget<Text>(find.text('ID FRONT'));
      expect(title.style?.color, AppPalette.dark.onBackground);
    });

    testWidgets('a phone with no camera plugin says so, and can be closed', (
      tester,
    ) async {
      await pumpIdScreenWithoutStandIn(tester, api);
      await tester.tap(find.text('TAKE ID PHOTO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Its spinner never settles, so wait out the failing plugin call itself.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(find.text('ID FRONT'), findsOneWidget);
      expect(find.textContaining('could not start'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close camera'));
      await tester.pumpAndSettle();
      expect(find.text('ID FRONT'), findsNothing);
      expect(find.text('VERIFY WITH YOUR ID'), findsOneWidget);
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
      expect(find.text('+50% · Take the QR photo again.'), findsOneWidget);
    });

    test('the notification opens the verification screen, for anyone', () {
      expect(
        targetFor('national_id_reviewed', const {'role': 'general_user'}),
        NotificationTarget.verification,
      );
      expect(canOpen('national_id_reviewed', const {}), isTrue);
    });

    test('a verified address shows masked, as 15 does', () {
      expect(maskEmail('m.reyes@gmail.com'), 'm•••@gmail.com');
      expect(maskEmail(null), isNull);
    });
  });
}
