import 'package:flutter/material.dart';

/// A reported photo, full screen, to be looked at closely before deciding.
///
/// Pinch to zoom (up to 6x), drag to look around once zoomed, double-tap to
/// jump in on a spot and again to come back out, and the close button (or
/// Back) to return to the incident. The photo is only displayed: nothing here
/// changes, crops or re-uploads the original.
Future<void> openPhoto(BuildContext context, String url, {String? label}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => PhotoViewer(url: url, label: label),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.url, this.label});

  final String url;

  /// What the photo is, for screen readers ("Report photo").
  final String? label;

  static const double maxZoom = 6;
  static const double doubleTapZoom = 2.5;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _zoom = TransformationController();
  // Made in initState, not lazily: a lazy controller first created in dispose
  // (closing before any double-tap) would ask for a ticker from a dead element.
  late final AnimationController _animation;
  Matrix4Tween? _tween;
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_step);
  }

  @override
  void dispose() {
    _animation.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _step() {
    final tween = _tween;
    if (tween != null) _zoom.value = tween.evaluate(_animation);
  }

  bool get _zoomedIn => _zoom.value.getMaxScaleOnAxis() > 1.01;

  /// Double-tap: zoom in on the spot tapped, or back out if already in.
  void _toggleZoom() {
    final Matrix4 target;
    if (_zoomedIn) {
      target = Matrix4.identity();
    } else {
      const s = PhotoViewer.doubleTapZoom;
      target = Matrix4.identity()
        ..translateByDouble(-_tapAt.dx * (s - 1), -_tapAt.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    _tween = Matrix4Tween(begin: _zoom.value, end: target);
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (d) => _tapAt = d.localPosition,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _zoom,
                minScale: 1,
                maxScale: PhotoViewer.maxZoom,
                child: Center(
                  child: Semantics(
                    image: true,
                    label: widget.label ?? 'Report photo',
                    child: Image.network(
                      widget.url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                      errorBuilder: (context, error, stack) => const Center(
                        child: Text(
                          'The photo could not be loaded.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: _RoundButton(
                  icon: Icons.close,
                  label: 'Close photo',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          // At the foot, where it covers the least of the photo and has the
          // width to fit at any font size.
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(child: _Hint()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Pinch or double-tap to zoom',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
