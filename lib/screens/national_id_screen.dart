import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/coordinator_kit.dart'
    show
        AlertTone,
        IconPlate,
        InlineAlert,
        ListRow,
        ProgressState,
        ProgressStep,
        SectionHeader;
import '../widgets/design.dart';
import '../widgets/app_icons.dart';
import 'id_camera_screen.dart';
import '../i18n/i18n.dart';

/// National ID verification (+50%), as the Figma frames take it (12 November
/// 2026: "the national id verification screen (based on figma) is not
/// consistent in the system itself so fix it based on figma"):
///
/// - "16 · Start": what it takes, then Take ID photo.
/// - "20 · ID front", "20C · ID back" and "20B · Face" ([IdCameraScreen]),
///   one after the other, each chip ticked as its photo is taken.
/// - "20D · Check your photos": each as it was framed; any one retaken
///   without losing the others; Send for review.
/// - "21 · Sent for review".
///
/// Didit's automatic check (16's "Continue to Didit", 17 and 18) has no
/// credits, so every National ID takes the manual path,
/// POST /verification/national-id/manual: an administrator reads the QR code
/// on the card's back on PSA's PhilSys Check, which takes the holder's
/// consent, compares the photos, and awards +50%.
///
/// All three photos are taken with the camera. There is no gallery option,
/// by design: attaching a saved picture is how someone submits an ID that is
/// not theirs, and the whole value of the face photo is that it was taken at
/// the same time as the card.
class NationalIdScreen extends StatefulWidget {
  const NationalIdScreen({super.key, this.api, this.camera, this.percent});

  final ApiClient? api;

  /// Stands in for the phone's camera in a test: the photo asked for in,
  /// its bytes out.
  final Future<Uint8List?> Function(IdShot shot)? camera;

  /// The resident's score now, for "Your score stays at 50% until then".
  final int? percent;

  @override
  State<NationalIdScreen> createState() => _NationalIdScreenState();
}

enum _Stage { start, check, sent }

