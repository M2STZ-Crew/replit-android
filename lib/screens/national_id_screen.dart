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
/// POST /verification/national-id/manual: the user uploads a government ID photo
/// and a matching selfie, which an administrator reviews before awarding +50%.
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

  Future<void> _pickId() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
              title: const Text('Take a photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final shot = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    if (mounted) {
      setState(() {
        _idBytes = bytes;
        _error = null;
      });
    }
  }

  Future<void> _pickSelfie() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    if (mounted) {
      setState(() {
        _selfieBytes = bytes;
        _error = null;
      });
    }
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
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.badge_outlined, color: AppColors.accent, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verify your identity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a clear photo of your government-issued ID and a matching '
                'selfie. An administrator reviews them and awards +50%.',
                style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              _uploadSlot(
                label: 'GOVERNMENT ID',
                hint: 'Tap to add a photo of your ID',
                icon: Icons.badge_outlined,
                bytes: _idBytes,
                onTap: _pickId,
              ),
              const SizedBox(height: 16),
              _uploadSlot(
                label: 'SELFIE',
                hint: 'Tap to take a selfie',
                icon: Icons.face_outlined,
                bytes: _selfieBytes,
                onTap: _pickSelfie,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.live, fontSize: 13),
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
