import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/incident_map.dart';
import 'sos_report_screen.dart';

/// "Show them" — step 2 of the SOS flow in the v2 hand-off.
///
/// A live preview with the user's current location (reverse-geocoded address
/// plus coordinates) and a mini-map, then the required incident photo. On
/// capture it hands the bytes and GPS to [SosReportScreen].
///
/// The design's "Skip the photo" affordance is not offered: the server rejects
/// a report without one, and the photo is what it cross-references against the
/// device fix. A button that cannot work is worse than no button.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

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

  Position? _position;
  String? _address;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _getLocation();
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
        if (mounted) setState(() => _camError = 'No camera found on this device.');
        return;
      }
      _cameras = cams;
      final back = cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camIndex = back >= 0 ? back : 0;
      await _setController(_camIndex);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _camError = e.description ?? 'Camera permission denied.');
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
      _torch = false;
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
          _camError = e.description ?? 'Could not start the camera.';
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
  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location is off.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission denied.';
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _position = pos);
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {
      // location card will show "Locating..." / unavailable
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;
      final p = placemarks.first;
      final parts = [p.street, p.subLocality, p.locality]
          .where((s) => s != null && s.trim().isNotEmpty)
          .cast<String>()
          .toList();
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
      SnackBar(content: Text(message), backgroundColor: AppColors.live),
    );
  }

  // ------------------------------------------------------------ actions ---
  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    if (_position == null) {
      _toast('Still pinpointing your location — one moment.');
      return;
    }
    setState(() => _capturing = true);
    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      _goToReport(bytes);
    } catch (_) {
      _toast('Could not capture the photo. Try again.');
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
      _toast('Flash is not available on this camera.');
    }
  }

  void _goToReport(List<int> bytes) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SosReportScreen(
          photoBytes: bytes,
          lat: _position!.latitude,
          lng: _position!.longitude,
          accuracyM: _position!.accuracy,
          address: _address,
        ),
      ),
    );
  }

  // ------------------------------------------------------------- build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _previewLayer(),
          // Dark gradient for control legibility, top and bottom.
          const DecoratedBox(
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Eyebrow('Step 2 of 3', color: AppColors.accent),
                            SizedBox(height: 6),
                            Text('SHOW THEM', style: AppText.screenTitle),
                          ],
                        ),
                      ),
                      _miniMap(),
                    ],
                  ),
                ),
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
    final c = _controller;
    if (_camError != null) {
      return _cameraError();
    }
    if (c == null || !_camReady || !c.value.isInitialized || c.value.previewSize == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
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

  Widget _cameraError() {
    return ColoredBox(
      color: AppColors.canvas,
      child: EmptyState(
        icon: Icons.no_photography_outlined,
        tone: AppColors.live,
        title: 'Camera unavailable',
        body: '$_camError\n\nA live photo of the scene is required to send a '
            'report — it is what proves where and when this was taken.',
        action: AppButton.secondary(
          'Retry camera',
          onPressed: () {
            setState(() => _camError = null);
            _initCamera();
          },
        ),
      ),
    );
  }

  Widget _miniMap() {
    return Container(
      width: 92,
      height: 92,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      ),
      child: _position == null
          ? const Center(
              child: Icon(
                Icons.location_searching,
                color: AppColors.muted,
                size: 22,
              ),
            )
          : IgnorePointer(
              child: IncidentMap(
                lat: _position!.latitude,
                lng: _position!.longitude,
                zoom: 16,
              ),
            ),
    );
  }

  Widget _locationCard() {
    final title =
        _address ?? (_locating ? 'Locating you…' : 'Location unavailable');
    return Panel(
      color: AppColors.surfaceSolid.withValues(alpha: 0.92),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const IconWell(
            tint: AppColors.accent,
            icon: Icons.location_on,
            size: 40,
            glyph: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Eyebrow('Geotagged', color: AppColors.accent),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  _coords(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta,
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
        color: AppColors.surfaceSolid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(
            _torch ? Icons.flash_on : Icons.flash_off,
            _toggleFlash,
            active: _torch,
          ),
          _shutter(),
          _circleButton(
            Icons.cameraswitch_outlined,
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
                ? AppColors.accent.withValues(alpha: 0.18)
                : AppColors.glass,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppColors.accent : AppColors.line,
            ),
          ),
          child: Icon(
            icon,
            color: active ? AppColors.accent : AppColors.onBackground,
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
      label: 'Take the photo',
      child: GestureDetector(
        onTap: _capture,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.onBackground.withValues(alpha: 0.9),
              width: 3,
            ),
          ),
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.onBackground,
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
