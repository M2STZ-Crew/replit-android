import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/verification_api.dart';

/// Where the phone flow has got to. Entering a number and entering the code are
/// separate screens' worth of state, and the code step must not be reachable
/// before an SMS was actually sent.
enum PhoneStep { enterNumber, enterCode, verified }

class VerificationState {
  const VerificationState({
    this.phoneStep = PhoneStep.enterNumber,
    this.phoneE164,
    this.busy = false,
    this.errorMessage,
    this.infoMessage,
    this.idImage,
    this.selfieImage,
  });

  final PhoneStep phoneStep;
  final String? phoneE164;
  final bool busy;
  final String? errorMessage;

  /// Non-error feedback, e.g. "Verification email sent."
  final String? infoMessage;

  /// National ID capture. Both are required before submitting.
  final File? idImage;
  final File? selfieImage;

  bool get canSubmitId => idImage != null && selfieImage != null && !busy;

  VerificationState copyWith({
    PhoneStep? phoneStep,
    String? phoneE164,
    bool? busy,
    String? errorMessage,
    String? infoMessage,
    File? idImage,
    File? selfieImage,
    bool clearMessages = false,
  }) {
    return VerificationState(
      phoneStep: phoneStep ?? this.phoneStep,
      phoneE164: phoneE164 ?? this.phoneE164,
      busy: busy ?? this.busy,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearMessages ? null : (infoMessage ?? this.infoMessage),
      idImage: idImage ?? this.idImage,
      selfieImage: selfieImage ?? this.selfieImage,
    );
  }
}

class VerificationNotifier extends StateNotifier<VerificationState> {
  VerificationNotifier(this._api, this._ref) : super(const VerificationState());

  final VerificationApi _api;
  final Ref _ref;

  Future<void> sendPhoneCode(String rawInput) async {
    final e164 = VerificationApi.toE164(rawInput);
    if (e164 == null) {
      state = state.copyWith(
        errorMessage: 'Enter a Philippine mobile number, e.g. 0917 123 4567.',
        infoMessage: null,
      );
      return;
    }

    state = state.copyWith(busy: true, clearMessages: true);
    final result = await _api.requestPhoneCode(e164);
    result.when(
      success: (message) {
        state = state.copyWith(
          busy: false,
          phoneStep: PhoneStep.enterCode,
          phoneE164: e164,
          infoMessage: message,
        );
      },
      failure: (error) {
        state = state.copyWith(busy: false, errorMessage: error.message);
      },
    );
  }

  Future<void> submitPhoneCode(String code) async {
    state = state.copyWith(busy: true, clearMessages: true);
    final result = await _api.verifyPhoneCode(code.trim());
    await result.when(
      success: (verification) async {
        // The badge and percent are recomputed server-side, so pull the profile
        // rather than guessing the new values here.
        await _ref.read(authProvider.notifier).refreshUser();
        state = state.copyWith(
          busy: false,
          phoneStep: PhoneStep.verified,
          infoMessage: verification.message ?? 'Phone verified.',
        );
      },
      failure: (error) async {
        state = state.copyWith(busy: false, errorMessage: error.message);
      },
    );
  }

  Future<void> sendEmailLink() async {
    state = state.copyWith(busy: true, clearMessages: true);
    final result = await _api.requestEmailLink();
    result.when(
      success: (message) {
        state = state.copyWith(busy: false, infoMessage: message);
      },
      failure: (error) {
        state = state.copyWith(busy: false, errorMessage: error.message);
      },
    );
  }

  Future<void> pickIdImage({required bool isSelfie, required bool fromCamera}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        // Larger than an incident photo: an Admin has to read the text on the
        // document, and over-compressing it makes the review impossible.
        maxWidth: 2400,
        imageQuality: 90,
      );
      if (picked == null) return;
      final file = File(picked.path);
      state = isSelfie
          ? state.copyWith(selfieImage: file, clearMessages: true)
          : state.copyWith(idImage: file, clearMessages: true);
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Could not open the camera. Check app permissions.',
      );
    }
  }

  Future<void> submitNationalId() async {
    final id = state.idImage;
    final selfie = state.selfieImage;
    if (id == null || selfie == null) return;

    state = state.copyWith(busy: true, clearMessages: true);
    final result = await _api.submitNationalId(idImage: id, selfieImage: selfie);
    await result.when(
      success: (_) async {
        // Awards nothing yet — an Admin has to approve it — so refresh the
        // channel status rather than the profile, and say "submitted".
        _ref.invalidate(verificationStatusProvider);
        state = const VerificationState(
          infoMessage: 'Sent for review. An Admin will confirm your ID shortly.',
        );
      },
      failure: (error) async {
        state = state.copyWith(busy: false, errorMessage: error.message);
      },
    );
  }

  /// Back to the number field, e.g. after a typo in the number.
  void changeNumber() => state = const VerificationState();

  void clearMessages() => state = state.copyWith(clearMessages: true);
}

/// Per-channel verification state from the server.
final verificationStatusProvider =
    FutureProvider.autoDispose<Map<String, ChannelStatus>>((ref) async {
  final result = await ref.watch(verificationApiProvider).status();
  return result.when(success: (m) => m, failure: (_) => const {});
});

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  return VerificationNotifier(ref.watch(verificationApiProvider), ref);
});
