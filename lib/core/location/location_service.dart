import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_result.dart';

/// The single place `Geolocator`'s static API is called from — every other
/// layer (controllers, screens) only ever sees [LocationResult], never a
/// raw `Position`/`LocationPermission`/`LocationServiceDisabledException`.
class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationServiceDisabled();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationPermissionDeniedForever();
    }
    if (permission == LocationPermission.denied) {
      return const LocationPermissionDenied();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    return LocationAvailable(position.latitude, position.longitude);
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());
