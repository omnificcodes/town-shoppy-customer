import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/purchases/application/purchase_detail_provider.dart';
import 'package:customer/features/purchases/data/models/merchant_purchase_qr_resolution.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';

class FakePurchasesRepository implements PurchasesRepository {
  FakePurchasesRepository({this.purchase, this.error});

  final Purchase? purchase;
  final AppException? error;

  @override
  Future<Purchase> show(int id) async {
    if (error != null) throw error!;
    return purchase!;
  }

  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => throw UnimplementedError();

  @override
  Future<MerchantPurchaseQrResolution> resolveMerchantQr(String token) async => throw UnimplementedError();

  @override
  Future<Purchase> requestPurchase({
    required String token,
    required double billAmount,
    required String idempotencyKey,
  }) async => throw UnimplementedError();
}

void main() {
  test('purchaseDetailProvider surfaces the loaded purchase', () async {
    final purchase = Purchase(
      id: 5,
      merchantId: 1,
      merchant: const PurchaseMerchantRef(id: 1, name: 'Corner Cafe'),
      branch: null,
      billAmount: 200,
      currency: 'INR',
      billReference: null,
      coinsAwarded: 20,
      couponsIssued: 0,
      status: 'recorded',
      reviewedAt: null,
      rejectionReason: null,
      createdAt: DateTime(2026, 1, 1),
    );
    final container = ProviderContainer(
      overrides: [purchasesRepositoryProvider.overrideWithValue(FakePurchasesRepository(purchase: purchase))],
    );
    addTearDown(container.dispose);

    final result = await container.read(purchaseDetailProvider(5).future);

    expect(result.merchantName, 'Corner Cafe');
  });

  test('purchaseDetailProvider surfaces a 404 for an unavailable/deleted purchase', () async {
    final container = ProviderContainer(
      overrides: [purchasesRepositoryProvider.overrideWithValue(FakePurchasesRepository(error: const NotFoundException()))],
    );
    addTearDown(container.dispose);

    // Riverpod 3.3.2 auto-retries a failed provider build with backoff, so
    // it stays in `AsyncLoading(error: ..., retrying)` rather than settling
    // into `AsyncError` — `hasError`/`error` are set on both variants and
    // are the version-stable way to observe the failure here.
    var state = container.read(purchaseDetailProvider(999));
    for (var i = 0; i < 50 && !state.hasError; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = container.read(purchaseDetailProvider(999));
    }

    expect(state.hasError, isTrue);
    expect(state.error, isA<NotFoundException>());
  });
}
