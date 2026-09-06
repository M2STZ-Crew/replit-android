import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';

const Color _safeGreen = AppColors.ok;

/// National ID verification (+50%) via the manual-review path.
///
/// The backend's Didit auto-KYC has no credits, so this uses
/// POST /verification/national-id/manual: the user supplies a government ID
/// photo and a matching selfie, which an administrator reviews before
/// awarding +50%.
///
/// Both images can be taken now or chosen from the gallery. Camera-only is
/// the usual anti-spoofing move in a KYC flow, but it buys nothing here:
/// there is no liveness check, so a camera pointed at a printed photo passes
/// exactly as easily. What actually catches a bad submission is the admin
/// review queue, and that runs either way.
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

  /// Ask where the image should come from.
  ///
  /// Both slots offer the camera and the gallery. A photo of an ID very often
  /// already exists in someone's gallery — sent by a parent, saved from an
  /// email — and forcing them to re-photograph a document they already have a
  /// clear picture of is the kind of friction that makes people give up on
  /// verification entirely.
  ///
  /// Returns null if the sheet is dismissed without a choice.
  Future<ImageSource?> _askSource({required String what}) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      // sheetContext, not the screen's: popping with the outer context happens
      // to hit the same Navigator today, but it is the screen that would go if
      // this sheet were ever shown over another route.
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              Text('ADD YOUR $what'.toUpperCase(), style: AppText.screenTitle),
              const SizedBox(height: 16),
              _sourceRow(
                icon: Icons.photo_camera_outlined,
                title: 'Take a photo',
                subtitle: 'Use the camera now',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _sourceRow(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                subtitle: 'Pick a picture already on this phone',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Panel(
      radius: AppRadius.control,
      color: AppColors.glassDim,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          IconWell(tint: AppColors.accent, icon: icon, size: 42, glyph: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppText.cardTitle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: AppText.meta),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.faint,
          ),
        ],
      ),
    );
  }

  /// Read one image into memory.
  ///
  /// [front] only matters for the camera — it opens the selfie lens. Capped at
  /// 1600px and 70% quality: an ID has to stay legible enough for an admin to
  /// read, but a full-resolution phone photo is several megabytes of upload
  /// over mobile data.
  Future<Uint8List?> _capture(ImageSource source, {bool front = false}) async {
    try {
      final shot = await _picker.pickImage(
        source: source,
        preferredCameraDevice: front
            ? CameraDevice.front
            : CameraDevice.rear,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (shot == null) return null; // dismissed — not an error
      return shot.readAsBytes();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = source == ImageSource.camera
              ? 'Could not open the camera. Check the app permissions.'
              : 'Could not open your gallery. Check the app permissions.',
        );
      }
      return null;
    }
  }

  Future<void> _pickId() async {
    final source = await _askSource(what: 'ID');
    if (source == null) return;
    final bytes = await _capture(source);
    if (bytes == null || !mounted) return;
    setState(() {
      _idBytes = bytes;
      _error = null;
    });
  }

  Future<void> _pickSelfie() async {
    final source = await _askSource(what: 'selfie');
    if (source == null) return;
    final bytes = await _capture(source, front: true);
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
      await _api.submitNationalIdManual(idBytes: _idBytes!, selfieBytes: _selfieBytes!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submitted for review. An admin will award +50% once approved.'),
          backgroundColor: _safeGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not submit. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 26),
              const IconWell(
                tint: AppColors.accent,
                icon: Icons.badge_outlined,
                size: 56,
                glyph: 28,
              ),
              const SizedBox(height: 18),
              const Text('VERIFY YOUR IDENTITY', style: AppText.title),
              const SizedBox(height: 10),
              const Text(
                'Add a clear picture of your government ID and a matching '
                'selfie — take them now or pick ones already on your phone. An '
                'administrator reviews both and awards +50%.',
                style: AppText.body,
              ),
              const SizedBox(height: 26),
              _uploadSlot(
                label: 'Government ID',
                hint: 'Take a photo or choose one',
                icon: Icons.badge_outlined,
                bytes: _idBytes,
                onTap: _pickId,
              ),
              const SizedBox(height: 12),
              _uploadSlot(
                label: 'Selfie',
                hint: 'Take one now or choose one',
                icon: Icons.face_outlined,
                bytes: _selfieBytes,
                onTap: _pickSelfie,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Panel(
                  radius: AppRadius.control,
                  color: AppColors.live.withValues(alpha: 0.09),
                  border: AppColors.live.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: AppColors.live,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppText.meta.copyWith(
                            fontSize: 12,
                            height: 16 / 12,
                            color: AppColors.textSoft,
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
        Text('National ID'.toUpperCase(), style: AppText.screenTitle),
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
          color: AppColors.glassDim,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(
            color: filled ? _safeGreen : AppColors.lineStrong,
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
                        color: AppColors.canvas.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _safeGreen,
                            size: 13,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'TAP TO RETAKE',
                            style: AppText.tag.copyWith(
                              color: AppColors.onBackground,
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
                    tint: AppColors.accent,
                    icon: icon,
                    size: 44,
                    glyph: 22,
                  ),
                  const SizedBox(height: 12),
                  Eyebrow(label, color: AppColors.accent),
                  const SizedBox(height: 6),
                  Text(hint, style: AppText.meta),
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
      color: AppColors.glassDim,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your ID and selfie are held in private storage and shared only '
              'with the reviewing administrator. The +50% applies once it is '
              'approved.',
              style: AppText.meta.copyWith(height: 16 / 11),
            ),
          ),
        ],
      ),
    );
  }
}
