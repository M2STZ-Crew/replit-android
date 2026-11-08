import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/updates/app_updates.dart';
import 'package:replit/theme.dart';

/// "Check for updates", Android only (the 5 November issue list, 2.4, and
/// issue 3 after it): the newest build from the repository's GitHub releases,
/// for anyone, with no Firebase tester invitation, installed from inside the
/// app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppUpdates.supportedOverride = null;
    AppUpdates.checkOverride = null;
    AppUpdates.installOverride = null;
    AppUpdates.clientOverride = null;
    AppUpdates.installedBuildOverride = null;
    AppUpdates.installedVersionOverride = null;
  });

  group('the sheet', () {
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

    testWidgets('a newer build: its version, size, notes, and an install', (
      tester,
    ) async {
      final progress = Completer<void>();
      late ValueChanged<double?> report;
      AppUpdates.checkOverride = () async => const UpdateAvailable(
        AvailableRelease(
          version: '1.12.26',
          build: 50,
          size: 72 * 1024 * 1024,
          notes: 'The splash says "Connecting to RepLiT".',
        ),
      );
      AppUpdates.installOverride = (onProgress) {
        report = onProgress;
        return progress.future;
      };
      await open(tester);
      expect(find.text('Version 1.12.26 (50) is ready.'), findsOneWidget);
      expect(find.text('Download: 72 MB. Wi-Fi is best.'), findsOneWidget);
      expect(
        find.text('The splash says "Connecting to RepLiT".'),
        findsOneWidget,
      );

      await tester.tap(find.text('DOWNLOAD AND INSTALL'));
      await tester.pump();
      expect(find.text('Downloading…'), findsOneWidget);
      expect(find.textContaining('allow installs from RepLiT'), findsOneWidget);
      report(0.42);
      await tester.pump();
      expect(find.text('Downloading… 42%'), findsOneWidget);

      progress.complete();
      await tester.pump();
      expect(find.textContaining('Finish the install'), findsOneWidget);
    });

    testWidgets('after the hand-off, the installer can be opened again', (
      tester,
    ) async {
      var installs = 0;
      late Completer<void> pending;
      AppUpdates.checkOverride = () async => const UpdateAvailable(
        AvailableRelease(version: '1.12.27', build: 51, size: 72 * 1024 * 1024),
      );
      AppUpdates.installOverride = (_) {
        installs++;
        pending = Completer<void>();
        return pending.future;
      };
      await open(tester);
      await tester.tap(find.text('DOWNLOAD AND INSTALL'));
      await tester.pump();
      pending.complete();
      await tester.pump();
      expect(find.textContaining('Finish the install'), findsOneWidget);

      // The install window was closed: the same download opens it again.
      await tester.tap(find.text('OPEN THE INSTALLER AGAIN'));
      await tester.pump();
      expect(find.text('Opening the installer…'), findsOneWidget);
      expect(installs, 2);
      pending.complete();
      await tester.pump();
      expect(find.textContaining('Finish the install'), findsOneWidget);
    });

    testWidgets('an update already downloaded installs straight away', (
      tester,
    ) async {
      AppUpdates.checkOverride = () async => const UpdateAvailable(
        AvailableRelease(version: '1.12.27', build: 51, size: 72 * 1024 * 1024),
        downloaded: true,
      );
      await open(tester);
      expect(
        find.text('Version 1.12.27 (51) is downloaded and ready to install.'),
        findsOneWidget,
      );
      expect(find.textContaining('Wi-Fi'), findsNothing);
      expect(find.text('INSTALL'), findsOneWidget);
    });

    testWidgets('a failed check explains itself and can be tried again', (
      tester,
    ) async {
      var calls = 0;
      AppUpdates.checkOverride = () async {
        calls++;
        return calls == 1
            ? const UpdateCheckFailed('NETWORK_FAILURE')
            : const UpToDate();
      };
      await open(tester);
      expect(find.textContaining('No connection'), findsOneWidget);

      await tester.tap(find.text('TRY AGAIN'));
      await tester.pump();
      await tester.pump();
      expect(find.text('You have the latest version.'), findsOneWidget);
    });

    testWidgets('a failed install says why', (tester) async {
      AppUpdates.checkOverride = () async => const UpdateAvailable(
        AvailableRelease(version: '1.12.26', build: 50),
      );
      AppUpdates.installOverride = (_) async =>
          throw const UpdateInstallFailed('CORRUPT');
      await open(tester);
      await tester.tap(find.text('DOWNLOAD AND INSTALL'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('damaged on the way'), findsOneWidget);
    });
  });

  group('GitHub releases', () {
    const channel = MethodChannel('replit/updates');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final sha = 'ab' * 32;
    late Directory downloads;
    late List<MethodCall> calls;
    late List<Uri> fetched;

    Map<String, Object?> manifest({int build = 50}) => {
      'version': '1.12.26',
      'build': build,
      'tag': 'android-v1.12.26-$build',
      'apk': 'RepLiT-1.12.26-$build.apk',
      'size': 6,
      'sha256': sha,
      'notes': 'Build $build (abc1234)\n\nNew for testers.',
    };

    void serve({
      Object? latest,
      int latestStatus = 200,
      List<int> apk = const [1, 2, 3, 4, 5, 6],
    }) {
      AppUpdates.clientOverride = () => MockClient((request) async {
        fetched.add(request.url);
        if (request.url.path.endsWith('/latest/download/latest.json')) {
          return http.Response(jsonEncode(latest), latestStatus);
        }
        if (request.url.path.endsWith('.apk')) {
          return http.Response.bytes(apk, 200);
        }
        return http.Response('', 404);
      });
    }

    setUp(() {
      downloads = Directory.systemTemp.createTempSync('replit_updates_');
      calls = [];
      fetched = [];
      AppUpdates.installedBuildOverride = 47;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'updatesDir' => downloads.path,
          'install' => true,
          _ => null,
        };
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (downloads.existsSync()) downloads.deleteSync(recursive: true);
    });

    // 8 November: an iPhone is told of a newer version too. Its build
    // numbers count apart from Android's (8 to Android's 52), so the version
    // decides, and there is nothing to download.
    test('an iPhone compares versions, and downloads nothing', () async {
      AppUpdates.supportedOverride = false;
      serve(latest: manifest());
      AppUpdates.installedVersionOverride = '1.12.25';
      final found = await AppUpdates.check();
      expect(found, isA<UpdateAvailable>());
      expect((found as UpdateAvailable).release.version, '1.12.26');
      AppUpdates.installedVersionOverride = '1.12.26';
      expect(await AppUpdates.check(), isA<UpToDate>());
      expect(calls, isEmpty);
    });

    test('a newer build in the latest release is offered', () async {
      serve(latest: manifest());
      final found = await AppUpdates.check();
      expect(found, isA<UpdateAvailable>());
      final release = (found as UpdateAvailable).release;
      expect(release.label, '1.12.26 (50)');
      expect(release.notes, startsWith('Build 50'));
      expect(
        fetched.single.toString(),
        'https://github.com/M2STZ-Crew/replit-android/releases/latest/'
        'download/latest.json',
      );
      expect(
        release.apkUrl.toString(),
        'https://github.com/M2STZ-Crew/replit-android/releases/download/'
        'android-v1.12.26-50/RepLiT-1.12.26-50.apk',
      );
    });

    test('the same build, or an older one, is up to date', () async {
      serve(latest: manifest(build: 47));
      expect(await AppUpdates.check(), isA<UpToDate>());
      serve(latest: manifest(build: 46));
      expect(await AppUpdates.check(), isA<UpToDate>());
    });

    test('no release published yet is up to date', () async {
      serve(latest: null, latestStatus: 404);
      expect(await AppUpdates.check(), isA<UpToDate>());
    });

    test('a release it cannot trust is refused', () async {
      for (final bad in [
        {...manifest(), 'apk': '../RepLiT.apk'},
        {...manifest(), 'apk': 'RepLiT.zip'},
        {...manifest(), 'tag': 'v1/../../x'},
        {...manifest(), 'sha256': 'abc'},
        {...manifest(), 'size': 0},
        {...manifest()}..remove('build'),
        'not a manifest',
      ]) {
        serve(latest: bad);
        final found = await AppUpdates.check();
        expect(found, isA<UpdateCheckFailed>(), reason: '$bad');
        expect((found as UpdateCheckFailed).code, 'BAD_RELEASE');
      }
    });

    test('no connection says so', () async {
      AppUpdates.clientOverride = () =>
          MockClient((_) async => throw http.ClientException('offline'));
      final found = await AppUpdates.check();
      expect((found as UpdateCheckFailed).code, 'NETWORK_FAILURE');
    });

    test('installing downloads the APK and hands it to Android', () async {
      serve(latest: manifest());
      await AppUpdates.check();
      final progress = <double?>[];
      await AppUpdates.install(progress.add);

      final install = calls.singleWhere((c) => c.method == 'install');
      final path = (install.arguments as Map)['path'] as String;
      expect(File(path).parent.path, downloads.path);
      expect(path, endsWith('RepLiT-1.12.26-50.apk'));
      expect(File(path).readAsBytesSync(), [1, 2, 3, 4, 5, 6]);
      expect((install.arguments as Map)['sha256'], sha);
      expect(progress.first, 0);
      expect(progress.last, 1);
    });

    test('a whole download waits; installing again fetches nothing', () async {
      serve(latest: manifest());
      await AppUpdates.check();
      await AppUpdates.install((_) {});
      int apkFetches() => fetched.where((u) => u.path.endsWith('.apk')).length;
      expect(apkFetches(), 1);

      // The install window was closed; the next check finds the file.
      final again = await AppUpdates.check();
      expect((again as UpdateAvailable).downloaded, isTrue);
      final progress = <double?>[];
      await AppUpdates.install(progress.add);
      expect(apkFetches(), 1, reason: 'no second download');
      expect(calls.where((c) => c.method == 'install'), hasLength(2));
      expect(progress, [1]);
    });

    test('once the update is installed, the waiting APK goes', () async {
      serve(latest: manifest());
      await AppUpdates.check();
      await AppUpdates.install((_) {});
      expect(downloads.listSync(), hasLength(1));

      AppUpdates.installedBuildOverride = 50;
      expect(await AppUpdates.check(), isA<UpToDate>());
      expect(downloads.listSync(), isEmpty);
    });

    test('a part file, a short file or an older APK is cleared', () async {
      File(
        '${downloads.path}/RepLiT-1.12.26-50.apk.part',
      ).writeAsBytesSync([1, 2]);
      File('${downloads.path}/RepLiT-1.12.26-50.apk').writeAsBytesSync([1, 2]);
      File(
        '${downloads.path}/RepLiT-1.12.25-47.apk',
      ).writeAsBytesSync([1, 2, 3, 4, 5, 6]);
      serve(latest: manifest());
      final found = await AppUpdates.check();
      expect((found as UpdateAvailable).downloaded, isFalse);
      expect(downloads.listSync(), isEmpty);
    });

    test('a download cut short is thrown away, never installed', () async {
      serve(latest: manifest(), apk: [1, 2, 3]);
      await AppUpdates.check();
      await expectLater(
        AppUpdates.install((_) {}),
        throwsA(
          isA<UpdateInstallFailed>().having(
            (e) => e.code,
            'code',
            'DOWNLOAD_FAILURE',
          ),
        ),
      );
      expect(calls.where((c) => c.method == 'install'), isEmpty);
      expect(downloads.listSync(), isEmpty);
    });

    test('Android refusing the download says why', () async {
      serve(latest: manifest());
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'updatesDir') return downloads.path;
        throw PlatformException(code: 'CORRUPT');
      });
      await AppUpdates.check();
      await expectLater(
        AppUpdates.install((_) {}),
        throwsA(
          isA<UpdateInstallFailed>().having((e) => e.code, 'code', 'CORRUPT'),
        ),
      );
      expect(downloads.listSync(), isEmpty);
    });
  });

  test('every failure has words for the resident', () {
    for (final code in [
      'NETWORK_FAILURE',
      'DOWNLOAD_FAILURE',
      'CORRUPT',
      'BAD_RELEASE',
      'UNAVAILABLE',
      'NOT_IMPLEMENTED',
      'INSTALLATION_FAILURE',
      'UPDATE_NOT_AVAILABLE',
      'HTTP_503',
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
