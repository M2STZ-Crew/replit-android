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

  testWidgets('each step lets go of its camera before the next opens one', (
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
    expect(cameras.log, ['open 1 back']);
    expect(find.byKey(const ValueKey('preview-1')), findsOneWidget);

    // ID front: its camera is closed before the back's is opened.
    await shoot(tester);
    expect(cameras.log, ['open 1 back', 'photo 1', 'close 1', 'open 2 back']);
    expect(cameras.open, 1, reason: 'never two cameras at once');
    expect(find.text('ID BACK'), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-2')), findsOneWidget);

    // ID back, then the face on the front lens.
    await shoot(tester);
    expect(cameras.log.sublist(4), ['photo 2', 'close 2', 'open 3 front']);
    expect(cameras.open, 1);
    expect(find.text('YOUR FACE'), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-3')), findsOneWidget);

    await shoot(tester);
    expect(cameras.log.sublist(7), ['photo 3', 'close 3']);
    expect(cameras.open, 0, reason: 'no camera left on after the check');
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
