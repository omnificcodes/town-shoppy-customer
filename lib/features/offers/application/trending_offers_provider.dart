import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/application/home_location_controller.dart';
import '../data/models/offer.dart';
import '../data/offers_repository.dart';

/// Home's "Trending offers near you" section — there is no separate
/// "trending" endpoint on the backend (only `GET /offers`/`GET
/// /offers/nearby`/`GET /offers/{id}`, confirmed by reading
/// `OfferController`), so "trending" here means the nearest currently-active
/// offers to the customer's resolved location, the same proxy the backend
/// itself is set up for. Depends on [homeLocationControllerProvider]
/// resolving to coordinates first; while that's loading or unavailable this
/// returns an empty list rather than its own error state, since a missing
/// "trending" carousel shouldn't block the rest of Home the way a failed
/// wallet balance would.
final trendingOffersProvider = FutureProvider<List<Offer>>((ref) async {
  final HomeLocationState location;
  try {
    location = await ref.watch(homeLocationControllerProvider.future);
  } catch (_) {
    // A location failure (permission denied, no GPS, web without
    // geolocation) is the header pill's problem to explain, not this
    // section's -- surfacing it here as "something went wrong" would blame
    // the offers API for a device state. Only a real offers fetch failure
    // reaches the UI as an error.
    return const [];
  }

  if (location is! HomeLocationReady) return const [];

  return ref.read(offersRepositoryProvider).nearby(latitude: location.latitude, longitude: location.longitude);
});
