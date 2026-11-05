import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/updates/app_updates.dart';
import 'package:replit/theme.dart';

/// "Check for updates", Android only (the 5 November issue list, 2.4): a newer
/// build from Firebase App Distribution, installed from inside the app.
void main() {
  tearDown(() {
    AppUpdates.supportedOverride = null;
    AppUpdates.checkOverride = null;
    AppUpdates.installOverride = null;
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showUpdateSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('up to date says so', (tester) async {
    AppUpdates.checkOverride = () async => const UpToDate();
    await open(tester);
    expect(find.text('CHECK FOR UPDATES'), findsOneWidget);
    expect(find.text('You have the latest version.'), findsOneWidget);
  });

  testWidgets('a newer build: its version, its notes, and an install', (
    tester,
  ) async {
    final progress = Completer<void>();
    late ValueChanged<double?> report;
    AppUpdates.checkOverride = () async => const UpdateAvailable(
      AvailableRelease(
        version: '1.12.24',
        build: 91,
        notes: 'Drawers keep their handle.',
      ),
    );
    AppUpdates.installOverride = (onProgress) {
      report = onProgress;
      return progress.future;
    };
    await open(tester);
    expect(find.text('Version 1.12.24 (91) is ready.'), findsOneWidget);
    expect(find.text('Drawers keep their handle.'), findsOneWidget);

    await tester.tap(find.text('DOWNLOAD AND INSTALL'));
    await tester.pump();
    expect(find.text('Downloading…'), findsOneWidget);
    report(0.42);
    await tester.pump();
    expect(find.text('Downloading… 42%'), findsOneWidget);

    progress.complete();
    await tester.pump();
    expect(find.textContaining('Finish the install'), findsOneWidget);
  });

  testWidgets('a failed check explains itself and can be tried again', (
    tester,
  ) async {
    var calls = 0;
    AppUpdates.checkOverride = () async {
      calls++;
      return calls == 1
          ? const UpdateCheckFailed('AUTHENTICATION_CANCELED')
          : const UpToDate();
    };
    await open(tester);
    expect(find.textContaining('Sign-in was cancelled'), findsOneWidget);

    await tester.tap(find.text('TRY AGAIN'));
    await tester.pump();
    await tester.pump();
    expect(find.text('You have the latest version.'), findsOneWidget);
  });

  testWidgets('a failed install says why', (tester) async {
    AppUpdates.checkOverride = () async =>
        const UpdateAvailable(AvailableRelease(version: '1.12.24', build: 91));
    AppUpdates.installOverride = (_) async =>
        throw const UpdateInstallFailed('INSTALLATION_CANCELED');
    await open(tester);
    await tester.tap(find.text('DOWNLOAD AND INSTALL'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('The install was cancelled'), findsOneWidget);
  });

  test('every failure has words for the resident', () {
    for (final code in [
      'AUTHENTICATION_CANCELED',
      'AUTHENTICATION_FAILURE',
      'NETWORK_FAILURE',
      'API_DISABLED',
      'UNAVAILABLE',
      'NOT_IMPLEMENTED',
      'INSTALLATION_CANCELED',
      'INSTALLATION_FAILURE',
      'DOWNLOAD_FAILURE',
      'HOST_ACTIVITY_INTERRUPTED',
      'SOMETHING_NEW',
    ]) {
      expect(AppUpdates.explain(code), isNotEmpty, reason: code);
    }
  });

  test('only Android checks', () {
    // flutter test runs as Android unless told otherwise.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppUpdates.supported, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppUpdates.supported, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
