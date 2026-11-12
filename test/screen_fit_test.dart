import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:replit/api/api_client.dart';
import 'package:replit/api/session.dart';
import 'package:replit/location/sos_location.dart';
import 'package:replit/models/active_report.dart';
import 'package:replit/screens/report_status_screen.dart';
import 'package:replit/screens/sos_report_screen.dart';
import 'package:replit/theme.dart';

import 'citizen_flow_test.dart' show FakeGeo, kPixel;
import 'real_font.dart';

/// 12 November 2026: "the "what are we sending", "getting you help", and
/// "fire out" screen is still scrollable. make it not to by removing
/// "encrypted, shared only with responders" to make it unscrollable and make
/// it responsive".
///
/// Measured in Inter, the app's own typeface, on phones from a short one to
/// the 402 × 874 frame.
void main() {
  const me = 'm.reyes@gmail.com';
  setUpAll(loadAppFont);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ActiveReportStore.reset();
    Session.instance.email = me;
    GeolocatorPlatform.instance = FakeGeo();
    SosLocation.instance.reset();
  });

  ApiClient api({String status = 'reported'}) => ApiClient(
    client: MockClient(
      (req) async => http.Response(
        jsonEncode({
          'id': 'a1',
          'designation': 'Area 1.2',
          'status': status,
          'report_count': 3,
          'centroid_lat': 14.54,
          'centroid_lng': 121.0,
        }),
        200,
      ),
    ),
  );

  Widget status({String state = 'reported'}) => ReportStatusScreen.of(
    ActiveReport(
      owner: me,
      reportId: 'r1',
      areaId: 'a1',
      designation: 'Area 1.2',
      lat: 14.54,
      lng: 121.0,
      submittedAt: DateTime.now(),
      agencies: const ['fire_volunteer'],
    ),
    api: api(status: state),
  );

  /// Opens [screen] on a phone of [size]; how far it scrolls.
  Future<double> open(WidgetTester tester, Size size, Widget screen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    return tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .maxScrollExtent;
  }

  /// The ring's width, or null when it stepped aside.
  double? ring(WidgetTester tester) {
    final ring = find.byType(CircularProgressIndicator);
    return ring.evaluate().isEmpty ? null : tester.getSize(ring).width;
  }

  const phones = [
    Size(360, 600),
    Size(360, 690),
    Size(402, 778),
    Size(412, 850),
    Size(402, 874),
  ];

  for (final phone in phones) {
    testWidgets('"Getting you help" fits a ${phone.width.round()} × '
        '${phone.height.round()} phone', (tester) async {
      expect(await open(tester, phone, status()), 0);
      expect(find.text('GETTING YOU HELP'), findsOneWidget);
      expect(find.textContaining('ENCRYPTED'), findsNothing);
      expect(
        find.text('Something else? Call a hotline').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('"Fire out" fits a ${phone.width.round()} × '
        '${phone.height.round()} phone', (tester) async {
      expect(await open(tester, phone, status(state: 'fire_out')), 0);
      expect(find.text('FIRE OUT'), findsWidgets);
      expect(find.text('DONE').hitTestable(), findsOneWidget);
    });

    testWidgets('"What are we sending?" fits a ${phone.width.round()} × '
        '${phone.height.round()} phone', (tester) async {
      expect(await open(tester, phone, SosReportScreen(photoBytes: kPixel)), 0);
      expect(find.text('WHAT ARE WE SENDING?'), findsOneWidget);
      expect(find.text('SEND REPORT').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('the ring takes the room there is, and steps aside without it', (
    tester,
  ) async {
    final sizes = <double?>[];
    for (final phone in phones) {
      await open(tester, phone, status());
      sizes.add(ring(tester));
    }
    // A short phone: the steps say what the ring would.
    expect(sizes.first, isNull);
    expect(find.text('Waiting to be accepted'), findsOneWidget);
    // Taller phones: a bigger ring, up to the frame's 144.
    final shown = sizes.skip(1).cast<double>().toList();
    for (var i = 1; i < shown.length; i++) {
      expect(shown[i], greaterThan(shown[i - 1]));
    }
    expect(shown.last, 144);
    // The figure is always there; the stage under it once there is room.
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('CONFIRMING'), findsOneWidget);
  });

  testWidgets('the photo takes the room there is: 214 in the frame', (
    tester,
  ) async {
    double photo() => tester
        .getSize(find.bySemanticsLabel(RegExp('^Photo of the scene')).first)
        .height;
    await open(tester, phones.last, SosReportScreen(photoBytes: kPixel));
    expect(photo(), 214);
    await open(tester, phones.first, SosReportScreen(photoBytes: kPixel));
    expect(photo(), inInclusiveRange(88, 213));
  });

  testWidgets('a very short phone scrolls rather than cut anything off', (
    tester,
  ) async {
    final over = await open(
      tester,
      const Size(320, 480),
      SosReportScreen(photoBytes: kPixel),
    );
    expect(over, greaterThan(0));
    await tester.scrollUntilVisible(
      find.text('SEND REPORT'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SEND REPORT').hitTestable(), findsOneWidget);
  });
}
