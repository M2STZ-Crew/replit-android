import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../verification/guide_crop.dart';
import '../widgets/app_icons.dart';
import '../widgets/design.dart';
import '../widgets/map_glass.dart';
import '../widgets/loading.dart';
import '../i18n/i18n.dart';

/// One photo of the National ID check, in the order they are taken: what the
/// screen says and the guide it holds up (Figma 20, 20C and 20B).
enum IdShot {
  /// "20 National ID · ID front" (460:4632).
  front(
    title: 'ID front',
    step: 'Step 1 of 3',
    hint: 'Fit all four corners of the card inside the frame.',
    oval: false,
    lens: CameraLensDirection.back,
    resolution: ResolutionPreset.veryHigh,
  ),

  /// "20C National ID · ID back" (1177:1673). The back carries the QR code
  /// the administrator reads on PSA's PhilSys Check, so it keeps the most
  /// detail: the reader needs every square of the code.
  back(
    title: 'ID back',
    step: 'Step 2 of 3',
    hint: 'Turn the card over. Fit all four corners inside the frame.',
    oval: false,
    lens: CameraLensDirection.back,
    resolution: ResolutionPreset.ultraHigh,
  ),

  /// "20B National ID · Face" (464:1209).
  face(
    title: 'Your face',
    step: 'Step 3 of 3',
    hint: 'Keep your face inside the oval. Look straight at the camera.',
    oval: true,
    lens: CameraLensDirection.front,
    resolution: ResolutionPreset.veryHigh,
  );

  const IdShot({
    required this.title,
    required this.step,
    required this.hint,
    required this.oval,
    required this.lens,
    required this.resolution,
  });

  /// The photo's name: the screen's title, and its chip and card after.
  final String title;
  final String step;
  final String hint;

  /// The face oval, rather than the card's frame.
  final bool oval;
  final CameraLensDirection lens;
  final ResolutionPreset resolution;

  /// The guide's width to its height (Capture guide, 1171:3772): an ID-1
  /// card, 1.586 : 1, and the face oval, 4 : 5.
  double get aspect => oval ? 0.8 : 1.586;

  /// Room the guide leaves above and below: the header with its chips, then
  /// the shutter and its note. Two lines of hint sit under the guide.
  static const double _clearTop = 118;
  static const double _clearBottom = 140;
  static const double hintGap = 16;
  static const double _hintRoom = hintGap + 36;

  /// Where the guide sits on [screen] (Capture guide): the card the screen's
  /// width less 36 each side (330 × 208 on the 402 frame, 288 × 182 at 360,
  /// 358 × 226 at 430), the oval 240 × 300 or 60% of the width when that is
  /// narrower; centred between the header and the shutter, and smaller on a
  /// phone without the height for it.
  Rect guideIn(Size screen, EdgeInsets safe) {
    final top = safe.top + _clearTop;
    final bottom = screen.height - safe.bottom - _clearBottom;
    final room = math.max(bottom - top - _hintRoom, 120.0);
    var width = oval ? math.min(240.0, screen.width * 0.6) : screen.width - 72;
    var height = width / aspect;
    if (height > room) {
      height = room;
      width = height * aspect;
    }
    return Rect.fromLTWH(
      (screen.width - width) / 2,
      top + (room - height) / 2,
      width,
      height,
    );
  }
}

/// The National ID camera: "20 · ID front", "20C · ID back", "20B · Face".
///
/// Pops with the JPEG cut to the guide (see [GuideCrop]) — what the resident
/// framed, not the whole sensor frame — or with nothing when closed. It is an in-app camera so
/// that the photo is live: there is no gallery here to reach for, which a
/// phone's own camera app offers one tap away.
///
/// A viewfinder stays dark on the light ground too, so the screen always
/// draws from the dark palette.
class IdCameraScreen extends StatelessWidget {
  const IdCameraScreen({
    super.key,
    required this.shot,
    this.taken = const {},
    this.preview,
  });

  final IdShot shot;

  /// The photos already taken, ticked in the chips under the title.
  final Set<IdShot> taken;

  /// Stands in for the live camera in a test.
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAppTheme(),
      child: _IdCamera(shot: shot, taken: taken, preview: preview),
    );
  }
}

class _IdCamera extends StatefulWidget {
  const _IdCamera({required this.shot, required this.taken, this.preview});

  final IdShot shot;
  final Set<IdShot> taken;
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

