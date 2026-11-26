import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/models/area_view.dart';
import 'package:replit/store_build.dart';
import 'package:replit/theme.dart';
import 'package:replit/widgets/fire_type_row.dart';

/// v1.12.63 (26 November 2026): the LIVE panel of an organization not going
/// (coordinator_experience_test.dart), the fire type's wait, the Terms, and no
/// read-storage permission.
void main() {
  testWidgets('the fire type waits for the first team on scene', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: FireTypeRow(
            area: AreaView(const {
              'id': 'a1',
              'status': 'arrived',
              'fire_type': null,
            }),
          ),
        ),
      ),
    );
    expect(find.text('Waiting for the first team on scene'), findsOneWidget);
  });

  test('the Terms are on the residents\' site', () {
    expect(PolicyLinks.terms.path, '/terms');
    expect(PolicyLinks.terms.host, PolicyLinks.privacy.host);
  });

  test('no read-storage permission either', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
        'tools:node="remove"/>',
      ),
    );
  });
}
