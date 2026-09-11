import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/screens/area_detail_screen.dart';
import 'package:replit/theme.dart';

/// "06 Area detail": the confidence bars say what the server computed, and
/// "I see it too" is offered only where the report would actually join.
void main() {
  // The server's own terms (clustering.py): N = 3/10, S = 1 − 84/300, V = .42.
  Map<String, dynamic> area({String status = 'dispatched'}) => {
    'id': 'a1',
    'designation': 'Area 1.2',
    'status': status,
    'centroid_lat': 14.5414,
    'centroid_lng': 121.0014,
    'report_count': 3,
    'confidence_score': 0.462,
    'confidence_band': 'medium',
    'n_score': 0.3,
    's_score': 0.72,
    'v_score': 0.42,
    'reports': [],
  };

  // ~200 m from the centre: inside the 300 m a report can join from. (The
  // frame shows the button at "400 m away"; from there a report would open a
  // separate incident, so the screen does not offer it.)
  const here200m = LatLng(14.5396, 121.0014);
  const here2km = LatLng(14.5234, 121.0014);

  ApiClient api({String status = 'dispatched', bool mine = false}) => ApiClient(
    client: MockClient((req) async {
      if (req.url.path.endsWith('/reports/mine')) {
        return http.Response(
          jsonEncode([
            if (mine) {'id': 'r9', 'area_id': 'a1'},
          ]),
          200,
        );
      }
      return http.Response(jsonEncode(area(status: status)), 200);
    }),
  );

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

  for (final scale in <double>[1.0, 1.5]) {
    testWidgets(
      'reads the confidence as the server computed it, at ${scale}x',
      (tester) async {
        await pump(
          tester,
          AreaDetailScreen(areaId: 'a1', here: here200m, api: api()),
          scale: scale,
        );
        expect(tester.takeException(), isNull);

        expect(find.text('AREA 1.2'), findsOneWidget);
        expect(
          find.text('INCIDENT AREA'),
          findsOneWidget,
          reason: 'no geocoder',
        );
        expect(find.text('3 REPORTS'), findsOneWidget);
        // ~200 m on the WGS84 ellipsoid.
        expect(find.textContaining(RegExp(r'^19\d M AWAY$')), findsOneWidget);
        expect(find.text('MEDIUM'), findsOneWidget);
        expect(find.text('3 of 10 reports'), findsOneWidget);
        expect(find.text('Spread 84 m'), findsOneWidget);
        expect(find.text('Reporters average 42%'), findsOneWidget);
        // The status chip and the progress line both name it.
        expect(find.text('DISPATCHED'), findsNWidgets(2));
        expect(find.text('I SEE IT TOO — ADD MY REPORT'), findsOneWidget);
      },
    );
  }

  testWidgets('from 2 km away it explains instead of offering', (tester) async {
    await pump(
      tester,
      AreaDetailScreen(areaId: 'a1', here: here2km, api: api()),
    );
    expect(find.text('I SEE IT TOO — ADD MY REPORT'), findsNothing);
    expect(find.textContaining('within 300 m'), findsOneWidget);
  });

  testWidgets('your own area offers to follow it, not to report again', (
    tester,
  ) async {
    await pump(
      tester,
      AreaDetailScreen(areaId: 'a1', here: here200m, api: api(mine: true)),
    );
    expect(find.text('I SEE IT TOO — ADD MY REPORT'), findsNothing);
    expect(find.text('YOU REPORTED THIS — FOLLOW IT'), findsOneWidget);
  });

  testWidgets('once it is over there is nothing to add', (tester) async {
    await pump(
      tester,
      AreaDetailScreen(
        areaId: 'a1',
        here: here200m,
        api: api(status: 'post_incident_report'),
      ),
    );
    // A crew's Post-Incident Report is internal: residents see "resolved".
    expect(find.text('RESOLVED'), findsNWidgets(2));
    expect(find.text('I SEE IT TOO — ADD MY REPORT'), findsNothing);
  });
}
