import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// v1.12.64: Google Play's copy left out location "All the time" (answered
/// "Leave it out for now", 26 Nov 2026). Since v1.12.66 neither copy asks
/// for it (test/v1_12_66_test.dart); what stays from v1.12.64 is here.
void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('the APK page\'s copy keeps the responders\' foreground service', () {
    // Play's copy leaves it out since v1.12.65 (test/v1_12_65_test.dart).
    expect(
      gradle,
      contains('"android.permission.FOREGROUND_SERVICE_LOCATION"'),
    );
  });
}