  /// The viewfinder and the guide on it, as last laid out: what the shutter
  /// measures the photo against.
  Size? _viewfinder;
  Rect? _guide;

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
        _fail(t('No camera found on this device.'));
        return;
      }
      _lens = cameras.firstWhere(
        (c) => c.lensDirection == widget.shot.lens,
        orElse: () => cameras.first,
      );
      await _open();
    } on CameraException catch (e) {
      _fail(e.description ?? t('Camera permission denied.'));
    } catch (_) {
      _fail(t('The camera could not start.'));
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
      _fail(e.description ?? t('Could not start the camera.'));
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
      var bytes = await shot.readAsBytes();
      try {
        // The plugin leaves the file in the cache, and this one is an ID.
        await File(shot.path).delete();
      } on FileSystemException catch (_) {
        // Already gone.
      }
      // Keep what was inside the guide. The preview is laid out portrait,
      // as [_previewLayer] draws it.
      final preview = c.value.previewSize;
      final viewfinder = _viewfinder;
      final guide = _guide;
      if (preview != null && viewfinder != null && guide != null) {
        bytes = await GuideCrop.cropToGuide(
          bytes,
          screen: viewfinder,
          guide: guide,
          preview: Size(preview.height, preview.width),
        );
      }
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Could not take the photo. Try again.')),
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
    _viewfinder = box.biggest;
    _guide = guide;
    final live = _error == null;
    return Stack(
      fit: StackFit.expand,
      children: [
        _previewLayer(),
        if (live) ...[
          CustomPaint(
            painter: _GuidePainter(
              guide: guide,
              oval: shot.oval,
              scrim: pal.scrim,
              edge: pal.accent,
            ),
          ),
          Positioned(
            top: guide.bottom + IdShot.hintGap,
            left: 24,
            right: 24,
            child: Text(
              t(shot.hint),
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
                    t(
                      "Camera only — photos from your gallery aren't accepted.",
                    ),
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
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Text(
                    t(widget.shot.title).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.headline,
                  ),
                ),
                const SizedBox(height: 8),
                Eyebrow(t(widget.shot.step), color: context.pal.label),
                const SizedBox(height: 16),
                _CaptureSlots(current: widget.shot, taken: widget.taken),
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
        child: LoadingView(
          label: t('Starting the camera'),
          mark: false,
          scrollable: false,
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
      title: t('Camera unavailable'),
      body:
          '$_error\n\n${t('A live photo is required: saved pictures are not '
          'accepted for your National ID.')}',
      action: AppButton.secondary(
        t('Retry camera'),
        onPressed: () {
          setState(() => _error = null);
          _start();
        },
      ),
    );
  }
}

/// Darkens the viewfinder around the guide, so the words stay readable over
/// any scene, and draws the guide (Capture guide): the card's four coral
/// corners, 28 long and 4 thick, or the face oval's coral edge.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.guide,
    required this.oval,
    required this.scrim,
    required this.edge,
  });

  final Rect guide;
  final bool oval;
  final Color scrim;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Path();
    if (oval) {
      hole.addOval(guide);
    } else {
      hole.addRect(guide);
    }
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addPath(hole, Offset.zero),
      Paint()..color = scrim,
    );
    final paint = Paint()..color = edge;
    if (oval) {
      canvas.drawOval(
        guide.deflate(1),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }
    const long = 28.0;
    const thick = 4.0;
    const round = Radius.circular(2);
    void bar(double left, double top, double width, double height) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, width, height),
            round,
          ),
          paint,
        );
    final g = guide;
    for (final (x, y, dx, dy) in [
      (g.left, g.top, 0.0, 0.0),
      (g.right, g.top, -1.0, 0.0),
      (g.left, g.bottom, 0.0, -1.0),
      (g.right, g.bottom, -1.0, -1.0),
    ]) {
      bar(x + dx * long, y + dy * thick, long, thick);
      bar(x + dx * thick, y + dy * long, thick, long);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.guide != guide ||
      old.oval != oval ||
      old.scrim != scrim ||
      old.edge != edge;
}

/// The three photos as chips under the title (Capture slots): ticked green
/// once taken, coral for the one being taken, glass for the ones to come.
class _CaptureSlots extends StatelessWidget {
  const _CaptureSlots({required this.current, required this.taken});

  final IdShot current;
  final Set<IdShot> taken;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final shot in IdShot.values)
          if (shot == current)
            _slot(
              context,
              shot,
              fill: pal.accent.withValues(alpha: 0.16),
              edge: pal.accent,
              ink: pal.accent,
            )
          else if (taken.contains(shot))
            _slot(
              context,
              shot,
              fill: pal.statusTint(pal.ok),
              ink: pal.ok,
              done: true,
            )
          else
            _slot(
              context,
              shot,
              fill: AppColors.glassOverlay,
              ink: pal.textSoft,
            ),
      ],
    );
  }

  Widget _slot(
    BuildContext context,
    IdShot shot, {
    required Color fill,
    required Color ink,
    Color? edge,
    bool done = false,
  }) {
    final name = t(shot.title);
    return Semantics(
      label: done
          ? t('{photo}, taken', {'photo': name})
          : shot == current
          ? t('{photo}, now', {'photo': name})
          : name,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: edge == null ? null : Border.all(color: edge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              Icon(AppIcons.check, size: 12, color: ink),
              const SizedBox(width: 4),
            ],
            Text(name, style: context.type.tag.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
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
      label: t('Close camera'),
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
      label: t('Take the photo'),
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
