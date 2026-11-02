import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../widgets/map_glass.dart';

/// One photo of the National ID check: what the screen says and the frame it
/// holds up. The sizes are the design's, on its 402 px wide phone.
enum IdShot {
  /// "20 National ID · ID photo" (460:4632).
  card(
    title: 'Photo of your ID',
    step: 'Step 1 of 3',
    hint: 'Fit the whole card inside the frame. Avoid glare.',
    guide: Size(330, 208),
    radius: 16,
    lens: CameraLensDirection.back,
    resolution: ResolutionPreset.veryHigh,
  ),

  /// Not in Figma, which predates PhilSys Check: frame 20 with a square guide.
  /// It keeps the most detail: PSA's reader needs every square of the code,
  /// and an ePhilID's are small.
  qr(
    title: 'Photo of your QR',
    step: 'Step 2 of 3',
    hint:
        'Fit the whole QR code inside the frame. It is on the back of the '
        'card.',
    guide: Size(260, 260),
    radius: 16,
    lens: CameraLensDirection.back,
    resolution: ResolutionPreset.ultraHigh,
  ),

  /// "20B National ID · Selfie" (464:1209).
  selfie(
    title: 'Live selfie',
    step: 'Step 3 of 3',
    hint: 'Look straight at the camera. Remove glasses or a cap if you can.',
    guide: Size(240, 300),
    radius: 120,
    lens: CameraLensDirection.front,
    resolution: ResolutionPreset.veryHigh,
  );

  const IdShot({
    required this.title,
    required this.step,
    required this.hint,
    required this.guide,
    required this.radius,
    required this.lens,
    required this.resolution,
  });

  final String title;
  final String step;
  final String hint;
  final Size guide;
  final double radius;
  final CameraLensDirection lens;
  final ResolutionPreset resolution;

  /// Room the guide leaves above and below: the header, then the shutter and
  /// its note. Two lines of hint sit under the guide.
  static const double _clearTop = 116;
  static const double _clearBottom = 164;
  static const double hintGap = 16;
  static const double _hintRoom = hintGap + 36;

  /// Where the guide sits on [screen], at the design's size where it fits and
  /// smaller on a phone that has less room.
  RRect guideIn(Size screen, EdgeInsets safe) {
    final top = safe.top + _clearTop;
    final bottom = screen.height - safe.bottom - _clearBottom;
    final room = math.max(bottom - top - _hintRoom, 120.0);
    final scale = math.min(
      1.0,
      math.min((screen.width - 72) / guide.width, room / guide.height),
    );
    final width = guide.width * scale;
    final height = guide.height * scale;
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (screen.width - width) / 2,
        top + (room - height) / 2,
        width,
        height,
      ),
      Radius.circular(radius * scale),
    );
  }
}

/// The National ID camera: "20 National ID · ID photo" and "20B · Selfie".
///
/// Pops with the JPEG, or with nothing when closed. It is an in-app camera so
/// that the photo is live: there is no gallery here to reach for, which a
/// phone's own camera app offers one tap away.
///
/// A viewfinder stays dark on the light ground too, so the screen always
/// draws from the dark palette.
class IdCameraScreen extends StatelessWidget {
  const IdCameraScreen({super.key, required this.shot, this.preview});

  final IdShot shot;

  /// Stands in for the live camera in a test.
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAppTheme(),
      child: _IdCamera(shot: shot, preview: preview),
    );
  }
}

class _IdCamera extends StatefulWidget {
  const _IdCamera({required this.shot, this.preview});

  final IdShot shot;
  final Widget? preview;

  @override
  State<_IdCamera> createState() => _IdCameraState();
}

