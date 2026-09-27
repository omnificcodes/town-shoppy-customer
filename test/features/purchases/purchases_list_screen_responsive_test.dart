import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/purchases/data/models/merchant_purchase_qr_resolution.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/models/purchase_request_target.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';
import 'package:customer/features/purchases/presentation/purchases_list_screen.dart';

import '../../helpers/responsive_test_helper.dart';

class _FakePurchasesRepository implements PurchasesRepository {
  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async => OffsetPage(
    items: [
      Purchase(
        id: 1,
        merchantId: 1,
        merchant: const PurchaseMerchantRef(id: 1, name: 'The Grand Downtown Corner Cafe and Bakery Emporium'),
        branch: null,
        billAmount: 999999.99,
        currency: 'INR',
        billReference: null,
        coinsAwarded: 50000,
        couponsIssued: null,
        status: 'recorded',
        reviewedAt: null,
        rejectionReason: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ],
    currentPage: 1,
    lastPage: 1,
    total: 1,
  );

  @override
  Future<Purchase> show(int id) async => throw UnimplementedError();

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => throw UnimplementedError();

  @override
  Future<MerchantPurchaseQrResolution> resolveMerchantQr(String token) async => throw UnimplementedError();

  @override
  Future<CounterPurchaseResult> requestPurchase({
    required PurchaseRequestTarget target,
    required double billAmount,
    required String idempotencyKey,
    bool redeem = false,
  }) async => throw UnimplementedError();
}

Widget _wrap() {
  return ProviderScope(
    overrides: [purchasesRepositoryProvider.overrideWithValue(_FakePurchasesRepository())],
    child: MaterialApp(theme: AppTheme.light, home: const PurchasesListScreen()),
  );
}

void main() {
  testWidgets('PurchasesListScreen renders a long merchant name and large amount without overflow at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Purchases'), findsOneWidget);
        expect(find.textContaining('The Grand Downtown'), findsOneWidget);
        expect(find.text('+50000 coins'), findsOneWidget);
      },
    );
  });
}
