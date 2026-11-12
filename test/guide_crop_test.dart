import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/material.dart' as m show Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/id_camera_screen.dart';
import 'package:replit/screens/national_id_screen.dart';
import 'package:replit/theme.dart';
import 'package:replit/verification/guide_crop.dart';

/// The National ID photos come back as the resident framed them: cut to the
/// guide on the camera screen, and shown in its shape on the form (the 5
/// November issue list, 1.7).
void main() {
  // A 400 × 800 viewfinder over a 9:16 preview, which covers it with 25 px
  // cut off each side; the card guide sits 35 px in from each edge.
  const screen = Size(400, 800);
  const preview = Size(450, 800);
  const guide = Rect.fromLTWH(35, 200, 330, 208);

  group('where the guide falls in the photo', () {
    test('a photo the preview\'s shape: the same share of it', () {
      final cut = GuideCrop.guideInPhoto(
        screen: screen,
        guide: guide,
        preview: preview,
        photo: const Size(900, 1600),
        margin: 0,
      );
      // (35 + 25) / 450 of 900 = 120; (365 + 25) / 450 of 900 = 780.
      expect(cut.left, moreOrLessEquals(120));
      expect(cut.right, moreOrLessEquals(780));
      expect(cut.top, moreOrLessEquals(400));
      expect(cut.bottom, moreOrLessEquals(816));
    });

    test('a wider 3:4 photo: the preview is its middle strip', () {
      final cut = GuideCrop.guideInPhoto(
        screen: screen,
        guide: guide,
        preview: preview,
        photo: const Size(1200, 1600),
        margin: 0,
      );
      // The 9:16 preview is the middle 75 % of a 3:4 photo's width.
      expect(cut.left, moreOrLessEquals(270));
      expect(cut.right, moreOrLessEquals(930));
      expect(cut.top, moreOrLessEquals(400));
      expect(cut.bottom, moreOrLessEquals(816));
    });

    test('the margin widens it, and never past the photo', () {
      final cut = GuideCrop.guideInPhoto(
        screen: screen,
        guide: const Rect.fromLTWH(-20, -20, 440, 840),
        preview: preview,
        photo: const Size(900, 1600),
      );
      expect(cut.left, 0);
      expect(cut.top, 0);
      expect(cut.right, 900);
      expect(cut.bottom, 1600);
    });

    test('the cut keeps the guide\'s shape', () {
      final cut = GuideCrop.guideInPhoto(
        screen: screen,
        guide: guide,
        preview: preview,
        photo: const Size(900, 1600),
      );
      expect(cut.width / cut.height, moreOrLessEquals(330 / 208, epsilon: .01));
    });
  });

  test('a real photo is cut to what was inside the guide', () async {
    // Black, with a red card exactly where the guide is.
    final frame = img.Image(width: 900, height: 1600);
    img.fill(frame, color: img.ColorRgb8(0, 0, 0));
    img.fillRect(
      frame,
      x1: 120,
      y1: 400,
      x2: 780,
      y2: 816,
      color: img.ColorRgb8(220, 20, 20),
    );
    final jpeg = img.encodeJpg(frame, quality: 95);

    final out = await GuideCrop.cropToGuide(
      jpeg,
      screen: screen,
      guide: guide,
      preview: preview,
    );
    final cut = img.decodeJpg(out)!;
    // The card's 660 × 416, and the 5 % margin on each side.
    expect(cut.width, closeTo(660 * 1.1, 2));
    expect(cut.height, closeTo(416 * 1.1, 2));
    final middle = cut.getPixel(cut.width ~/ 2, cut.height ~/ 2);
    expect(middle.r, greaterThan(180));
    expect(middle.g, lessThan(60));
    // Most of the result is the card: the table top around it is gone.
    final corner = cut.getPixel(2, 2);
    expect(corner.r, lessThan(60));
  });

  test('what it cannot read it hands back whole', () async {
    final notJpeg = Uint8List.fromList(utf8.encode('not a photo'));
    final out = await GuideCrop.cropToGuide(
      notJpeg,
      screen: screen,
      guide: guide,
      preview: preview,
    );
    expect(out, notJpeg);
  });

  testWidgets('Check your photos shows each in its guide\'s shape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
      '60e6kgAAAABJRU5ErkJggg==',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: NationalIdScreen(
          api: ApiClient(
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
          camera: (_) async => Uint8List.fromList(photo),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TAKE ID PHOTO'));
    // Each photo is a round trip to the camera stand-in.
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('CHECK YOUR PHOTOS'), findsOneWidget);

    for (final shot in IdShot.values) {
      final framed = find.byKey(ValueKey('framed-${shot.name}'));
      expect(framed, findsOneWidget, reason: shot.name);
      final size = tester.getSize(framed);
      expect(
        size.width / size.height,
        moreOrLessEquals(shot.aspect, epsilon: .01),
        reason: '${shot.name} keeps its guide\'s shape',
      );
      expect(
        find.descendant(of: framed, matching: find.byType(m.Image)),
        findsOneWidget,
      );
    }
  });
}
