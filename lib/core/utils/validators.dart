import '../constants/app_constants.dart';

abstract final class Validators {
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final _htmlTagRegex = RegExp(r'<[^>]*>');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain an uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain a number';
    }
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Name must be under 100 characters';
    }
    return null;
  }

  static String? incidentDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length < AppConstants.minDescriptionLength) {
      return 'Description must be at least ${AppConstants.minDescriptionLength} characters';
    }
    if (value.trim().length > AppConstants.maxDescriptionLength) {
      return 'Description must be under ${AppConstants.maxDescriptionLength} characters';
    }
    return null;
  }

  static String sanitize(String input) {
    return input.replaceAll(_htmlTagRegex, '').trim();
  }

  static bool isValidImageExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return AppConstants.allowedImageTypes.contains(ext);
  }

  static bool isValidImageSize(int sizeInBytes) {
    return sizeInBytes <= AppConstants.maxPhotoSizeBytes;
  }
}
