import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/coordinator_kit.dart' show CheckRow;
import '../widgets/design.dart';
import '../widgets/app_icons.dart';

Color _safeGreen = AppColors.ok;

/// National ID verification (+50%) via the manual-review path.
///
/// The backend's Didit auto-KYC has no credits, so this uses
/// POST /verification/national-id/manual: the user supplies a photo of their
/// PhilID or ePhilID, its QR code and a matching selfie. An administrator runs
/// the QR code through PSA's PhilSys Check, which takes the holder's consent,
/// compares the result with the other two, and awards +50%.
///
/// All three images must be taken with the camera. There is no gallery option,
/// by design: attaching a saved picture is how someone submits an ID that
/// is not theirs, and the whole value of the selfie is that it was taken at
/// the same time as the document.
class NationalIdScreen extends StatefulWidget {
  const NationalIdScreen({super.key, this.api, this.camera});

  final ApiClient? api;

  /// Stands in for the phone's camera in a test.
  final Future<Uint8List?> Function()? camera;

  @override
  State<NationalIdScreen> createState() => _NationalIdScreenState();
}

class _NationalIdScreenState extends State<NationalIdScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _idBytes;
  Uint8List? _qrBytes;
  Uint8List? _selfieBytes;
  bool _consent = false;
  bool _submitting = false;
  String? _error;

  bool get _ready =>
      _idBytes != null && _qrBytes != null && _selfieBytes != null && _consent;

  /// Take one photo with the camera.
  ///
  /// Deliberately camera-only: there is no gallery option on either slot.
  /// Letting someone attach a saved picture makes it trivial to submit an ID
  /// that is not theirs — a screenshot of somebody else's card, or a photo
  /// lifted off social media. Requiring a live capture forces them to at least
  /// physically hold the document, which is the whole point of asking for a
  /// matching selfie alongside it.
  ///
  /// [front] opens the selfie lens.
  ///
  /// Capped at 1600px and 70% quality: an ID has to stay legible enough for an
  /// administrator to read, but a full-resolution phone photo is several
  /// megabytes of upload over mobile data. [qr] keeps more: PhilSys Check has
  /// to read every square of the code, and an ePhilID's are small.
  Future<Uint8List?> _capture({bool front = false, bool qr = false}) async {
    final camera = widget.camera;
    if (camera != null) return camera();
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
        imageQuality: qr ? 90 : 70,
        maxWidth: qr ? 2000 : 1600,
      );
      if (shot == null) return null; // backed out — not an error
      return shot.readAsBytes();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open the camera. Check the app permissions in your '
              'phone settings.',
        );
      }
      return null;
    }
  }

  Future<void> _pickId() async {
    final bytes = await _capture();
    if (bytes == null || !mounted) return;
    setState(() {
      _idBytes = bytes;
      _error = null;
    });
  }

  Future<void> _pickQr() async {
    final bytes = await _capture(qr: true);
    if (bytes == null || !mounted) return;
    setState(() {
      _qrBytes = bytes;
      _error = null;
    });
  }

  Future<void> _pickSelfie() async {
    final bytes = await _capture(front: true);
    if (bytes == null || !mounted) return;
    setState(() {
      _selfieBytes = bytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.submitNationalIdManual(
        idBytes: _idBytes!,
        qrBytes: _qrBytes!,
        selfieBytes: _selfieBytes!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submitted for review. An admin will award +50% once approved.',
          ),
          backgroundColor: _safeGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not submit. Check your connection and try again.',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 26),
              IconWell(
                tint: context.pal.accent,
                icon: AppIcons.badge,
                size: 56,
                glyph: 28,
              ),
              const SizedBox(height: 18),
              Text('VERIFY YOUR IDENTITY', style: context.type.title),
              const SizedBox(height: 10),
              Text(
                'Photograph your PhilID card or ePhilID and its QR code, then '
                'take a matching selfie. All three must be taken now with the '
                'camera — saved pictures are not accepted. An administrator '
                "checks the QR code on PSA's PhilSys Check and awards +50%.",
                style: context.type.body,
              ),
              const SizedBox(height: 26),
              _uploadSlot(
                label: 'National ID',
                hint: 'Tap to photograph the side with your picture',
                icon: AppIcons.badge,
                bytes: _idBytes,
                onTap: _pickId,
              ),
              const SizedBox(height: 12),
              _uploadSlot(
                label: 'QR code',
                hint: 'On the back of the card. Fill the photo with it.',
                icon: AppIcons.photoCamera,
                bytes: _qrBytes,
                onTap: _pickQr,
              ),
              const SizedBox(height: 12),
              _uploadSlot(
                label: 'Selfie',
                hint: 'Tap to take a selfie',
                icon: AppIcons.face,
                bytes: _selfieBytes,
                onTap: _pickSelfie,
              ),
              const SizedBox(height: 14),
              CheckRow(
                label:
                    "I agree to an administrator checking my QR code on PSA's "
                    'PhilSys Check. PSA records the date, my first name and '
                    'the result.',
                checked: _consent,
                onTap: () => setState(() => _consent = !_consent),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Panel(
                  radius: AppRadius.control,
                  color: context.pal.live.withValues(alpha: 0.09),
                  border: context.pal.live.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.error, size: 17, color: context.pal.live),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: context.type.meta.copyWith(
                            fontSize: 12,
                            height: 16 / 12,
                            color: context.pal.textSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _submitButton(),
              const SizedBox(height: 16),
              _privacyNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const BackWell(),
        const SizedBox(width: 16),
        Text('National ID'.toUpperCase(), style: context.type.screenTitle),
      ],
    );
  }

  Widget _uploadSlot({
    required String label,
    required String hint,
    required IconData icon,
    required Uint8List? bytes,
    required VoidCallback onTap,
  }) {
    final filled = bytes != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.pal.glassDim,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(
            color: filled ? _safeGreen : context.pal.lineStrong,
          ),
        ),
        child: filled
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes, fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: context.pal.canvas.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.checkCircle,
                            color: _safeGreen,
                            size: 13,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'TAP TO RETAKE',
                            style: context.type.tag.copyWith(
                              color: context.pal.onBackground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconWell(
                    tint: context.pal.accent,
                    icon: icon,
                    size: 44,
                    glyph: 22,
                  ),
                  const SizedBox(height: 12),
                  Eyebrow(label, color: context.pal.accent),
                  const SizedBox(height: 6),
                  Text(hint, style: context.type.meta),
                ],
              ),
      ),
    );
  }

  Widget _submitButton() {
    return AppButton(
      'Submit for review',
      busy: _submitting,
      onPressed: (_ready && !_submitting) ? _submit : null,
    );
  }

  Widget _privacyNote() {
    return Panel(
      radius: AppRadius.control,
      color: context.pal.glassDim,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.lock, size: 16, color: context.pal.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your photos are held in private storage, seen only by the '
              'reviewing administrator, and deleted once the review is '
              'decided. The +50% applies once it is approved.',
              style: context.type.meta.copyWith(height: 16 / 11),
            ),
          ),
        ],
      ),
    );
  }
}
