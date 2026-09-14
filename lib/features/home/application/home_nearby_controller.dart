import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../merchants/data/merchants_repository.dart';
import '../../merchants/data/models/nearby_merchant.dart';
import 'home_location_controller.dart';

/// Home's "Find Stores Near You" filters: a search radius and an
/// open-now switch.
class HomeNearbyFilter {
  const HomeNearbyFilter({this.radiusKm = nearRadiusKm, this.openNowOnly = false});

  /// The two radius chips. Both sit well inside the server's configured
  /// maximum for `radius_km`.
  static const nearRadiusKm = 2.0;
  static const wideRadiusKm = 5.0;

  final double radiusKm;
  final bool openNowOnly;

  HomeNearbyFilter copyWith({double? radiusKm, bool? openNowOnly}) {
    return HomeNearbyFilter(radiusKm: radiusKm ?? this.radiusKm, openNowOnly: openNowOnly ?? this.openNowOnly);
  }
}

class HomeNearbyFilterController extends Notifier<HomeNearbyFilter> {
  @override
  HomeNearbyFilter build() => const HomeNearbyFilter();

  void setRadius(double radiusKm) {
    if (state.radiusKm == radiusKm) return;
    state = state.copyWith(radiusKm: radiusKm);
  }

  void toggleOpenNow() => state = state.copyWith(openNowOnly: !state.openNowOnly);
}

final homeNearbyFilterProvider = NotifierProvider<HomeNearbyFilterController, HomeNearbyFilter>(
  HomeNearbyFilterController.new,
);

/// A short row of shops around the customer, for Home.
///
/// Separate from `nearbyMerchantsControllerProvider`, which powers the full
/// discovery screen and deliberately waits for an explicit "Use my
/// location" tap. Home already resolves location silently for its header
/// (see [homeLocationControllerProvider]), so this reuses that fix rather
/// than prompting again.
///
/// Returns null when there is no location to search around, which tells
/// the section to hide rather than show an error for a device state.
///
/// "Open now" is filtered here, from each merchant's saved business hours:
/// the nearby endpoint has no open-now parameter. It applies to the nearest
/// page of results, which is all a Home carousel shows.
final homeNearbyMerchantsProvider = FutureProvider<List<NearbyMerchant>?>((ref) async {
  final filter = ref.watch(homeNearbyFilterProvider);

  final HomeLocationState location;
  try {
    location = await ref.watch(homeLocationControllerProvider.future);
  } catch (_) {
    return null;
  }

  if (location is! HomeLocationReady) return null;

  final page = await ref.read(merchantsRepositoryProvider).nearby(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: filter.radiusKm,
        perPage: _homeNearbyPageSize,
      );

  if (!filter.openNowOnly) return page.items;

  final now = DateTime.now();
  return page.items.where((item) => item.merchant.businessHours?.statusAt(now).isOpen ?? false).toList();
});

/// One of the page sizes the nearby endpoint accepts (10, 20 or 50).
const _homeNearbyPageSize = 10;
