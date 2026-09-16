import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/purchases/data/models/counter_redemption.dart';
import 'package:customer/features/purchases/data/models/merchant_purchase_qr_resolution.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';
import 'package:customer/features/purchases/presentation/request_purchase_screen.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _resolution = MerchantPurchaseQrResolution(
  merchantId: 42,
  merchantName: 'Kairaly Bakers',
  branchId: 7,
  branchName: 'Main Branch',
  branchAddressLine: 'Kakkanad',
  acceptsTownCoin: false,
  discountRate: null,
);

Purchase _purchase({String status = 'pending', int coins = 0, int? coupons}) => Purchase.fromJson({
  'id': 90,
  'merchant_id': 42,
  'bill_amount': 500,
  'currency': 'INR',
  'status': status,
  'coins_awarded': coins,
  // The server's own figure: ₹500 earns 50 coins, pending or approved.
  'expected_coins': 50,
  'coupons_issued': ?coupons,
  'created_at': '2026-09-16T10:43:00+05:30',
});

/// Returns the submitted purchase as pending, then whatever [nextStatus]
/// says the next time the status is checked.
class _FakePurchasesRepository implements PurchasesRepository {
  String nextStatus = 'pending';
  int showCalls = 0;

  @override
  Future<MerchantPurchaseQrResolution> resolveMerchantQr(String token) async => _resolution;

  @override
  Future<CounterPurchaseResult> requestPurchase({
    required String token,
    required double billAmount,
    required String idempotencyKey,
    bool redeem = false,
  }) async => CounterPurchaseResult(
    purchase: _purchase(),
    redemption: const CounterRedemption(
      applied: false,
      reason: 'This merchant has no valid Town Coin discount rate configured.',
    ),
  );

  @override
  Future<Purchase> show(int id) async {
    showCalls++;
    return nextStatus == 'recorded'
        ? _purchase(status: 'recorded', coins: 50, coupons: 2)
        : _purchase(status: nextStatus);
  }

  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async =>
      const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0);

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => const [];
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async => const SilverWalletBalance(
    balance: 0,
    universalBalance: 0,
    shopExclusiveBalance: 0,
    shopExclusiveBreakdown: [],
    balanceInrEquivalent: 0,
    updatedAt: null,
  );

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => throw UnimplementedError();
}

Future<void> _submitBill(WidgetTester tester, _FakePurchasesRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        purchasesRepositoryProvider.overrideWithValue(repository),
        walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const RequestPurchaseScreen(scannedToken: 'tok'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), '500');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pay ₹500.00'));
  await tester.pumpAndSettle();
}

void main() {
  // A tap that misses must fail the test, never pass it vacuously.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('a sent bill shows the success page with its details and a Pending status', (tester) async {
    await _submitBill(tester, _FakePurchasesRepository());

    expect(find.text('Bill sent successfully'), findsOneWidget);
    expect(find.text('Waiting for Kairaly Bakers to confirm. Nothing is deducted until they do.'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.byTooltip('Refresh status'), findsOneWidget);

    expect(find.text('Kairaly Bakers'), findsOneWidget);
    expect(find.text('Main Branch · Kakkanad'), findsOneWidget);
    expect(find.text('Amount to pay'), findsOneWidget);
    // Nothing was redeemed on this bill; approval will earn 50 coins.
    expect(find.text('You save'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);
    expect(find.text('No coins used on this bill'), findsOneWidget);
    expect(find.text("You'll earn"), findsOneWidget);
    expect(find.text('50 coins'), findsOneWidget);
    expect(find.text('Credited once approved'), findsOneWidget);
    expect(find.text('#90'), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining('No coins were used on this bill.'), 200);
    expect(find.textContaining('No coins were used on this bill.'), findsOneWidget);
  });

  testWidgets('refresh re-checks the status and shows the approved purchase with coins earned', (tester) async {
    final repository = _FakePurchasesRepository();
    await _submitBill(tester, repository);
    expect(find.text('Pending'), findsOneWidget);

    repository.nextStatus = 'recorded';
    final callsBefore = repository.showCalls;
    await tester.tap(find.byTooltip('Refresh status'));
    await tester.pumpAndSettle();

    expect(repository.showCalls, greaterThan(callsBefore));
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Purchase confirmed'), findsOneWidget);
    expect(find.text('You earned'), findsOneWidget);
    expect(find.text('50 coins'), findsOneWidget);
    expect(find.text('Added to your wallet'), findsOneWidget);
    expect(find.text('2 coupons'), findsOneWidget);
  });

  testWidgets('a declined bill says so instead of showing a tick', (tester) async {
    final repository = _FakePurchasesRepository();
    await _submitBill(tester, repository);

    repository.nextStatus = 'rejected';
    await tester.tap(find.byTooltip('Refresh status'));
    await tester.pumpAndSettle();

    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Bill declined'), findsOneWidget);
    expect(find.text('0 coins'), findsOneWidget);
    expect(find.text('Not issued'), findsOneWidget);
  });
}
