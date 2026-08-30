import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_result.dart';
import '../../../core/location/location_service.dart';
import '../data/merchants_repository.dart';
import '../data/models/nearby_merchant.dart';

/// The "Nearby" tab's state machine — distinct from [NearbyMerchantsData]
/// (below), which is only the "have a location, have results" sub-state.
/// Kept as its own sealed type (rather than folding permission/service
/// failures into [AsyncError]) because each failure needs a different
/// recovery action (re-prompt vs. open OS location settings vs. open this
/// app's own settings), not a generic "try again".
sealed class NearbyMerchantsUiState {
  const NearbyMerchantsUiState();
}

/// Location hasn't been requested yet — the initial state, and the state
/// returned to after [NearbyMerchantsController.reset].
class NearbyPromptState extends NearbyMerchantsUiState {
  const NearbyPromptState();
}

class NearbyLocatingState extends NearbyMerchantsUiState {
  const NearbyLocatingState();
}

class NearbyServiceDisabledState extends NearbyMerchantsUiState {
  const NearbyServiceDisabledState();
}

class NearbyPermissionDeniedState extends NearbyMerchantsUiState {
  const NearbyPermissionDeniedState({required this.forever});

  /// Whether the OS will refuse to show the permission prompt again — the
  /// only recovery at that point is this app's own settings screen.
  final bool forever;
}

class NearbyReadyState extends NearbyMerchantsUiState {
  const NearbyReadyState(this.data);

  final NearbyMerchantsData data;
}

class NearbyMerchantsData {
  const NearbyMerchantsData({
    required this.items,
    required this.latitude,
    required this.longitude,
    required this.page,
    required this.hasMore,
    required this.categoryId,
    this.isLoadingMore = false,
    this.isChangingFilter = false,
  });

  final List<NearbyMerchant> items;
  final double latitude;
  final double longitude;
  final int page;
  final bool hasMore;
  final int? categoryId;
  final bool isLoadingMore;
  final bool isChangingFilter;

  NearbyMerchantsData copyWith({
    List<NearbyMerchant>? items,
    int? page,
    bool? hasMore,
    int? categoryId,
    bool clearCategoryId = false,
    bool? isLoadingMore,
    bool? isChangingFilter,
  }) {
    return NearbyMerchantsData(
      items: items ?? this.items,
      latitude: latitude,
      longitude: longitude,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isChangingFilter: isChangingFilter ?? this.isChangingFilter,
    );
  }
}

/// Deliberately does not auto-request location in `build()` — the OS
/// permission prompt only ever appears in response to the customer tapping
/// "Use my location" on the [NearbyPromptState] card, never as a surprise on
/// screen open.
class NearbyMerchantsController extends AsyncNotifier<NearbyMerchantsUiState> {
  static const _perPage = 50;

  @override
  NearbyMerchantsUiState build() => const NearbyPromptState();

  Future<void> requestLocationAndLoad() async {
    final previousCategoryId = switch (state.value) {
      NearbyReadyState(:final data) => data.categoryId,
      _ => null,
    };

    state = const AsyncData(NearbyLocatingState());
    final location = await ref.read(locationServiceProvider).getCurrentLocation();

    switch (location) {
      case LocationServiceDisabled():
        state = const AsyncData(NearbyServiceDisabledState());
      case LocationPermissionDenied():
        state = const AsyncData(NearbyPermissionDeniedState(forever: false));
      case LocationPermissionDeniedForever():
        state = const AsyncData(NearbyPermissionDeniedState(forever: true));
      case LocationAvailable(:final latitude, :final longitude):
        await _search(latitude: latitude, longitude: longitude, categoryId: previousCategoryId);
    }
  }

  Future<void> _search({required double latitude, required double longitude, required int? categoryId}) async {
    try {
      final page = await ref.read(merchantsRepositoryProvider).nearby(
            latitude: latitude,
            longitude: longitude,
            categoryId: categoryId,
            page: 1,
            perPage: _perPage,
          );
      state = AsyncData(
        NearbyReadyState(
          NearbyMerchantsData(
            items: page.items,
            latitude: latitude,
            longitude: longitude,
            page: 1,
            hasMore: page.hasMore,
            categoryId: categoryId,
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current is! NearbyReadyState || !current.data.hasMore || current.data.isLoadingMore) return;

    state = AsyncData(NearbyReadyState(current.data.copyWith(isLoadingMore: true)));
    try {
      final page = await ref.read(merchantsRepositoryProvider).nearby(
            latitude: current.data.latitude,
            longitude: current.data.longitude,
            categoryId: current.data.categoryId,
            page: current.data.page + 1,
            perPage: _perPage,
          );
      state = AsyncData(
        NearbyReadyState(
          current.data.copyWith(
            items: [...current.data.items, ...page.items],
            page: page.currentPage,
            hasMore: page.hasMore,
            isLoadingMore: false,
          ),
        ),
      );
    } catch (_) {
      // Same "keep the existing list, only drop the trailing spinner" rule
      // MerchantsListController.loadMore() uses.
      state = AsyncData(NearbyReadyState(current.data.copyWith(isLoadingMore: false)));
    }
  }

  Future<void> filterByCategory(int? categoryId) async {
    final current = state.value;
    if (current is! NearbyReadyState || current.data.categoryId == categoryId) return;

    state = AsyncData(NearbyReadyState(current.data.copyWith(isChangingFilter: true)));
    await _search(latitude: current.data.latitude, longitude: current.data.longitude, categoryId: categoryId);
  }

  /// Back to [NearbyPromptState] — used when the customer switches away from
  /// the "Nearby" tab and back, so a stale permission-denied/error card
  /// doesn't linger; they get a fresh "Use my location" prompt instead.
  void reset() => state = const AsyncData(NearbyPromptState());
}

final nearbyMerchantsControllerProvider = AsyncNotifierProvider<NearbyMerchantsController, NearbyMerchantsUiState>(
  NearbyMerchantsController.new,
);
