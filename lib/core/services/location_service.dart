import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../errors/app_exception.dart';
import '../errors/result.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  Future<Result<Position>> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Failure(
          LocationException('Location services are disabled. Please enable them.'),
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const Failure(
            PermissionException('Location permission denied.'),
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const Failure(
          PermissionException(
            'Location permission permanently denied. Please enable in settings.',
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return Success(position);
    } on TimeoutException {
      return const Failure(LocationException('Location request timed out.'));
    } catch (e) {
      return Failure(LocationException('Failed to get location.', e));
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
