import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/reporting_standing.dart';
import '../screens/camera_capture_screen.dart';
import '../screens/reporting_paused_screen.dart';

/// Opens the report camera, or "Reporting paused" when this phone already
/// knows a resident's reporting is paused after prank reports (v1.12.52).
///
/// It decides from what the phone knows ([ReportingStanding.cached], fetched
/// at start-up), so the button stays instant for everyone else: no network
/// call stands between a real fire and the camera. The server still refuses a
/// paused report, and the report screen then shows the same page.
Future<void> openReportCamera(
  BuildContext context, {
  bool replace = false,
  ApiClient? api,
}) async {
  final nav = Navigator.of(context);
  final known = ReportingStanding.cached;
  final Route<void> route = MaterialPageRoute<void>(
    builder: (_) => known != null && known.blocksNow
        ? ReportingPausedScreen(api: api)
        : const CameraCaptureScreen(),
  );
  if (replace) {
    await nav.pushReplacement(route);
  } else {
    await nav.push(route);
  }
}
