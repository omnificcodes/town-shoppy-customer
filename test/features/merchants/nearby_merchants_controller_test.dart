import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/location/location_result.dart';
import 'package:customer/core/location/location_service.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/merchants/application/nearby_merchants_controller.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';

NearbyMerchant _result(int merchantId, {double distanceKm = 1.2}) {
  return NearbyMerchant(
    merchant: Merchant(
      id: merchantId,
      name: 'Merchant $merchantId',
      description: null,
      logoUrl: null,
      websiteUrl: null,
      contactMobileNumber: null,
      socialLinks: null,
      discountRate: null,
      acceptsTownCoin: false,
      category: null,
      association: null,
      branch: null,
    ),
    branch: const MerchantBranchRef(
      id: 1,
      name: null,
      isPrimary: true,
      addressLine: '1 Main St',
      locality: null,
      city: null,
      state: null,
      postalCode: null,
      country: null,
      latitude: 12.9,
      longitude: 77.5,
      distanceKm: 1.2,
    ),
    distanceKm: distanceKm,
  );
}

/// Scripted fake, same convention as `FakeMerchantsRepository` in
/// `merchants_list_controller_test.dart`.
class FakeMerchantsRepository implements MerchantsRepository {
  final List<Object> _responses = [];
  final List<int?> categoryIdsRequested = [];
  final List<int> pagesRequested = [];

  void queuePage(OffsetPage<NearbyMerchant> page) => _responses.add(page);
  void queueError(AppException error) => _responses.add(error);

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    int page = 1,
    int perPage = 50,
  }) async {
    categoryIdsRequested.add(categoryId);
    pagesRequested.add(page);
    final next = _responses.first;
    if (next is AppException) throw next;
    _responses.removeAt(0);
    return next as OffsetPage<NearbyMerchant>;
  }

  @override
  Future<OffsetPage<Merchant>> list({int page = 1, int perPage = 20, int? categoryId, bool? acceptsTownCoin, bool? featured}) async =>
      throw UnimplementedError();

  @override
  Future<Merchant> show(int id) async => throw UnimplementedError();

  @override
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async => throw UnimplementedError();
}

/// A scripted fake for the single result `getCurrentLocation()` should
/// return — `openAppSettings`/`openLocationSettings` are recorded but not
/// asserted on here, since the controller never awaits their effect.
class FakeLocationService implements LocationService {
  const FakeLocationService(this.result);

  final LocationResult result;

  @override
  Future<LocationResult> getCurrentLocation() async => result;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  group('NearbyMerchantsController', () {
    test('starts in the prompt state without requesting location', () {
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(FakeMerchantsRepository()),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationAvailable(0, 0))),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(nearbyMerchantsControllerProvider).value;
      expect(state, isA<NearbyPromptState>());
    });

    test('requestLocationAndLoad fetches nearby results once location is available', () async {
      final fake = FakeMerchantsRepository()
        ..queuePage(OffsetPage(items: [_result(1), _result(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(fake),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationAvailable(12.97, 77.59))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();

      final state = container.read(nearbyMerchantsControllerProvider).value;
      expect(state, isA<NearbyReadyState>());
      final data = (state as NearbyReadyState).data;
      expect(data.items.map((r) => r.merchant.id), [1, 2]);
      expect(data.latitude, 12.97);
      expect(data.longitude, 77.59);
    });

    test('requestLocationAndLoad surfaces a service-disabled state without calling the repository', () async {
      final fake = FakeMerchantsRepository();
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(fake),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationServiceDisabled())),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();

      final state = container.read(nearbyMerchantsControllerProvider).value;
      expect(state, isA<NearbyServiceDisabledState>());
      expect(fake.categoryIdsRequested, isEmpty);
    });

    test('requestLocationAndLoad distinguishes a re-askable denial from a permanent one', () async {
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(FakeMerchantsRepository()),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationPermissionDeniedForever())),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();

      final state = container.read(nearbyMerchantsControllerProvider).value;
      expect(state, isA<NearbyPermissionDeniedState>());
      expect((state as NearbyPermissionDeniedState).forever, isTrue);
    });

    test('a network failure surfaces as AsyncError, not a permission/service state', () async {
      final fake = FakeMerchantsRepository()..queueError(const NetworkException());
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(fake),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationAvailable(12.97, 77.59))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();

      final state = container.read(nearbyMerchantsControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkException>());
    });

    test('loadMore appends the next page using the same coordinates', () async {
      final fake = FakeMerchantsRepository()
        ..queuePage(OffsetPage(items: [_result(1)], currentPage: 1, lastPage: 2, total: 2))
        ..queuePage(OffsetPage(items: [_result(2)], currentPage: 2, lastPage: 2, total: 2));
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(fake),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationAvailable(12.97, 77.59))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();
      await container.read(nearbyMerchantsControllerProvider.notifier).loadMore();

      final data = (container.read(nearbyMerchantsControllerProvider).value! as NearbyReadyState).data;
      expect(data.items.map((r) => r.merchant.id), [1, 2]);
      expect(fake.pagesRequested, [1, 2]);
    });

    test('filterByCategory re-searches at the same coordinates with the new category', () async {
      final fake = FakeMerchantsRepository()
        ..queuePage(OffsetPage(items: [_result(1), _result(2)], currentPage: 1, lastPage: 1, total: 2))
        ..queuePage(OffsetPage(items: [_result(9)], currentPage: 1, lastPage: 1, total: 1));
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(fake),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationAvailable(12.97, 77.59))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();
      await container.read(nearbyMerchantsControllerProvider.notifier).filterByCategory(5);

      final data = (container.read(nearbyMerchantsControllerProvider).value! as NearbyReadyState).data;
      expect(data.categoryId, 5);
      expect(data.items.map((r) => r.merchant.id), [9]);
      expect(fake.categoryIdsRequested, [null, 5]);
    });

    test('reset returns to the prompt state', () async {
      final fake = FakeMerchantsRepository()..queuePage(OffsetPage(items: [_result(1)], currentPage: 1, lastPage: 1, total: 1));
      final container = ProviderContainer(
        overrides: [
          merchantsRepositoryProvider.overrideWithValue(fake),
          locationServiceProvider.overrideWithValue(const FakeLocationService(LocationAvailable(12.97, 77.59))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();
      container.read(nearbyMerchantsControllerProvider.notifier).reset();

      expect(container.read(nearbyMerchantsControllerProvider).value, isA<NearbyPromptState>());
    });
  });
}
