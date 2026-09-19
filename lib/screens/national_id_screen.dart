import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';

Color _safeGreen = AppColors.ok;

/// National ID verification (+50%) via the manual-review path.
///
/// The backend's Didit auto-KYC has no credits, so this uses
/// POST /verification/national-id/manual: the user supplies a government ID
/// photo and a matching selfie, which an administrator reviews before
/// awarding +50%.
///
/// Both images must be taken with the camera. There is no gallery option,
/// by design: attaching a saved picture is how someone submits an ID that
/// is not theirs, and the whole value of the selfie is that it was taken at
/// the same time as the document.
class NationalIdScreen extends StatefulWidget {
  const NationalIdScreen({super.key});

  @override
  State<NationalIdScreen> createState() => _NationalIdScreenState();
}

class _NationalIdScreenState extends State<NationalIdScreen> {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _idBytes;
  Uint8List? _selfieBytes;
  bool _submitting = false;
  String? _error;

  bool get _ready => _idBytes != null && _selfieBytes != null;

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
  /// megabytes of upload over mobile data.
  Future<Uint8List?> _capture({bool front = false}) async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 70,
        maxWidth: 1600,
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
                icon: Icons.badge_outlined,
                size: 56,
                glyph: 28,
              ),
              const SizedBox(height: 18),
              Text('VERIFY YOUR IDENTITY', style: context.type.title),
              const SizedBox(height: 10),
              Text(
                'Photograph your government ID and take a matching selfie. '
                'Both must be taken now with the camera — saved pictures are '
                'not accepted. An administrator reviews them and awards +50%.',
                style: context.type.body,
              ),
              const SizedBox(height: 26),
              _uploadSlot(
                label: 'Government ID',
                hint: 'Tap to photograph your ID',
                icon: Icons.badge_outlined,
                bytes: _idBytes,
                onTap: _pickId,
              ),
              const SizedBox(height: 12),
              _uploadSlot(
                label: 'Selfie',
                hint: 'Tap to take a selfie',
                icon: Icons.face_outlined,
                bytes: _selfieBytes,
                onTap: _pickSelfie,
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
                      Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: context.pal.live,
                      ),
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
                            Icons.check_circle_rounded,
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
          Icon(Icons.lock_outline_rounded, size: 16, color: context.pal.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your ID and selfie are held in private storage and shared only '
              'with the reviewing administrator. The +50% applies once it is '
              'approved.',
              style: context.type.meta.copyWith(height: 16 / 11),
            ),
          ),
        ],
      ),
    );
  }
}
