import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/location/location_result.dart';
import '../../../core/location/location_service.dart';

/// The Home header's location label — deliberately a *separate* provider
/// from [nearbyMerchantsControllerProvider], which never auto-requests
/// location (its own doc comment: the OS prompt only ever appears after an
/// explicit "Use my location" tap). Home's header is different: like most
/// discovery-led consumer apps, showing *some* location label right on
/// launch is the point of that header, so this one resolves silently on
/// first build. A denied/unavailable result degrades to a tappable
/// "Set location" label instead of blocking or erroring the rest of Home.
sealed class HomeLocationState {
  const HomeLocationState();
}

class HomeLocationUnavailable extends HomeLocationState {
  const HomeLocationUnavailable();
}

class HomeLocationReady extends HomeLocationState {
  const HomeLocationReady({required this.latitude, required this.longitude, required this.label});

  final double latitude;
  final double longitude;
  final String label;
}

class HomeLocationController extends AsyncNotifier<HomeLocationState> {
  // geocoding 5.x dropped the old top-level `placemarkFromCoordinates()`
  // convenience function in favor of this instance-based API. Created on
  // first use, so a controller that never geocodes never touches the plugin.
  late final _geocoding = Geocoding();

  @override
  Future<HomeLocationState> build() => _resolve();

  Future<void> retry() async {
    state = const AsyncLoading();
    state = AsyncData(await _resolve());
  }

  Future<HomeLocationState> _resolve() async {
    final result = await ref.read(locationServiceProvider).getCurrentLocation();

    if (result is! LocationAvailable) return const HomeLocationUnavailable();

    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(result.latitude, result.longitude);
      final label = placemarks.isEmpty ? null : _labelFor(placemarks.first);
      return HomeLocationReady(
        latitude: result.latitude,
        longitude: result.longitude,
        label: label ?? 'Current location',
      );
    } on Object {
      // Reverse geocoding failing (no network, no OS geocoder) shouldn't
      // hide that we DO have coordinates -- the trending-offers section
      // only needs lat/lng, never the label.
      return HomeLocationReady(latitude: result.latitude, longitude: result.longitude, label: 'Current location');
    }
  }

  String? _labelFor(Placemark placemark) {
    final town = _firstNonEmpty([placemark.locality, placemark.subAdministrativeArea, placemark.subLocality]);
    final district = _firstNonEmpty([placemark.subAdministrativeArea, placemark.administrativeArea]);

    if (town != null && district != null && town != district) return '$town, $district';
    return town ?? district;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

final homeLocationControllerProvider = AsyncNotifierProvider<HomeLocationController, HomeLocationState>(
  HomeLocationController.new,
);
