import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/merchants/application/merchants_list_controller.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';

Merchant _merchant(int id) {
  return Merchant(
    id: id,
    name: 'Merchant $id',
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
  );
}

/// A scripted fake — mirrors `purchases_list_controller_test.dart`'s
/// `FakePurchasesRepository`: an error is peeked, not popped, since
/// Riverpod 3.3.2 auto-retries a failed provider build with backoff.
class FakeMerchantsRepository implements MerchantsRepository {
  final List<Object> _responses = [];
  final List<int?> categoryIdsRequested = [];

  void queuePage(OffsetPage<Merchant> page) => _responses.add(page);
  void queueError(AppException error) => _responses.add(error);

  @override
  Future<OffsetPage<Merchant>> list({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    bool? acceptsTownCoin,
    bool? featured,
    String? search,
  }) async {
    categoryIdsRequested.add(categoryId);
    final next = _responses.first;
    if (next is AppException) throw next;
    _responses.removeAt(0);
    return next as OffsetPage<Merchant>;
  }

  @override
  Future<Merchant> show(int id) async => throw UnimplementedError();

  @override
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async => throw UnimplementedError();

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    int page = 1,
    int perPage = 50,
  }) async => throw UnimplementedError();
}

void main() {
  group('MerchantsListController', () {
    test('loads the first page successfully', () async {
      final fake = FakeMerchantsRepository()
        ..queuePage(OffsetPage(items: [_merchant(1), _merchant(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(merchantsListControllerProvider.future);

      expect(state.items, hasLength(2));
      expect(state.hasMore, isFalse);
      expect(state.categoryId, isNull);
    });

    test('surfaces an empty list distinctly from a failure', () async {
      final fake = FakeMerchantsRepository()..queuePage(const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0));
      final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(merchantsListControllerProvider.future);

      expect(state.items, isEmpty);
    });

    test('propagates a backend error', () async {
      final fake = FakeMerchantsRepository()..queueError(const NetworkException());
      final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      // Riverpod 3.3.2 auto-retries a failed provider build with backoff,
      // so it stays in `AsyncLoading(error: ..., retrying)` rather than
      // settling into `AsyncError` — poll `hasError`/`error`, which are set
      // on both. The fake's error is peeked, not popped (see its own
      // docblock), so every retry attempt keeps failing the same way.
      var state = container.read(merchantsListControllerProvider);
      for (var i = 0; i < 50 && !state.hasError; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        state = container.read(merchantsListControllerProvider);
      }

      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkException>());
    });

    test('loadMore appends the next page and tracks currentPage/hasMore', () async {
      final fake = FakeMerchantsRepository()
        ..queuePage(OffsetPage(items: [_merchant(1)], currentPage: 1, lastPage: 2, total: 2))
        ..queuePage(OffsetPage(items: [_merchant(2)], currentPage: 2, lastPage: 2, total: 2));
      final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(merchantsListControllerProvider.future);
      await container.read(merchantsListControllerProvider.notifier).loadMore();

      final state = container.read(merchantsListControllerProvider).value!;
      expect(state.items.map((m) => m.id), [1, 2]);
      expect(state.hasMore, isFalse);
    });

    test('filterByCategory resets to page 1 and requests the new category_id', () async {
      final fake = FakeMerchantsRepository()
        ..queuePage(OffsetPage(items: [_merchant(1), _merchant(2)], currentPage: 1, lastPage: 2, total: 3))
        ..queuePage(OffsetPage(items: [_merchant(9)], currentPage: 1, lastPage: 1, total: 1));
      final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(merchantsListControllerProvider.future);
      await container.read(merchantsListControllerProvider.notifier).filterByCategory(5);

      final state = container.read(merchantsListControllerProvider).value!;
      expect(state.categoryId, 5);
      expect(state.items.map((m) => m.id), [9]);
      expect(fake.categoryIdsRequested, [null, 5]);
    });

    test('filterByCategory is a no-op when re-selecting the already-active category', () async {
      final fake = FakeMerchantsRepository()..queuePage(OffsetPage(items: [_merchant(1)], currentPage: 1, lastPage: 1, total: 1));
      final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(merchantsListControllerProvider.future);
      await container.read(merchantsListControllerProvider.notifier).filterByCategory(null);

      expect(fake.categoryIdsRequested, [null]);
    });
  });
}
