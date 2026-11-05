import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/i18n/i18n.dart';
import 'package:replit/security/developer_mode.dart';
import 'package:replit/theme.dart';

/// A release build opens to a warning while Android's Developer options are
/// on, the way GCash does (the 5 November issue list, 2.1, and issue 1 after
/// it): they are where a fake-GPS app is switched on, and every report needs
/// a real location. Exit closes RepLiT; 911 stays a tap away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceRisk? risk;
  late int asked;
  late int exits;
  late int reports;

  setUp(() {
    risk = DeviceRisk.developerOptions;
    asked = 0;
    exits = 0;
    reports = 0;
    DeveloperMode.enforcedOverride = true;
    DeveloperMode.probeOverride = () async {
      asked++;
      return risk;
    };
    DeveloperMode.exitOverride = () async => exits++;
  });

  tearDown(() {
    DeveloperMode.enforcedOverride = null;
    DeveloperMode.probeOverride = null;
    DeveloperMode.exitOverride = null;
    LanguageChoice.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: DeveloperModeGate(child: child!),
        ),
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => reports++,
              child: const Text('Report a fire'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> comeBack(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  final warning = find.byKey(const ValueKey('developer-mode-warning'));

  testWidgets('with them on, the app opens under a warning it cannot pass', (
    tester,
  ) async {
    await pump(tester);
    expect(warning, findsOneWidget);
    expect(find.text('Developer options are on'), findsOneWidget);
    expect(
      find.text(
        'Our system found settings on this phone that are not secure: '
        'Developer options are on.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ref 02'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
    expect(find.text('In an emergency, call 911'), findsOneWidget);

    // The app opened underneath, but is out of reach.
    expect(find.text('Report a fire'), findsOneWidget);
    await tester.tap(find.text('Report a fire'), warnIfMissed: false);
    expect(reports, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('USB debugging on too: it says so, with its own code', (
    tester,
  ) async {
    risk = DeviceRisk.usbDebugging;
    await pump(tester);
    expect(
      find.text(
        'Our system found settings on this phone that are not secure: '
        'Developer options and USB debugging are on.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ref 03'), findsOneWidget);
  });

  testWidgets('Exit closes RepLiT', (tester) async {
    await pump(tester);
    await tester.tap(find.text('EXIT'));
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('turned off in Settings, the warning is gone on the way back', (
    tester,
  ) async {
    await pump(tester);
    expect(warning, findsOneWidget);

    risk = null;
    await comeBack(tester);
    expect(warning, findsNothing);
    await tester.tap(find.text('Report a fire'));
    expect(reports, 1);
  });

  testWidgets('it looks again each time the app comes back', (tester) async {
    risk = null;
    await pump(tester);
    expect(warning, findsNothing);

    risk = DeviceRisk.developerOptions;
    await comeBack(tester);
    expect(warning, findsOneWidget);
  });

  testWidgets('fits in Tagalog on a small phone with large text', (
    tester,
  ) async {
    LanguageChoice.current.value = AppLanguage.tl;
    risk = DeviceRisk.usbDebugging;
    await pump(tester, size: const Size(320, 640), textScale: 1.5);
    expect(find.text('Naka-on ang Developer options'), findsOneWidget);
    expect(find.text('LUMABAS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a debug build never asks', (tester) async {
    DeveloperMode.enforcedOverride = false;
    await pump(tester);
    expect(asked, 0);
    expect(warning, findsNothing);
  });

  test('under flutter test the real build is not enforced', () {
    DeveloperMode.enforcedOverride = null;
    expect(DeveloperMode.enforced, isFalse);
  });

  group('what counts', () {
    test('Developer options off: nothing, whatever USB debugging says', () {
      expect(
        DeviceRisk.from(developerOptions: false, usbDebugging: false),
        isNull,
      );
      expect(
        DeviceRisk.from(developerOptions: false, usbDebugging: true),
        isNull,
      );
    });

    test('Developer options on: Ref 02, or Ref 03 with USB debugging', () {
      expect(
        DeviceRisk.from(developerOptions: true, usbDebugging: false),
        DeviceRisk.developerOptions,
      );
      expect(
        DeviceRisk.from(developerOptions: true, usbDebugging: true),
        DeviceRisk.usbDebugging,
      );
      expect(DeviceRisk.developerOptions.ref, '02');
      expect(DeviceRisk.usbDebugging.ref, '03');
    });
  });

  group('the phone', () {
    const channel = MethodChannel('replit/device');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];

    setUp(() {
      calls.clear();
      DeveloperMode.probeOverride = null;
      DeveloperMode.exitOverride = null;
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('is asked for both switches', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return {'developerOptions': true, 'usbDebugging': true};
      });
      expect(await DeveloperMode.check(), DeviceRisk.usbDebugging);
      expect(calls, ['deviceSettings']);
    });

    test('that cannot answer counts as off', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'broken');
      });
      expect(await DeveloperMode.check(), isNull);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await DeveloperMode.check(), isNull);
    });

    test('is told to close the app on Exit', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      await DeveloperMode.exit();
      expect(calls, ['exit']);
    });
  });
}
