import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:image/image.dart' as img;

/// The National ID photos, cut to the frame the resident filled.
///
/// The camera screen holds up a guide — the card's shape, a square for the QR
/// code, an oval for the face — over a viewfinder that fills the screen. The
/// shutter, though, saves the whole sensor frame: far more than the guide, and
/// a different shape from the screen. Shown in the form's preview tiles with
/// `BoxFit.cover`, that frame was cut a second time to the tile's own shape, so
/// the card someone had lined up inside the box came back off-centre, cropped,
/// or small in a sea of table top (the 5 November issue list, 1.7).
///
/// [guideInPhoto] finds the guide's rectangle in the photo, and [cropToGuide]
/// keeps only that, with a small [margin] so an edge drawn right on the
/// guide's line is not lost. The tile then shows the result in the guide's own
/// shape, and the reviewer sees what the resident framed.
abstract final class GuideCrop {
  /// Extra room kept around the guide, as a share of its width and height on
  /// each side: the guide's 2 px line sits a little inside what it frames.
  static const double margin = 0.05;

  /// Where [guide] (in viewfinder coordinates) falls in a photo of [photo]
  /// pixels, when the viewfinder of [screen] shows a camera preview of
  /// [preview] (both portrait) scaled to cover it, as `BoxFit.cover` does.
  ///
  /// The photo and the preview come from the same sensor about the same
  /// centre. When their shapes differ — a 3:4 photo behind a 9:16 preview is
  /// usual — the preview is the narrower cut of the two, so the photo shows
  /// more on the sides that differ.
  static Rect guideInPhoto({
    required Size screen,
    required Rect guide,
    required Size preview,
    required Size photo,
    double margin = GuideCrop.margin,
  }) {
    // Viewfinder → preview, as a share of the preview's width and height.
    final scale = math.max(
      screen.width / preview.width,
      screen.height / preview.height,
    );
    final shown = Size(preview.width * scale, preview.height * scale);
    final dx = (screen.width - shown.width) / 2;
    final dy = (screen.height - shown.height) / 2;
    var left = (guide.left - dx) / shown.width;
    var right = (guide.right - dx) / shown.width;
    var top = (guide.top - dy) / shown.height;
    var bottom = (guide.bottom - dy) / shown.height;

    // Preview → photo, about the shared centre.
    final previewAspect = preview.width / preview.height;
    final photoAspect = photo.width / photo.height;
    if (photoAspect > previewAspect) {
      // The photo is wider: the preview is its middle strip, side to side.
      final k = previewAspect / photoAspect;
      left = 0.5 + (left - 0.5) * k;
      right = 0.5 + (right - 0.5) * k;
    } else if (photoAspect < previewAspect) {
      // The photo is taller: the preview is its middle band, top to bottom.
      final k = photoAspect / previewAspect;
      top = 0.5 + (top - 0.5) * k;
      bottom = 0.5 + (bottom - 0.5) * k;
    }

    // The margin, then never past the photo's edge.
    final padX = (right - left) * margin;
    final padY = (bottom - top) * margin;
    left = (left - padX).clamp(0.0, 1.0);
    right = (right + padX).clamp(0.0, 1.0);
    top = (top - padY).clamp(0.0, 1.0);
    bottom = (bottom + padY).clamp(0.0, 1.0);

    return Rect.fromLTRB(
      left * photo.width,
      top * photo.height,
      right * photo.width,
      bottom * photo.height,
    );
  }

  /// [jpeg] cut to [guide], off the UI thread.
  ///
  /// The photo is turned upright first (phones save it sideways with an EXIF
  /// note saying so), so the guide is measured against what the resident saw.
  /// If anything goes wrong — a format the decoder does not know, a degenerate
  /// rectangle — the photo is returned whole rather than lost: a full frame
  /// the reviewer can still read beats a retake.
  static Future<Uint8List> cropToGuide(
    Uint8List jpeg, {
    required Size screen,
    required Rect guide,
    required Size preview,
    int quality = 92,
  }) {
    final args = (jpeg, screen, guide, preview, quality);
    return Isolate.run(() => _crop(args));
  }

  static Uint8List _crop((Uint8List, Size, Rect, Size, int) args) {
    final (jpeg, screen, guide, preview, quality) = args;
    try {
      final decoded = img.decodeJpg(jpeg);
      if (decoded == null) return jpeg;
      final upright = img.bakeOrientation(decoded);
      final cut = guideInPhoto(
        screen: screen,
        guide: guide,
        preview: preview,
        photo: Size(upright.width.toDouble(), upright.height.toDouble()),
      );
      final x = cut.left.floor();
      final y = cut.top.floor();
      final w = math.min(cut.width.ceil(), upright.width - x);
      final h = math.min(cut.height.ceil(), upright.height - y);
      if (w < 16 || h < 16) return jpeg;
      final cropped = img.copyCrop(upright, x: x, y: y, width: w, height: h);
      return img.encodeJpg(cropped, quality: quality);
    } catch (_) {
      return jpeg;
    }
  }
}
