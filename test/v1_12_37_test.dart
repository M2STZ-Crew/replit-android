import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/models/area_view.dart';
import 'package:replit/models/field_ops.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/field_ops.dart';
import 'package:replit/widgets/fire_type_row.dart';

/// App v1.12.37 (12 November 2026), with backend v1.12.29.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  // "in the fill-out of fire structure, the first fire organization will
  // fill out so that the second or next fire organization arrived will not
  // fill that out" (answered: the first fire team only; the rest read it).
  group('the first fire team says what is burning', () {
    const hercules = {'agency_type': 'fire_volunteer', 'primary_org_id': 'o1'};
    const bfp = {'agency_type': 'bfp', 'primary_org_id': 'o2'};
    const police = {'agency_type': 'police', 'primary_org_id': 'o3'};
    const medical = {'agency_type': 'medical', 'primary_org_id': 'o4'};

    final open = AreaView({'id': 'a1', 'status': 'arrived', 'fire_type': null});
    final answered = AreaView({
      'id': 'a1',
      'status': 'arrived',
      'fire_type': 'structural',
      'fire_subtype': 'residential',
      'fire_type_org_id': 'o1',
      'fire_type_org_name': 'Hercules Fire Brigade',
    });

    test('unanswered: any fire team may answer, no one else', () {
      expect(open.mayAnswerFireType(hercules), isTrue);
      expect(open.mayAnswerFireType(bfp), isTrue);
      expect(open.mayAnswerFireType(police), isFalse);
      expect(open.mayAnswerFireType(medical), isFalse);
      expect(open.mayAnswerFireType(null), isFalse);
    });

    test('answered: only the team that said corrects it', () {
      expect(answered.mayAnswerFireType(hercules), isTrue);
      expect(answered.mayAnswerFireType(bfp), isFalse, reason: 'next team');
      expect(answered.mayAnswerFireType(police), isFalse);
    });

    test('an older server, which does not say who answered: fire teams', () {
      final old = AreaView({
        'id': 'a1',
        'status': 'arrived',
        'fire_type': 'grass',
      });
      expect(old.mayAnswerFireType(bfp), isTrue);
      expect(old.mayAnswerFireType(police), isFalse);
    });

    testWidgets('the next team reads the answer and who gave it', (
      tester,
    ) async {
      await pump(tester, FireTypeRow(area: answered));
      expect(find.text('Fire type'), findsOneWidget);
      expect(
        find.text('Structural — Residential · Hercules Fire Brigade'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('unanswered, a team that may not answer is told who will', (
      tester,
    ) async {
      await pump(tester, FireTypeRow(area: open));
      expect(find.text('What’s burning?'), findsOneWidget);
      expect(
        find.text('Waiting for the fire team on scene to say'),
        findsOneWidget,
      );
    });
  });

  // "on that coordinator side where "LIT" placeholder in CIAR loading. put
  // the face of lit inside of it" (answered: a still face).
  group('Lit writes the CIAR', () {
    testWidgets('his face is in the circle while it is written', (
      tester,
    ) async {
      await pump(
        tester,
        const CiarStatusCard(
          state: CiarState.generating,
          reference: 'IR-2026-00142',
        ),
      );
      expect(find.text('Writing the CIAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('lit-face')), findsOneWidget);
      expect(find.text('Lit'), findsNothing, reason: 'no placeholder word');
      final face = tester.widget<Image>(find.byKey(const ValueKey('lit-face')));
      expect((face.image as ResizeImage).imageProvider, isA<AssetImage>());
      expect(File(LitPlaceholder.face).existsSync(), isTrue);
    });

    testWidgets('and gone once it is attached', (tester) async {
      await pump(
        tester,
        const CiarStatusCard(
          state: CiarState.ready,
          reference: 'IR-2026-00142',
          lockedAt: '10:24 PM',
        ),
      );
      expect(find.byKey(const ValueKey('lit-face')), findsNothing);
    });
  });
}