class _NationalIdScreenState extends State<NationalIdScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  final Map<IdShot, Uint8List> _photos = {};
  _Stage _stage = _Stage.start;
  bool _submitting = false;
  String? _error;

  /// One visit to the camera for [shots], taken in turn in that one screen
  /// (v1.12.43): the photos it took, by shot. Closing it is not an error; a
  /// camera that cannot start says so on its own screen.
  Future<Map<IdShot, Uint8List>> _visit(List<IdShot> shots) async {
    final taken = await Navigator.of(context).push<Map<IdShot, Uint8List>>(
      MaterialPageRoute(
        builder: (_) =>
            IdCameraScreen(shots: shots, taken: _photos.keys.toSet()),
      ),
    );
    return taken ?? const {};
  }

  /// Take one photo again (Retake). Null means they closed the camera.
  Future<Uint8List?> _capture(IdShot shot) async {
    final camera = widget.camera;
    if (camera != null) return camera(shot);
    return (await _visit([shot]))[shot];
  }

  /// Take ID photo: those still missing, in one camera, then Check your
  /// photos (v1.12.43: "the step by step is not seamless": each photo had a
  /// camera of its own, and this screen showed between them). Closing the
  /// camera stops there; what was taken is kept for the next go.
  Future<void> _takePhotos() async {
    final missing = [
      for (final shot in IdShot.values)
        if (!_photos.containsKey(shot)) shot,
    ];
    if (widget.camera != null) {
      for (final shot in missing) {
        final bytes = await _capture(shot);
        if (bytes == null || !mounted) return;
        setState(() => _photos[shot] = bytes);
      }
    } else if (missing.isNotEmpty) {
      final taken = await _visit(missing);
      if (!mounted) return;
      setState(() => _photos.addAll(taken));
      if (_photos.length < IdShot.values.length) return;
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.check;
      _error = null;
    });
  }

  /// Retake replaces only that photo.
  Future<void> _retake(IdShot shot) async {
    final bytes = await _capture(shot);
    if (bytes == null || !mounted) return;
    setState(() {
      _photos[shot] = bytes;
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_submitting || _photos.length < IdShot.values.length) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.submitNationalIdManual(
        idBytes: _photos[IdShot.front]!,
        // The back carries the QR code PSA's PhilSys Check reads.
        qrBytes: _photos[IdShot.back]!,
        selfieBytes: _photos[IdShot.face]!,
      );
      if (!mounted) return;
      setState(() {
        _stage = _Stage.sent;
        // Sent: the photos are the server's now, not this phone's.
        _photos.clear();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t(
            'Could not send. Check your connection and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: switch (_stage) {
          _Stage.start => _start(),
          _Stage.check => _check(),
          _Stage.sent => _sent(),
        },
      ),
    );
  }

  /// "16 · Start", on the manual path: what it takes, then the camera.
  Widget _start() {
    final pal = context.pal;
    return FootedScroll(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
      content: [
        Row(
          children: [
            const BackWell(),
            const SizedBox(width: 16),
            Expanded(
              child: Eyebrow(t('National ID · +50%'), color: pal.accentInk),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(t('VERIFY WITH YOUR ID'), style: context.type.heading1),
        const SizedBox(height: 12),
        Text(
          t(
            'Take three photos with your camera: both sides of your National '
            "ID card, then your face. An admin checks them, and the card's QR "
            "code on PSA's PhilSys Check.",
          ),
          style: context.type.body,
        ),
        const SizedBox(height: 32),
        SectionHeader(t('What you need')),
        const SizedBox(height: 8),
        ListRow(
          title: t('Your National ID card'),
          subtitle: t('Your PhilID card or ePhilID, not a photo of it'),
          leading: const IconPlate(AppIcons.localPolice),
        ),
        const SizedBox(height: 8),
        ListRow(
          title: t('Good light'),
          subtitle: t('Your face and the card clearly visible'),
          leading: const IconPlate(AppIcons.photoCamera),
        ),
        const SizedBox(height: 8),
        ListRow(
          title: t('About two minutes'),
          subtitle: t('You can stop and start again later'),
          leading: const IconPlate(AppIcons.schedule),
        ),
        const SizedBox(height: 16),
        InlineAlert(
          body: t(
            'Verification never blocks a report. It only tells responders '
            'how much weight to give yours.',
          ),
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(t('Take ID photo'), height: 56, onPressed: _takePhotos),
          const SizedBox(height: 12),
          Center(
            child: TextLink(
              t('Not now'),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  /// "20D · Check your photos", with Send for review held at the foot.
  Widget _check() {
    final pal = context.pal;
    return Column(
      children: [
        Expanded(
          // A column, not a lazy list: five children, all of them read.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: BackWell()),
                const SizedBox(height: 20),
                Text(t('CHECK YOUR PHOTOS'), style: context.type.heading1),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Each photo shows exactly what was inside the guide. Retake '
                    'one without losing the others.',
                  ),
                  style: context.type.body,
                ),
                const SizedBox(height: 20),
                for (final shot in IdShot.values) ...[
                  if (shot != IdShot.front) const SizedBox(height: 12),
                  _CapturePreview(
                    shot: shot,
                    bytes: _photos[shot]!,
                    onRetake: _submitting ? null : () => _retake(shot),
                  ),
                ],
                const SizedBox(height: 16),
                InlineAlert(
                  body: t(
                    "Sending them means you agree to an admin checking your "
                    "card's QR code on PSA's PhilSys Check, where PSA records "
                    'the date, your first name and the result. The photos stay '
                    'private and are deleted once it is decided.',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  InlineAlert(
                    tone: AlertTone.danger,
                    title: t('Not sent'),
                    body: _error!,
                  ),
                ],
              ],
            ),
          ),
        ),
        ColoredBox(
          color: pal.background,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                t('Send for review'),
                height: 56,
                busy: _submitting,
                onPressed: _submitting ? null : _send,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "21 · Sent for review".
  Widget _sent() {
    final percent = widget.percent;
    return FootedScroll(
      padding: const EdgeInsets.fromLTRB(24, 66, 24, 28),
      content: [
        Eyebrow(t('National ID · in review'), color: context.pal.warn),
        const SizedBox(height: 16),
        Text(t('SENT FOR REVIEW'), style: context.type.heading1),
        const SizedBox(height: 12),
        Text(
          percent == null
              ? t(
                  "An admin checks your ID and your selfie, with the QR code on "
                  "PSA's PhilSys Check. You'll get a notification when it's "
                  'done. Your score stays as it is until then.',
                )
              : t(
                  "An admin checks your ID and your selfie, with the QR code on "
                  "PSA's PhilSys Check. You'll get a notification when it's "
                  'done. Your score stays at {n}% until then.',
                  {'n': percent},
                ),
          style: context.type.body,
        ),
        const SizedBox(height: 32),
        ProgressStep(
          state: ProgressState.done,
          title: t('Photo of your ID'),
          detail: t('Captured'),
        ),
        const SizedBox(height: 8),
        ProgressStep(
          state: ProgressState.done,
          title: t('Live selfie'),
          detail: t('Captured'),
        ),
        const SizedBox(height: 8),
        ProgressStep(
          state: ProgressState.current,
          title: t('Admin review'),
          detail: t('Waiting for an admin'),
        ),
        const SizedBox(height: 16),
        InlineAlert(
          body: t('Verification never blocks a report. Send one any time.'),
        ),
      ],
      footer: AppButton(
        t('Back to profile'),
        height: 56,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    );
  }
}

/// One photo on Check your photos (Capture preview, 1171:3874): its name and
/// Retake, then exactly what was inside the guide at its own shape, fitted
/// in the dark box and never cropped a second time. The face shows mirrored,
/// as the camera showed it; the file sent is not.
class _CapturePreview extends StatelessWidget {
  const _CapturePreview({
    required this.shot,
    required this.bytes,
    required this.onRetake,
  });

  final IdShot shot;
  final Uint8List bytes;
  final VoidCallback? onRetake;

  static const double _box = 208;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // Smaller than the photo: the back's is a 4K frame.
    final image = Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 1000);
    return Container(
      key: ValueKey('preview-${shot.name}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t(shot.title), style: context.type.listTitle),
              ),
              if (onRetake != null) TextLink(t('Retake'), onTap: onRetake!),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: _box,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: pal.canvas,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: shot.oval
                ? SizedBox(
                    key: ValueKey('framed-${shot.name}'),
                    height: _box,
                    width: _box * shot.aspect,
                    child: ClipOval(
                      child: Transform.flip(flipX: true, child: image),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: AspectRatio(
                      key: ValueKey('framed-${shot.name}'),
                      aspectRatio: shot.aspect,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: image,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            shot.oval
                ? t('Mirrored, as you saw it')
                : t('All four corners should be visible'),
            style: context.type.caption.copyWith(color: pal.label),
          ),
        ],
      ),
    );
  }
}
