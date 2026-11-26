import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:replit/screens/profile_screen.dart';
import 'package:replit/store_build.dart';

/// v1.12.64: Google Play's copy leaves out location "All the time"
/// (answered "Leave it out for now", 26 Nov 2026).
void main() {
  group('location "All the time"', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('the manifest names it through the Play switch', () {
      expect(
        manifest,
        contains(r'android:name="${backgroundLocationPermission}"'),
      );
      expect(
        manifest,
        isNot(contains('"android.permission.ACCESS_BACKGROUND_LOCATION"')),
      );
    });

    test('only the APK page\'s copy asks for it', () {
      final at = gradle.indexOf(
        'manifestPlaceholders["backgroundLocationPermission"]',
      );
      expect(at, greaterThan(0));
      final block = gradle.substring(at, at + 400);
      // Play first, then the APK page's copy.
      expect(
        block.indexOf('NO_BACKGROUND_LOCATION_ON_PLAY'),
        lessThan(
          block.indexOf('android.permission.ACCESS_BACKGROUND_LOCATION'),
        ),
      );
      expect(block, contains('if (playStore)'));
    });

    test('the APK page\'s copy keeps the responders\' foreground service', () {
      // Play's copy leaves it out since v1.12.65 (test/v1_12_65_test.dart).
      expect(
        gradle,
        contains('"android.permission.FOREGROUND_SERVICE_LOCATION"'),
      );
    });
  });

  group('Profile', () {
    tearDown(() => StoreBuild.playOverride = null);

    test('the APK page\'s copy offers fire alerts with the app closed', () {
      StoreBuild.playOverride = false;
      expect(ProfileScreen.offersAllTheTime, isTrue);
    });

    test('the Play copy does not', () {
      StoreBuild.playOverride = true;
      expect(ProfileScreen.offersAllTheTime, isFalse);
    });
  });
}
