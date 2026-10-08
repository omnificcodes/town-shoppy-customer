import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/merchants/application/merchant_detail_provider.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';

class FakeMerchantsRepository implements MerchantsRepository {
  FakeMerchantsRepository({this.merchant, this.error});

  final Merchant? merchant;
  final AppException? error;

  @override
  Future<Merchant> show(int id) async {
    if (error != null) throw error!;
    return merchant!;
  }

  @override
  Future<OffsetPage<Merchant>> list({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    int? associationId,
    bool? acceptsTownCoin,
    bool? featured,
    String? search,
  }) async => throw UnimplementedError();

  @override
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async => throw UnimplementedError();

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    double? radiusKm,
    int page = 1,
    int perPage = 50,
  }) async => throw UnimplementedError();
}

void main() {
  test('merchantDetailProvider surfaces the loaded merchant', () async {
    const merchant = Merchant(
      id: 5,
      name: 'Corner Cafe',
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
    final container = ProviderContainer(
      overrides: [merchantsRepositoryProvider.overrideWithValue(FakeMerchantsRepository(merchant: merchant))],
    );
    addTearDown(container.dispose);

    final result = await container.read(merchantDetailProvider(5).future);

    expect(result.name, 'Corner Cafe');
  });

  test('merchantDetailProvider surfaces a 404 for an unavailable/deleted merchant', () async {
    final container = ProviderContainer(
      overrides: [merchantsRepositoryProvider.overrideWithValue(FakeMerchantsRepository(error: const NotFoundException()))],
    );
    addTearDown(container.dispose);

    // Riverpod 3.3.2 auto-retries a failed provider build with backoff, so
    // it stays in `AsyncLoading(error: ..., retrying)` rather than settling
    // into `AsyncError` — poll `hasError`/`error`, which are set on both.
    var state = container.read(merchantDetailProvider(999));
    for (var i = 0; i < 50 && !state.hasError; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = container.read(merchantDetailProvider(999));
    }

    expect(state.hasError, isTrue);
    expect(state.error, isA<NotFoundException>());
  });
}
