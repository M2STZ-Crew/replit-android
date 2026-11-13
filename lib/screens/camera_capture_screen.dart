import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

import '../diagnostics/report_timing.dart';
import '../location/sos_location.dart';
import '../models/active_report.dart';
import '../theme.dart';
import '../tutorial/lit_lessons.dart';
import '../tutorial/practice.dart';
import '../widgets/design.dart';
import '../widgets/incident_map.dart';
import '../widgets/loading.dart';
import 'sos_report_screen.dart';
import '../widgets/app_icons.dart';
import '../i18n/i18n.dart';
import '../widgets/responsive_frame.dart';

/// A photo taken again from the report screen, with the place it names.
typedef RetakenPhoto = ({List<int> bytes, String? address});

/// "Show them" — step 2 of the SOS flow in the v2 hand-off.
///
/// A live preview with the user's current location (reverse-geocoded address
/// plus coordinates) and a mini-map, then the required incident photo. On
/// capture it hands the bytes to [SosReportScreen].
///
/// The GPS fix is [SosLocation]'s, started when the resident began holding
/// SOS. The shutter no longer waits for it (v10 §6): the fix keeps working
/// while they choose who to call, and only the send waits, if it must.
///
/// The design's "Skip the photo" affordance is not offered: the server rejects
/// a report without one, and the photo is what it cross-references against the
/// device fix. A button that cannot work is worse than no button.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key, this.retake = false});

  /// Opened from the report screen to replace its photo: the capture pops
  /// back with the new one (a [RetakenPhoto]) rather than opening a second
  /// report on top of the first.
  final bool retake;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _camIndex = 0;
  bool _camReady = false;
  String? _camError;
  bool _capturing = false;
  bool _torch = false;

  /// The photo just taken, shown in place of the live view while this
  /// screen gives way to the next: by then its camera is let go of.
  Uint8List? _still;

  final SosLocation _location = SosLocation.instance;
  String? _address;
  Position? _geocodedFor;

  Position? get _position => _location.position.value;

  /// Opened in the LIT tutorial's practice report: the real camera, but the
  /// photo is deleted from the phone as soon as it is read, nothing is
  /// timed, and a drawing can stand in when the camera will not start.
  final bool _practice = Practice.active;

  @override
  void initState() {
    super.initState();
    ReportComposer.enter();
    WidgetsBinding.instance.addObserver(this);
    _location.position.addListener(_onPosition);
    _location.problem.addListener(_onPosition);
    _initCamera();
    if (_practice) Practice.tell(PracticeEvent.cameraOpened);
    // Joins the fix the SOS hold started, or starts one (asking for permission
    // here if it was never granted).
    _location.warmUp();
    _geocodeIfNew();
  }

  @override
  void dispose() {
    ReportComposer.leave();
    WidgetsBinding.instance.removeObserver(this);
    _location.position.removeListener(_onPosition);
    _location.problem.removeListener(_onPosition);
    _controller?.dispose();
    super.dispose();
  }

  void _onPosition() {
    if (!mounted) return;
    setState(() {});
    _geocodeIfNew();
  }

  void _geocodeIfNew() {
    final p = _position;
    if (p != null && !identical(p, _geocodedFor)) {
      _geocodedFor = p;
      _reverseGeocode(p.latitude, p.longitude);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setController(_camIndex);
    }
  }

  // ------------------------------------------------------------ camera ---
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) {
          setState(() => _camError = 'No camera found on this device.');
        }
        return;
      }
      _cameras = cams;
      final back = cams.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _camIndex = back >= 0 ? back : 0;
      await _setController(_camIndex);
    } on CameraException catch (e) {
      if (mounted) {
        setState(
          () => _camError = e.description ?? t('Camera permission denied.'),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _camError = 'Camera unavailable.');
    }
  }

  Future<void> _setController(int index) async {
    final prev = _controller;
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await prev?.dispose();
      await controller.initialize();
      // Let go of while it opened (the photo taken, the screen closed): not
      // this screen's camera any more.
      if (!identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      _torch = false;
      if (!_practice) ReportTiming.instance.mark('camera_ready');
      if (mounted) {
        setState(() {
          _camReady = true;
          _camError = null;
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _camReady = false;
          _camError = e.description ?? t('Could not start the camera.');
        });
      }
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    final current = _cameras[_camIndex].lensDirection;
    final next = _cameras.indexWhere((c) => c.lensDirection != current);
    if (next < 0) return;
    setState(() => _camReady = false);
    _camIndex = next;
    await _setController(next);
  }

  // ---------------------------------------------------------- location ---
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
      ].where((s) => s != null && s.trim().isNotEmpty).cast<String>().toList();
      if (mounted && parts.isNotEmpty) {
        setState(() => _address = parts.take(2).join(', '));
      }
    } catch (_) {
      // address stays null; coordinates are still shown
    }
  }

  String _coords() {
    final p = _position;
    if (p == null) return '—';
    final ns = p.latitude >= 0 ? 'N' : 'S';
    final ew = p.longitude >= 0 ? 'E' : 'W';
    return '${p.latitude.abs().toStringAsFixed(4)}° $ns, '
        '${p.longitude.abs().toStringAsFixed(4)}° $ew';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.pal.live),
    );
  }

  // ------------------------------------------------------------ actions ---
  Future<void> _capture() async {
    if (_capturing) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      // No camera to take it with: in the practice, a drawing will do.
      if (_practice && _camError != null) await _usePracticePhoto();
      return;
    }
    // No waiting on the GPS here any more: the fix finishes while the
    // resident picks who to call, and the send waits for it only if it must.
    setState(() => _capturing = true);
    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      if (_practice) {
        // A practice photo is never kept: only its bytes, for the screens.
        unawaited(_discard(shot.path));
      } else {
        ReportTiming.instance.mark('photo_taken');
      }
      if (!mounted) return;
      // Let go of the camera before the report screen, and a retake from
      // it, open theirs (13 November 2026: the National ID's freeze between
      // steps; the same would catch a quick Retake here).
      await _release(still: bytes);
      if (!mounted) return;
      _goToReport(bytes);
    } catch (_) {
      _toast(t('Could not capture the photo. Try again.'));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final next = _torch ? FlashMode.off : FlashMode.torch;
      await c.setFlashMode(next);
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      _toast(t('Flash is not available on this camera.'));
    }
  }

  void _goToReport(List<int> bytes) {
    if (widget.retake) {
      Navigator.of(
        context,
      ).pop<RetakenPhoto>((bytes: bytes, address: _address));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SosReportScreen(photoBytes: bytes, address: _address),
      ),
    );
  }

  /// Let go of the camera now, not when this screen is gone: the next one
  /// may already be opening its own (Android's camera, closed late, takes
  /// every preview with it). [still] stands in for the live view meanwhile.
  Future<void> _release({Uint8List? still}) async {
    final c = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _camReady = false;
        if (still != null) _still = still;
      });
    }
    await c?.dispose();
  }

  /// The practice photo's file, gone from the phone.
  static Future<void> _discard(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Never written, or already gone: nothing is kept either way.
    }
  }

  /// The practice report on a phone whose camera will not start: a
  /// drawing of a scene in place of the photo, taken with the shutter.
  Future<void> _usePracticePhoto() async {
    setState(() => _capturing = true);
    try {
      final bytes = await Practice.loadSamplePhoto();
      if (mounted) _goToReport(bytes);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) => FullBleed(child: _fullScreen(context));

  /// The screen, filling a tablet (v1.12.43: maps full, the rest
  /// centred).
  Widget _fullScreen(BuildContext context) => PracticeBack(
    child: PopScope(
      // Closed or backed out of: the camera goes now, not after the slide.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_release());
      },
      child: _page(context),
    ),
  );

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _previewLayer(),
          // Dark gradient for control legibility, top and bottom. Only a
          // shade: it took every touch, so "Retry camera" under it could
          // not be pressed.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB3000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xD9000000),
                  ],
                  stops: [0, 0.22, 0.5, 1],
                ),
              ),
            ),
          ),
          if (_camError == null) const _ViewfinderBrackets(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BackWell(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Eyebrow(
                              t('Step 2 of 3'),
                              color: context.pal.accent,
                            ),
                            SizedBox(height: 6),
                            Text(
                              t('SHOW THEM'),
                              style: context.type.screenTitle,
                            ),
                          ],
                        ),
                      ),
                      _miniMap(),
                    ],
                  ),
                ),
                // Without a camera, what went wrong fills the room the
                // viewfinder had, and scrolls in it: behind the location
                // card, a large text size hid its button.
                if (_camError != null)
                  Expanded(child: _cameraErrorRoom())
                else
                  const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                  child: _locationCard(),
                ),
                const SizedBox(height: 14),
                _controls(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewLayer() {
    final still = _still;
    if (still != null) {
      return Image.memory(still, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final c = _controller;
    if (_camError != null) {
      return ColoredBox(color: context.pal.canvas);
    }
    if (c == null ||
        !_camReady ||
        !c.value.isInitialized ||
        c.value.previewSize == null) {
      // The viewfinder's place while the camera starts; dark on either
      // ground, as the viewfinder is.
      return ColoredBox(
        color: Colors.black,
        child: Theme(
          data: buildAppTheme(),
          child: LoadingView(
            label: t('Starting the camera'),
            mark: false,
            scrollable: false,
          ),
        ),
      );
    }
    final preview = c.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  /// The camera's trouble, centred in [_cameraError]'s room, scrolling
  /// when it is taller.
  Widget _cameraErrorRoom() => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: _cameraError(),
      ),
    ),
  );

  Widget _cameraError() {
    return EmptyState(
      icon: AppIcons.noPhotography,
      tone: context.pal.live,
      title: t('Camera unavailable'),
      // In the practice, the shutter takes a drawing instead.
      body: _practice
          ? '$_camError\n\n${t('For practice, tap the shutter to use a '
            'drawing instead.')}'
          : '$_camError\n\n${t('A live photo of the scene is required to '
            'send a report — it is what proves where and when this was '
            'taken.')}',
      action: AppButton.secondary(
        t('Retry camera'),
        onPressed: () {
          setState(() => _camError = null);
          _initCamera();
        },
      ),
    );
  }

  Widget _miniMap() {
    return Container(
      width: 92,
      height: 92,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.pal.canvas,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: context.pal.accent.withValues(alpha: 0.55)),
      ),
      child: _position == null
          ? Center(
              child: Icon(
                AppIcons.locationSearching,
                color: context.pal.muted,
                size: 22,
              ),
            )
          : IgnorePointer(
              child: IncidentMap(
                lat: _position!.latitude,
                lng: _position!.longitude,
                zoom: 16,
                interactive: false,
              ),
            ),
    );
  }

  Widget _locationCard() {
    final problem = _location.problem.value;
    final title =
        _address ??
        (_position != null
            ? t('Location found')
            : problem != null
            ? t('Location needed')
            : t('Locating you…'));
    return Panel(
      // A tap retries when the fix failed (location off, permission denied).
      onTap: problem != null ? () => _location.warmUp() : null,
      color: context.pal.surfaceSolid.withValues(alpha: 0.92),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          IconWell(
            tint: context.pal.accent,
            icon: AppIcons.locationOn,
            size: 40,
            glyph: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow(t('Geotagged'), color: context.pal.accent),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  _position == null && problem != null
                      ? '$problem Tap to retry.'
                      : _coords(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.meta.copyWith(
                    color: _position == null && problem != null
                        ? context.pal.live
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: context.pal.surfaceSolid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        border: Border.all(color: context.pal.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(
            _torch ? AppIcons.flashOn : AppIcons.flashOff,
            _toggleFlash,
            active: _torch,
          ),
          // What the LIT tutorial lights for its photo.
          PracticeTarget(
            id: LitTargets.shutter,
            round: true,
            child: _shutter(),
          ),
          _circleButton(
            AppIcons.cameraswitch,
            _cameras.length < 2 ? null : _flip,
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    IconData icon,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: active
                ? context.pal.accent.withValues(alpha: 0.18)
                : context.pal.glass,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? context.pal.accent : context.pal.line,
            ),
          ),
          child: Icon(
            icon,
            color: active ? context.pal.accent : context.pal.onBackground,
            size: 21,
          ),
        ),
      ),
    );
  }

  /// The design's shutter: a white ring around a white disc. It reads as a
  /// camera control, not another SOS button — which matters, because the two
  /// sit two taps apart.
  Widget _shutter() {
    return Semantics(
      button: true,
      label: t('Take the photo'),
      child: GestureDetector(
        onTap: _capture,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.pal.onBackground.withValues(alpha: 0.9),
              width: 3,
            ),
          ),
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.pal.onBackground,
              shape: BoxShape.circle,
            ),
            child: _capturing
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.accentText,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// The design's four corner brackets over the viewfinder — the cue that this
/// frame is the evidence, not a snapshot.
class _ViewfinderBrackets extends StatelessWidget {
  const _ViewfinderBrackets();

  @override
  Widget build(BuildContext context) {
    const stroke = BorderSide(color: Color(0xE6FF9066), width: 2);

    Widget corner(Alignment alignment) => Align(
      alignment: alignment,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border(
            left: alignment.x < 0 ? stroke : BorderSide.none,
            right: alignment.x > 0 ? stroke : BorderSide.none,
            top: alignment.y < 0 ? stroke : BorderSide.none,
            bottom: alignment.y > 0 ? stroke : BorderSide.none,
          ),
        ),
      ),
    );

    return IgnorePointer(
      child: Padding(
        // Clear of the header above and the controls below.
        padding: const EdgeInsets.fromLTRB(30, 150, 30, 230),
        child: Stack(
          children: [
            corner(Alignment.topLeft),
            corner(Alignment.topRight),
            corner(Alignment.bottomLeft),
            corner(Alignment.bottomRight),
          ],
        ),
      ),
    );
  }
}
