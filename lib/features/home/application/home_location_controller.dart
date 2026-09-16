import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/location/location_result.dart';
import '../../../core/location/location_service.dart';
import '../../merchants/data/merchants_repository.dart';

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
  const HomeLocationUnavailable([this.reason]);

  /// Why there is no location -- the header uses it to say whether to allow
  /// the permission, or to turn location services back on.
  final LocationResult? reason;
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

    if (result is! LocationAvailable) return HomeLocationUnavailable(result);

    final label = await _placeName(result.latitude, result.longitude);

    // Whatever the name lookup did, having coordinates is what the nearby
    // and trending sections actually need -- they never read the label.
    return HomeLocationReady(
      latitude: result.latitude,
      longitude: result.longitude,
      label: label ?? 'Current location',
    );
  }

  /// The OS reverse geocoder first, then the nearest shop's own town.
  ///
  /// `geocoding` ships Android and Apple implementations only, so on the
  /// web build every call throws -- without the second step the header
  /// would be stuck on the generic "Current location" there forever.
  Future<String?> _placeName(double latitude, double longitude) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(latitude, longitude);
      final label = placemarks.isEmpty ? null : _labelFor(placemarks.first);
      if (label != null) return label;
    } on Object {
      // No OS geocoder here (or it failed) -- fall through to the API.
    }

    return _nearestTownName(latitude, longitude);
  }

  /// The town of the closest branch Town Shoppy knows about. Not a true
  /// reverse geocode, but it names the place a customer is shopping in
  /// using data this app already serves, without a geocoding service.
  Future<String?> _nearestTownName(double latitude, double longitude) async {
    try {
      final page = await ref
          .read(merchantsRepositoryProvider)
          .nearby(latitude: latitude, longitude: longitude, radiusKm: _townSearchRadiusKm, perPage: 10);

      for (final nearby in page.items) {
        final name = _firstNonEmpty([nearby.branch.city, nearby.branch.locality]);
        if (name != null) return name;
      }
    } on Object {
      // Offline, or nothing nearby -- the caller falls back to the generic
      // label, exactly as before.
    }

    return null;
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

/// Wide enough to name the town even when the nearest shop is a few
/// towns over; well inside the server's own maximum for `radius_km`.
const _townSearchRadiusKm = 25.0;

final homeLocationControllerProvider = AsyncNotifierProvider<HomeLocationController, HomeLocationState>(
  HomeLocationController.new,
);
