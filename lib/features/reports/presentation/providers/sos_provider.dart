import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../data/report_api.dart';
import '../../domain/entities/report.dart';

/// Where the submission has got to. Capture is several fallible steps, and the
/// UI has to say which one failed — "couldn't get a GPS fix" and "couldn't reach
/// the server" need different actions from the user.
enum SosStage { idle, locating, ready, submitting, submitted, failed }

class SosState {
  const SosState({
    this.stage = SosStage.idle,
    this.position,
    this.photo,
    this.agencies = const {AgencyType.fireVolunteer},
    this.notes = '',
    this.uploadProgress = 0,
    this.result,
    this.errorMessage,
  });

  final SosStage stage;
  final Position? position;
  final File? photo;

  /// Fire Volunteers are pre-selected — this is a fire-reporting app, and in an
  /// emergency the default should be the common case.
  final Set<String> agencies;

  final String notes;
  final double uploadProgress;
  final ReportSubmission? result;
  final String? errorMessage;

  bool get isBusy =>
      stage == SosStage.locating || stage == SosStage.submitting;

  /// The server requires a GPS fix, a photo, and at least one agency.
  bool get canSubmit =>
      position != null && photo != null && agencies.isNotEmpty && !isBusy;

  SosState copyWith({
    SosStage? stage,
    Position? position,
    File? photo,
    Set<String>? agencies,
    String? notes,
    double? uploadProgress,
    ReportSubmission? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SosState(
      stage: stage ?? this.stage,
      position: position ?? this.position,
      photo: photo ?? this.photo,
      agencies: agencies ?? this.agencies,
      notes: notes ?? this.notes,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SosNotifier extends StateNotifier<SosState> {
  SosNotifier(this._location, this._api, this._picker) : super(const SosState());

  final LocationService _location;
  final ReportApi _api;
  final ImagePicker _picker;

  /// Step 1 of the SOS hold: acquire the fix that becomes the incident location.
  Future<void> acquireLocation() async {
    state = state.copyWith(stage: SosStage.locating, clearError: true);
    final result = await _location.getCurrentPosition();
    result.when(
      success: (position) {
        state = state.copyWith(stage: SosStage.ready, position: position);
      },
      failure: (error) {
        state = state.copyWith(
          stage: SosStage.failed,
          errorMessage: error.message,
        );
      },
    );
  }

  /// Step 2: the photo. Mandatory — the server rejects a report without one.
  Future<void> capturePhoto({required bool fromCamera}) async {
    try {
      final picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        // Keeps a modern handset's 8–12 MB capture under the server's 5 MB cap
        // without a second compression pass.
        maxWidth: 1920,
        imageQuality: 85,
        // Preserves EXIF GPS, which the backend cross-references against the
        // device fix to catch spoofing. Stripping it would disable that check.
        requestFullMetadata: true,
      );
      if (picked == null) return; // user backed out — not an error
      state = state.copyWith(photo: File(picked.path), clearError: true);
    } catch (error) {
      state = state.copyWith(
        stage: SosStage.failed,
        errorMessage: 'Could not open the camera. Check app permissions.',
      );
    }
  }

  void toggleAgency(String agency) {
    final next = {...state.agencies};
    if (!next.remove(agency)) next.add(agency);
    state = state.copyWith(agencies: next);
  }

  /// Replace the agency set outright.
  ///
  /// The redesigned flow asks "what's happening?" — fire, medical, crime —
  /// rather than making a frightened person pick agencies out of a list. Each
  /// answer maps to the agencies that actually respond to it, so the request
  /// the server receives is unchanged.
  void setAgencies(Set<String> agencies) =>
      state = state.copyWith(agencies: agencies);

  void setNotes(String value) => state = state.copyWith(notes: value);

  Future<void> submit() async {
    final position = state.position;
    final photo = state.photo;
    if (position == null || photo == null) return;

    state = state.copyWith(
      stage: SosStage.submitting,
      uploadProgress: 0,
      clearError: true,
    );

    final result = await _api.submit(
      lat: position.latitude,
      lng: position.longitude,
      photo: photo,
      agencies: state.agencies.toList(),
      gpsAccuracyM: position.accuracy,
      // Compass heading is metadata only and never used to locate the fire.
      compassBearing: position.heading >= 0 && position.heading < 360
          ? position.heading
          : null,
      notes: state.notes,
      onProgress: (sent, total) {
        if (total > 0) {
          state = state.copyWith(uploadProgress: sent / total);
        }
      },
    );

    result.when(
      success: (submission) {
        state = state.copyWith(stage: SosStage.submitted, result: submission);
      },
      failure: (error) {
        state = state.copyWith(
          stage: SosStage.failed,
          errorMessage: error.message,
        );
      },
    );
  }

  /// Back to a clean slate for the next report.
  void reset() => state = const SosState();

  /// Keeps the captured evidence so a failed upload can be retried without
  /// making the user photograph the fire again.
  void dismissError() => state = state.copyWith(
        stage: state.position != null ? SosStage.ready : SosStage.idle,
        clearError: true,
      );
}

final sosProvider = StateNotifierProvider<SosNotifier, SosState>((ref) {
  return SosNotifier(
    ref.watch(locationServiceProvider),
    ref.watch(reportApiProvider),
    ImagePicker(),
  );
});
