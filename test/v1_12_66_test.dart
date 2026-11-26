import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/area_detail_screen.dart';
import 'package:replit/theme.dart';

/// v1.12.66: a fire's alert checks where the resident is when it is opened,
/// and neither copy asks for location "All the time" (27 Nov 2026).
void main() {
  group('no location "All the time" in either copy', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('the manifest and the build do not ask for it', () {
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      expect(manifest, isNot(contains('backgroundLocationPermission')));
      expect(gradle, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      expect(gradle, isNot(contains('backgroundLocationPermission')));
    });

    test('Profile no longer offers fire alerts with the app closed', () {
      final profile = File(
        'lib/screens/profile_screen.dart',
      ).readAsStringSync();
      expect(profile, isNot(contains('Fire alerts with the app closed')));
      expect(profile, isNot(contains('LocationPermission.always')));
    });
  });

  group('a fire near you, checked as you open it', () {
    Map<String, dynamic> area({String status = 'verified'}) => {
      'id': 'a1',
      'designation': 'Area 1.2',
      'status': status,
      'centroid_lat': 14.5414,
      'centroid_lng': 121.0014,
      'report_count': 2,
      'confidence_score': 0.4,
      'confidence_band': 'medium',
      'n_score': 0.2,
      's_score': 0.7,
      'v_score': 0.4,
      'reports': [],
    };

    // About 80 m and 500 m north of the fire's centre.
    const here80m = LatLng(14.54212, 121.0014);
    const here500m = LatLng(14.54589, 121.0014);

    ApiClient api({String status = 'verified'}) => ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/reports/mine')) {
          return http.Response('[]', 200);
        }
        return http.Response(jsonEncode(area(status: status)), 200);
      }),
    );

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: child));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('within 100 m it leads with how close and what to do', (
      tester,
    ) async {
      await pump(
        tester,
        AreaDetailScreen(areaId: 'a1', here: here80m, api: api()),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('near-fire')), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^This fire is about [78]\d m from you$')),
        findsOneWidget,
      );
      expect(find.textContaining('If anyone is trapped'), findsOneWidget);
      expect(find.text('Call 911'), findsOneWidget);
      // Above the facts: the warning is the first thing under the place.
      final warning = tester.getTopLeft(
        find.byKey(const ValueKey('near-fire')),
      );
      final facts = tester.getTopLeft(find.text('2 REPORTS'));
      expect(warning.dy, lessThan(facts.dy));
    });

    testWidgets('from 500 m it does not', (tester) async {
      await pump(
        tester,
        AreaDetailScreen(areaId: 'a1', here: here500m, api: api()),
      );
      expect(find.byKey(const ValueKey('near-fire')), findsNothing);
      expect(find.textContaining(RegExp(r'^\d+ M AWAY$')), findsOneWidget);
    });

    testWidgets('a fire that is over warns nobody', (tester) async {
      await pump(
        tester,
        AreaDetailScreen(
          areaId: 'a1',
          here: here80m,
          api: api(status: 'fire_out'),
        ),
      );
      expect(find.byKey(const ValueKey('near-fire')), findsNothing);
    });
  });
}
