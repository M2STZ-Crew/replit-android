import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/screens/national_id_screen.dart';
import 'package:replit/theme.dart';

/// The phone's cameras in a test: a back and a front lens, and a log of
/// every camera opened, photo taken and camera closed, in order.
class _Cameras extends CameraPlatform {
  _Cameras(this.photo);

  final Uint8List photo;
  final List<String> log = [];
  final Map<int, StreamController<CameraInitializedEvent>> _ready = {};
  int _next = 0;

  static const _back = CameraDescription(
    name: 'back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );
  static const _front = CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
  );

  /// Cameras open now: Android's plugin has only ever one preview.
  int get open =>
      log.where((e) => e.startsWith('open')).length -
      log.where((e) => e.startsWith('close')).length;

  @override
  Future<List<CameraDescription>> availableCameras() async => [_back, _front];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
    final id = ++_next;
    log.add('open $id ${cameraDescription.name}');
    _ready[id] = StreamController<CameraInitializedEvent>.broadcast();
    return id;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _ready[cameraId]!.stream;

  /// Open and quiet, as a camera without trouble is: never ends.
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    _ready[cameraId]!.add(
      CameraInitializedEvent(
        cameraId,
        1280,
        720,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}

  @override
  Widget buildPreview(int cameraId) =>
      SizedBox.expand(key: ValueKey('preview-$cameraId'));

  @override
  Future<XFile> takePicture(int cameraId) async {
    log.add('photo $cameraId');
    final file = File(
      '${Directory.systemTemp.path}/replit_id_camera_test_$cameraId.png',
    )..writeAsBytesSync(photo);
    return XFile(file.path);
  }

  /// A real camera takes a moment to shut: it is closed once that is done.
  @override
  Future<void> dispose(int cameraId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    log.add('close $cameraId');
  }
}

/// 13 November 2026: "the camera stucks after the front id capturing". The
/// next step's camera opened while the last one was still being closed, and
/// its closing took the new preview with it (Android's camera plugin closes
/// every preview there is). Now each step lets go of its camera first.
void main() {
  late CameraPlatform real;
  late _Cameras cameras;

  setUp(() {
    real = CameraPlatform.instance;
    cameras = _Cameras(
      File('assets/tutorial/practice_photo.png').readAsBytesSync(),
    );
    CameraPlatform.instance = cameras;
  });
  tearDown(() => CameraPlatform.instance = real);

  /// The shutter, then real time for the photo's crop (it runs on another
  /// isolate) and frames for the screens to slide.
  Future<void> shoot(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Take the photo'));
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  // v1.12.43: "the step by step is not seamless". The three photos are taken
  // in one camera screen: the ID's front and back on the same camera, which
  // never closes between them; the face once the back camera is closed in
  // full. The ID screen is not seen until "Check your photos".
  testWidgets('one camera for the three photos: open from the front to the '
      'back, closed before the face', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pushes = _Pushes();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        navigatorObservers: [pushes],
        home: const NationalIdScreen(),
      ),
    );
    await tester.tap(find.text('TAKE ID PHOTO'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(cameras.log, ['open 1 back']);
    expect(find.text('ID FRONT'), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-1')), findsOneWidget);

    // ID front: a tick, then the back's guide on the same live camera.
    await shoot(tester);
    expect(cameras.log, ['open 1 back', 'photo 1']);
    expect(find.text('ID BACK'), findsOneWidget);
    expect(
      find.text('TAKE ID PHOTO'),
      findsNothing,
      reason: 'still the camera',
    );
    expect(find.byKey(const ValueKey('preview-1')), findsOneWidget);

    // ID back, then the face: the back camera closed before the front opens.
    await shoot(tester);
    expect(cameras.log.sublist(2), ['photo 1', 'close 1', 'open 2 front']);
    expect(cameras.open, 1, reason: 'never two cameras at once');
    expect(find.text('YOUR FACE'), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-2')), findsOneWidget);

    // The face, and then "Check your photos": one camera screen for all.
    await shoot(tester);
    expect(cameras.log.sublist(5), ['photo 2', 'close 2']);
    expect(cameras.open, 0, reason: 'no camera left on after the check');
    expect(find.text('CHECK YOUR PHOTOS'), findsOneWidget);
    expect(pushes.count, 1, reason: 'one camera screen for the three photos');
  });

  testWidgets('closed after the front: that photo is kept for the next go', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const NationalIdScreen()),
    );
    await tester.tap(find.text('TAKE ID PHOTO'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await shoot(tester);
    expect(find.text('ID BACK'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(cameras.open, 0);

    // Again: the camera opens on the back, the front already ticked.
    await tester.tap(find.text('TAKE ID PHOTO'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('ID BACK'), findsOneWidget);
    expect(find.text('ID FRONT'), findsNothing);

    // Closed again, and let go of before the test ends.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(cameras.open, 0);
  });

  testWidgets('closing the camera lets go of it at once', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const NationalIdScreen()),
    );
    await tester.tap(find.text('TAKE ID PHOTO'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(cameras.open, 1);

    // Back, before the screen has finished sliding away: already closed.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    // The camera's own 150 ms to shut, well inside the screen's slide.
    await tester.pump(const Duration(milliseconds: 200));
    expect(cameras.log, ['open 1 back', 'close 1']);
    await tester.pumpAndSettle();
  });
}

/// Counts the screens pushed after the first.
class _Pushes extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) count++;
  }
}
