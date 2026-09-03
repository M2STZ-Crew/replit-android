import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final PhoneStep phoneStep;
  final String? phoneE164;
  final bool busy;
  final String? errorMessage;

  /// Non-error feedback, e.g. "Verification email sent."
  final String? infoMessage;

  VerificationState copyWith({
    PhoneStep? phoneStep,
    String? phoneE164,
    bool? busy,
    String? errorMessage,
    String? infoMessage,
    bool clearMessages = false,
  }) {
    return VerificationState(
      phoneStep: phoneStep ?? this.phoneStep,
      phoneE164: phoneE164 ?? this.phoneE164,
      busy: busy ?? this.busy,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearMessages ? null : (infoMessage ?? this.infoMessage),
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

  /// Back to the number field, e.g. after a typo in the number.
  void changeNumber() => state = const VerificationState();

  void clearMessages() => state = state.copyWith(clearMessages: true);
}

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  return VerificationNotifier(ref.watch(verificationApiProvider), ref);
});