class _IdCameraState extends State<_IdCamera> with WidgetsBindingObserver {
  CameraDescription? _lens;
  CameraController? _controller;
  bool _ready = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.preview == null) _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      setState(() => _ready = false);
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _open();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('No camera found on this device.');
        return;
      }
      _lens = cameras.firstWhere(
        (c) => c.lensDirection == widget.shot.lens,
        orElse: () => cameras.first,
      );
      await _open();
    } on CameraException catch (e) {
      _fail(e.description ?? 'Camera permission denied.');
    } catch (_) {
      _fail('The camera could not start.');
    }
  }

  Future<void> _open() async {
    final controller = CameraController(
      _lens!,
      widget.shot.resolution,
      enableAudio: false,
    );
    final previous = _controller;
    _controller = controller;
    try {
      await previous?.dispose();
      await controller.initialize();
      try {
        // A flash on a laminated card is the glare the screen warns about.
        await controller.setFlashMode(FlashMode.off);
      } on CameraException catch (_) {
        // This lens has no flash to turn off.
      }
      if (mounted) {
        setState(() {
          _ready = true;
          _error = null;
        });
      }
    } on CameraException catch (e) {
      _fail(e.description ?? 'Could not start the camera.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _ready = false;
      _error = message;
    });
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      try {
        // The plugin leaves the file in the cache, and this one is an ID.
        await File(shot.path).delete();
      } on FileSystemException catch (_) {
        // Already gone.
      }
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not take the photo. Try again.'),
          backgroundColor: context.pal.live,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.canvas,
      body: LayoutBuilder(builder: _layout),
    );
  }

  Widget _layout(BuildContext context, BoxConstraints box) {
    final pal = context.pal;
    final shot = widget.shot;
    final guide = shot.guideIn(box.biggest, MediaQuery.paddingOf(context));
    final live = _error == null;
    return Stack(
      fit: StackFit.expand,
      children: [
        _previewLayer(),
        if (live) ...[
          CustomPaint(
            painter: _GuidePainter(
              guide: guide,
              scrim: pal.scrim,
              edge: pal.accent,
            ),
          ),
          Positioned(
            top: guide.bottom + IdShot.hintGap,
            left: 51,
            right: 51,
            child: Text(
              shot.hint,
              textAlign: TextAlign.center,
              style: context.type.bodySm.copyWith(color: pal.textSoft),
            ),
          ),
        ],
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                child: _header(),
              ),
              const Spacer(),
              if (live) ...[
                _Shutter(busy: _capturing, onTap: _ready ? _capture : null),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 41),
                  child: Text(
                    "Camera only — photos from your gallery aren't accepted.",
                    textAlign: TextAlign.center,
                    style: context.type.caption.copyWith(color: pal.label),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Stack(
      children: [
        // The words set the header's height, so large text grows it.
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 12, 56, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.shot.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.headline,
                ),
                const SizedBox(height: 8),
                Eyebrow(widget.shot.step, color: context.pal.label),
              ],
            ),
          ),
        ),
        const _CloseCamera(),
      ],
    );
  }

  Widget _previewLayer() {
    final stand = widget.preview;
    if (stand != null) return stand;
    if (_error != null) return _cameraError();
    final c = _controller;
    if (c == null ||
        !_ready ||
        !c.value.isInitialized ||
        c.value.previewSize == null) {
      return ColoredBox(
        color: context.pal.canvas,
        child: Center(
          child: CircularProgressIndicator(color: context.pal.accent),
        ),
      );
    }
    final size = c.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  Widget _cameraError() {
    return EmptyState(
      icon: AppIcons.noPhotography,
      tone: context.pal.live,
      title: 'Camera unavailable',
      body:
          '$_error\n\nA live photo is required: saved pictures are not '
          'accepted for your National ID.',
      action: AppButton.secondary(
        'Retry camera',
        onPressed: () {
          setState(() => _error = null);
          _start();
        },
      ),
    );
  }
}

/// Darkens the viewfinder around the guide, so the words stay readable over
/// any scene, and draws the guide's 2 px edge.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.guide,
    required this.scrim,
    required this.edge,
  });

  final RRect guide;
  final Color scrim;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(guide),
      Paint()..color = scrim,
    );
    canvas.drawRRect(
      guide.deflate(1),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.guide != guide || old.scrim != scrim || old.edge != edge;
}

/// "Close camera": the Icon button's Overlay style, translucent with a blur.
class _CloseCamera extends StatelessWidget {
  const _CloseCamera();

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadius.control);
    final button = Material(
      color: AppColors.glassOverlay,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: context.pal.line),
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.close,
            size: 24,
            color: context.pal.onBackground,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: 'Close camera',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: shape,
        child: MapGlass.blurs(context)
            ? BackdropFilter(filter: MapGlass.blur, child: button)
            : button,
      ),
    );
  }
}

/// The design's 76 px shutter: a 4 px ring around a 60 px disc.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final white = context.pal.onBackground;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Take the photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.38 : 1,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: white, width: 4),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: white, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.accentText,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
