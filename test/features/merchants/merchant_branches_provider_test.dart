import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/merchants/application/merchant_branches_provider.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';

class FakeMerchantsRepository implements MerchantsRepository {
  FakeMerchantsRepository({this.branches, this.error});

  final List<MerchantBranchRef>? branches;
  final AppException? error;
  int? lastRequestedMerchantId;

  @override
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async {
    lastRequestedMerchantId = merchantId;
    if (error != null) throw error!;
    return branches!;
  }

  @override
  Future<Merchant> show(int id) async => throw UnimplementedError();

  @override
  Future<OffsetPage<Merchant>> list({int page = 1, int perPage = 20, int? categoryId, bool? acceptsTownCoin, bool? featured}) async =>
      throw UnimplementedError();

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    int page = 1,
    int perPage = 50,
  }) async => throw UnimplementedError();
}

const _primary = MerchantBranchRef(
  id: 1,
  name: 'Main Street',
  isPrimary: true,
  addressLine: null,
  locality: null,
  city: null,
  state: null,
  postalCode: null,
  country: null,
  latitude: 1.0,
  longitude: 2.0,
  distanceKm: null,
);

void main() {
  test('merchantBranchesProvider surfaces the loaded branch list for the requested merchant', () async {
    final fake = FakeMerchantsRepository(branches: const [_primary]);
    final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final result = await container.read(merchantBranchesProvider(42).future);

    expect(result, hasLength(1));
    expect(result.first.name, 'Main Street');
    expect(fake.lastRequestedMerchantId, 42);
  });

  test('merchantBranchesProvider surfaces an empty list distinctly from a failure', () async {
    final fake = FakeMerchantsRepository(branches: const []);
    final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final result = await container.read(merchantBranchesProvider(42).future);

    expect(result, isEmpty);
  });

  test('merchantBranchesProvider surfaces a backend error', () async {
    final fake = FakeMerchantsRepository(error: const NetworkException());
    final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    // Riverpod 3.3.2 auto-retries a failed provider build with backoff, so
    // it stays in `AsyncLoading(error: ..., retrying)` rather than settling
    // into `AsyncError` — poll `hasError`/`error`, which are set on both.
    var state = container.read(merchantBranchesProvider(42));
    for (var i = 0; i < 50 && !state.hasError; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = container.read(merchantBranchesProvider(42));
    }

    expect(state.hasError, isTrue);
    expect(state.error, isA<NetworkException>());
  });

  test('different merchant IDs are cached independently', () async {
    final fake = FakeMerchantsRepository(branches: const [_primary]);
    final container = ProviderContainer(overrides: [merchantsRepositoryProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    await container.read(merchantBranchesProvider(1).future);
    await container.read(merchantBranchesProvider(2).future);

    expect(fake.lastRequestedMerchantId, 2);
    expect(container.read(merchantBranchesProvider(1)).hasValue, isTrue);
    expect(container.read(merchantBranchesProvider(2)).hasValue, isTrue);
  });
}
