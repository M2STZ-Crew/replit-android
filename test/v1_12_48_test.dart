import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:replit/theme.dart';
import 'package:replit/updates/app_updates.dart';
import 'package:replit/widgets/design.dart';

/// v1.12.48 (17 Nov 2026: "add the background downloading when updating,
/// because it can be interrupted"): Android's DownloadManager downloads the
/// update, so leaving RepLiT does not stop it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('replit/updates');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final sha = 'ab' * 32;
  const apk = 'RepLiT-1.12.26-50.apk';
  late Directory downloads;
  late List<MethodCall> calls;
  late List<Uri> fetched;
  late _Android android;

  Map<String, Object?> manifest({String version = '1.12.26', int build = 50}) =>
      {
        'version': version,
        'build': build,
        'tag': 'android-v$version-$build',
        'apk': 'RepLiT-$version-$build.apk',
        'size': 6,
        'sha256': sha,
        'notes': 'v$version',
      };

  void serve() {
    AppUpdates.clientOverride = () => MockClient((request) async {
      fetched.add(request.url);
      if (request.url.path.endsWith('/latest/download/latest.json')) {
        return http.Response(jsonEncode(manifest()), 200);
      }
      if (request.url.path.endsWith('.apk')) {
        return http.Response.bytes(const [1, 2, 3, 4, 5, 6], 200);
      }
      return http.Response('', 404);
    });
  }

  List<MethodCall> asked(String method) =>
      calls.where((c) => c.method == method).toList();

  setUp(() {
    downloads = Directory.systemTemp.createTempSync('replit_bg_updates_');
    calls = [];
    fetched = [];
    android = _Android(downloads);
    AppUpdates.installedVersionOverride = '1.12.25';
    AppUpdates.pollEvery = Duration.zero;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return android.answer(call);
    });
    serve();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    AppUpdates.clientOverride = null;
    AppUpdates.installedVersionOverride = null;
    AppUpdates.pollEvery = const Duration(milliseconds: 500);
    if (downloads.existsSync()) downloads.deleteSync(recursive: true);
  });

  test('Download and install hands the download to Android, and follows '
      'it to the installer', () async {
    await AppUpdates.check();
    final progress = <double?>[];
    final states = <UpdateDownloadState>[];
    await AppUpdates.install(progress.add, onState: states.add);

    final start = asked('startDownload').single.arguments as Map;
    expect(
      start['url'],
      'https://github.com/M2STZ-Crew/replit-android/releases/download/'
      'android-v1.12.26-50/$apk',
    );
    expect(start['file'], apk);
    expect(start['title'], 'RepLiT 1.12.26');
    expect(start['readyText'], 'Tap to install RepLiT 1.12.26.');
    expect(start['channel'], 'app_update_en_v1');
    expect(
      fetched.where((u) => u.path.endsWith('.apk')),
      isEmpty,
      reason: 'Android downloads it, not the app',
    );
    expect(states, contains(UpdateDownloadState.background));
    expect(progress, containsAllInOrder([0.5, 1.0]));

    final install = asked('install').single.arguments as Map;
    expect(install['path'], '${downloads.path}${Platform.pathSeparator}$apk');
    expect(install['sha256'], sha);
  });

  test('a download Android is on already is followed, never started twice, '
      'and its part file is left alone', () async {
    android
      ..id = 7
      ..file = apk
      ..states = ['running', 'running', 'successful'];
    final part = File('${downloads.path}${Platform.pathSeparator}$apk')
      ..writeAsBytesSync(const [1, 2, 3]);

    final found = await AppUpdates.check();
    expect((found as UpdateAvailable).downloading, isTrue);
    expect(part.existsSync(), isTrue, reason: 'Android is still writing it');

    await AppUpdates.install((_) {});
    expect(asked('startDownload'), isEmpty);
    expect(asked('install'), hasLength(1));
  });

  test('no connection: it waits, and says so', () async {
    android.states = ['paused', 'paused', 'successful'];
    await AppUpdates.check();
    final states = <UpdateDownloadState>[];
    await AppUpdates.install((_) {}, onState: states.add);
    expect(states, contains(UpdateDownloadState.waiting));
    expect(asked('install'), hasLength(1));
  });

  test('a failed download says so, and Android lets go of it', () async {
    android.states = ['failed'];
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
    expect(asked('cancelDownload'), isNotEmpty);
    expect(android.id, isNull);
    expect(asked('install'), isEmpty);
  });

  test('closing the sheet leaves Android downloading', () async {
    android.states = ['running'];
    await AppUpdates.check();
    await AppUpdates.install((_) {}, watching: () => false);
    expect(asked('install'), isEmpty);
    expect(asked('cancelDownload'), isEmpty);
    expect(android.id, 7, reason: 'still downloading, without the sheet');
  });

  test('without a DownloadManager, the app downloads it itself', () async {
    android.available = false;
    await AppUpdates.check();
    await AppUpdates.install((_) {});
    expect(fetched.where((u) => u.path.endsWith('.apk')), hasLength(1));
    final install = asked('install').single.arguments as Map;
    expect(File(install['path'] as String).readAsBytesSync(), [
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
  });

  test("an older release's download is dropped", () async {
    android
      ..id = 5
      ..file = 'RepLiT-1.12.25-49.apk'
      ..states = ['running'];
    final found = await AppUpdates.check();
    expect((found as UpdateAvailable).downloading, isFalse);
    expect(asked('cancelDownload'), hasLength(1));
  });

  // The sheet reads and writes real files (the downloads folder), which a
  // widget test's fake clock never waits for: let real time pass, in turns.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the sheet says RepLiT can be left while Android downloads', (
    tester,
  ) async {
    android.states = ['running'];
    // On a fake clock, a poll every 0 ms would never let time move on.
    AppUpdates.pollEvery = const Duration(milliseconds: 100);
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
    await settle(tester);
    expect(UpdateSheet.isShowing, isTrue);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppButton && w.label == 'Download and install',
      ),
    );
    await settle(tester);
    expect(find.text('Downloading… 50%'), findsOneWidget);
    expect(find.textContaining('You can leave RepLiT.'), findsOneWidget);

    // Closed: the sheet stops asking; Android carries on.
    Navigator.of(tester.element(find.byType(UpdateSheet))).pop();
    await settle(tester);
    expect(UpdateSheet.isShowing, isFalse);
    final askedSoFar = asked('downloadStatus').length;
    await tester.pump(const Duration(seconds: 1));
    expect(asked('downloadStatus').length, askedSoFar);
    expect(android.id, 7);
  });
}

/// Android's side of the channel, with a DownloadManager that answers
/// [states] in turn (the last one again and again).
class _Android {
  _Android(this.dir);

  final Directory dir;
  int? id;
  String? file;
  List<String> states = ['running', 'successful'];
  bool available = true;
  int _asked = 0;

  Object? answer(MethodCall call) {
    switch (call.method) {
      case 'updatesDir':
        return dir.path;
      case 'install':
        return true;
      case 'startDownload':
        if (!available) {
          throw PlatformException(code: 'UNAVAILABLE');
        }
        id = 7;
        file = (call.arguments as Map)['file'] as String;
        _asked = 0;
        return id;
      case 'pendingDownload':
        return id == null ? null : {'id': id, 'file': file};
      case 'downloadStatus':
        if (id == null) return null;
        final state = states[math.min(_asked++, states.length - 1)];
        final path = '${dir.path}${Platform.pathSeparator}$file';
        if (state == 'successful') {
          File(path).writeAsBytesSync(const [1, 2, 3, 4, 5, 6]);
        }
        return {
          'status': state,
          'bytes': state == 'successful' ? 6 : 3,
          'total': 6,
          'path': path,
        };
      case 'cancelDownload':
        id = null;
        file = null;
        return null;
    }
    return null;
  }
}
