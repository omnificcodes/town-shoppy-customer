import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';
import 'package:customer/features/purchases/application/customer_purchase_request_controller.dart';
import 'package:customer/features/purchases/data/models/merchant_purchase_qr_resolution.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/models/purchase_request_target.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

class FakePurchasesRepository implements PurchasesRepository {
  FakePurchasesRepository({this.resolution, this.resolveError, this.requestResult, this.requestError, this.delay});

  MerchantPurchaseQrResolution? resolution;
  AppException? resolveError;
  Purchase? requestResult;
  AppException? requestError;
  Completer<void>? delay;

  int resolveCallCount = 0;
  int requestCallCount = 0;
  String? lastToken;
  PurchaseRequestTarget? lastTarget;
  double? lastBillAmount;
  String? lastIdempotencyKey;

  /// Whether the last request asked to spend coins on the same bill.
  bool? lastRedeem;

  @override
  Future<MerchantPurchaseQrResolution> resolveMerchantQr(String token) async {
    resolveCallCount++;
    lastToken = token;
    if (resolveError != null) throw resolveError!;
    return resolution!;
  }

  @override
  Future<CounterPurchaseResult> requestPurchase({
    required PurchaseRequestTarget target,
    required double billAmount,
    required String idempotencyKey,
    bool redeem = false,
  }) async {
    requestCallCount++;
    lastTarget = target;
    lastBillAmount = billAmount;
    lastIdempotencyKey = idempotencyKey;
    lastRedeem = redeem;
    if (delay != null) await delay!.future;
    if (requestError != null) throw requestError!;
    return CounterPurchaseResult(purchase: requestResult!);
  }

  @override
  Future<Purchase> show(int id) async => throw UnimplementedError();

  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => throw UnimplementedError();
}

const _wallet = SilverWalletBalance(
  balance: 800,
  universalBalance: 800,
  shopExclusiveBalance: 0,
  shopExclusiveBreakdown: [],
  balanceInrEquivalent: 80,
  // Written at the old 10-coins-per-rupee rate; the rate rides along with
  // the wallet so 800 coins and ₹80 keep agreeing.
  coinToInrRate: 10,
  updatedAt: null,
);

/// The controller reads the wallet for its savings estimate; tests hand it
/// a fixed balance rather than letting it reach for the network.
class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async => _wallet;

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => throw UnimplementedError();
}

/// Only `show()` matters here: it is what the controller falls back to when
/// a merchant target arrives with nothing but ids.
class _FakeMerchantsRepository implements MerchantsRepository {
  _FakeMerchantsRepository({this.merchant, this.showError});

  Merchant? merchant;
  AppException? showError;
  int showCallCount = 0;

  @override
  Future<Merchant> show(int id) async {
    showCallCount++;
    if (showError != null) throw showError!;
    return merchant!;
  }

  @override
  Future<OffsetPage<Merchant>> list({
    int page = 1,
    int perPage = 20,
    int? categoryId,
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

ProviderContainer _container(FakePurchasesRepository repository, {MerchantsRepository? merchants}) {
  final container = ProviderContainer(
    overrides: [
      purchasesRepositoryProvider.overrideWithValue(repository),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      if (merchants != null) merchantsRepositoryProvider.overrideWithValue(merchants),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// A merchant that takes Town Coin at 7% of the bill.
const _resolution = MerchantPurchaseQrResolution(
  merchantId: 42,
  merchantName: 'Corner Cafe',
  branchId: 7,
  branchName: 'Main Branch',
  branchAddressLine: 'MG Road',
  acceptsTownCoin: true,
  discountRate: 7,
);

Purchase _pendingPurchase() {
  return Purchase(
    id: 1,
    merchantId: 42,
    merchant: const PurchaseMerchantRef(id: 42, name: 'Corner Cafe'),
    branch: const PurchaseMerchantRef(id: 7, name: 'Main Branch'),
    billAmount: 500,
    currency: 'INR',
    billReference: null,
    coinsAwarded: 0,
    couponsIssued: null,
    status: 'pending',
    reviewedAt: null,
    rejectionReason: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('CustomerPurchaseRequestController', () {
    test('initial state has no resolution/amount and cannot submit', () {
      final container = _container(FakePurchasesRepository());

      final state = container.read(customerPurchaseRequestControllerProvider);

      expect(state.resolution, isNull);
      expect(state.billAmount, isNull);
      expect(state.canSubmit, isFalse);
      expect(state.step, CounterStep.amount);
      expect(state.idempotencyKey, isNotEmpty);
    });

    test('resolveScannedToken resolves the merchant/branch and clears a prior error', () async {
      final fake = FakePurchasesRepository(resolution: _resolution);
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('tok_123');

      expect(fake.resolveCallCount, 1);
      expect(fake.lastToken, 'tok_123');
      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isResolving, isFalse);
      expect(state.resolution?.merchantName, 'Corner Cafe');
      expect(state.resolveError, isNull);
    });

    test('resolveScannedToken surfaces an invalid/revoked QR error without a resolution', () async {
      final fake = FakePurchasesRepository(resolveError: const NotFoundException());
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('bad_token');

      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isResolving, isFalse);
      expect(state.resolution, isNull);
      expect(state.resolveError, isA<NotFoundException>());
    });

    test('billAmount rejects values outside the backend\'s 0.01-1000000 bound', () {
      final container = _container(FakePurchasesRepository());
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      notifier.setBillAmount('0');
      expect(container.read(customerPurchaseRequestControllerProvider).billAmount, isNull);

      notifier.setBillAmount('1000001');
      expect(container.read(customerPurchaseRequestControllerProvider).billAmount, isNull);

      notifier.setBillAmount('500.50');
      expect(container.read(customerPurchaseRequestControllerProvider).billAmount, 500.50);
    });

    test('setBillAmount rotates the Idempotency-Key, re-setting the same text is a no-op', () {
      final container = _container(FakePurchasesRepository());
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      final initialKey = container.read(customerPurchaseRequestControllerProvider).idempotencyKey;
      notifier.setBillAmount('500');
      final afterFirstSet = container.read(customerPurchaseRequestControllerProvider).idempotencyKey;
      notifier.setBillAmount('500');
      final afterReset = container.read(customerPurchaseRequestControllerProvider).idempotencyKey;
      notifier.setBillAmount('750');
      final afterChange = container.read(customerPurchaseRequestControllerProvider).idempotencyKey;

      expect(afterFirstSet, isNot(initialKey));
      expect(afterReset, afterFirstSet);
      expect(afterChange, isNot(afterFirstSet));
    });

    test('turning redeeming off or on is part of the request, so it rotates the Idempotency-Key too', () {
      final container = _container(FakePurchasesRepository());
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      final before = container.read(customerPurchaseRequestControllerProvider).idempotencyKey;
      notifier.setRedeem(false);

      expect(container.read(customerPurchaseRequestControllerProvider).redeem, isFalse);
      expect(container.read(customerPurchaseRequestControllerProvider).idempotencyKey, isNot(before));
    });

    test('Continue needs a resolution and a valid amount; paying also needs the review step', () async {
      final fake = FakePurchasesRepository(resolution: _resolution);
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);
      CustomerPurchaseRequestState read() => container.read(customerPurchaseRequestControllerProvider);

      expect(read().canContinue, isFalse);

      await notifier.resolveScannedToken('tok_123');
      expect(read().canContinue, isFalse);

      notifier.setBillAmount('500');
      expect(read().canContinue, isTrue);
      expect(read().canSubmit, isFalse);

      notifier.review();
      expect(read().step, CounterStep.review);
      expect(read().canSubmit, isTrue);

      notifier.backToAmount();
      expect(read().step, CounterStep.amount);
      expect(read().canSubmit, isFalse);
    });

    test('submit() sends the scanned token/amount/Idempotency-Key, asks to redeem, and moves to waiting', () async {
      final fake = FakePurchasesRepository(resolution: _resolution, requestResult: _pendingPurchase());
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('tok_123');
      notifier.setBillAmount('500');
      notifier.review();
      final expectedKey = container.read(customerPurchaseRequestControllerProvider).idempotencyKey;
      await notifier.submit();

      expect(fake.requestCallCount, 1);
      expect(fake.lastTarget, isA<ScannedPurchaseTarget>().having((t) => t.token, 'token', 'tok_123'));
      expect(fake.lastBillAmount, 500);
      expect(fake.lastIdempotencyKey, expectedKey);
      expect(fake.lastRedeem, isTrue);

      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.step, CounterStep.waiting);
      expect(state.result?.status, 'pending');
      expect(state.result?.coinsAwarded, 0);
    });

    test('submit() is a no-op while unresolved or the amount is missing', () async {
      final fake = FakePurchasesRepository(resolution: _resolution, requestResult: _pendingPurchase());
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.submit();
      expect(fake.requestCallCount, 0);

      await notifier.resolveScannedToken('tok_123');
      await notifier.submit();
      expect(fake.requestCallCount, 0);
    });

    test('a failed submit() sets the error, clears isSubmitting, and preserves the resolution/amount', () async {
      final fake = FakePurchasesRepository(resolution: _resolution, requestError: const NetworkException());
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('tok_123');
      notifier.setBillAmount('500');
      notifier.review();
      await notifier.submit();

      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.submitError, isA<NetworkException>());
      expect(state.step, CounterStep.review);
      expect(state.resolution?.merchantName, 'Corner Cafe');
      expect(state.billAmountText, '500');
    });

    test('a second submit() call while the first is still in flight is a no-op (duplicate-tap guard)', () async {
      final delay = Completer<void>();
      final fake = FakePurchasesRepository(resolution: _resolution, requestResult: _pendingPurchase(), delay: delay);
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('tok_123');
      notifier.setBillAmount('500');
      notifier.review();

      final first = notifier.submit();
      expect(container.read(customerPurchaseRequestControllerProvider).isSubmitting, isTrue);
      final second = notifier.submit();

      delay.complete();
      await first;
      await second;

      expect(fake.requestCallCount, 1);
    });
  });

  // The estimate the customer sees before paying. It has to use the same
  // two caps as the server's RedemptionCalculator, or the "You save" figure
  // and the real discount disagree at the counter.
  group('savings estimate', () {
    CustomerPurchaseRequestState stateFor(
      String amount, {
      bool redeem = true,
      MerchantPurchaseQrResolution resolution = _resolution,
    }) {
      return CustomerPurchaseRequestState(
        idempotencyKey: 'key',
        resolution: resolution,
        billAmountText: amount,
        walletBalance: _wallet,
        redeem: redeem,
      );
    }

    test('is the merchant\'s rate of the bill when the coins cover it', () {
      final state = stateFor('1000');
      expect(state.estimatedDiscount, 70);
      expect(state.estimatedPayable, 930);
    });

    test('is capped at what the coins are worth', () {
      final state = stateFor('5000');
      expect(state.estimatedDiscount, 80);
      expect(state.estimatedPayable, 4920);
    });

    test('is zero when the customer turns redeeming off', () {
      expect(stateFor('1000', redeem: false).estimatedDiscount, 0);
    });

    test('is zero at a merchant that doesn\'t take Town Coin', () {
      const noCoins = MerchantPurchaseQrResolution(
        merchantId: 1,
        merchantName: 'Cash Only Traders',
        branchId: 1,
        branchName: 'Main',
        branchAddressLine: null,
        acceptsTownCoin: false,
        discountRate: 7,
      );
      expect(stateFor('1000', resolution: noCoins).estimatedDiscount, 0);
    });
  });

  group('start() with a merchant from its profile ("Pay bill with coins", no scan)', () {
    final merchant = Merchant.fromJson({
      'id': 42,
      'name': 'Corner Cafe',
      'accepts_town_coin': true,
      'discount_rate': 7,
      'branch': {'id': 7, 'name': 'Main Branch', 'address_line': 'MG Road'},
    });

    test('is ready at once, with the profile as the resolution and no resolve call', () async {
      final fake = FakePurchasesRepository();
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.start(PurchaseRequestTarget.merchant(merchant));

      expect(fake.resolveCallCount, 0);
      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isResolving, isFalse);
      expect(state.resolveError, isNull);
      expect(state.resolution?.merchantName, 'Corner Cafe');
      expect(state.resolution?.branchName, 'Main Branch');
      expect(state.resolution?.canDiscount, isTrue);
    });

    test('submit() names the merchant and its branch instead of a token', () async {
      final fake = FakePurchasesRepository(requestResult: _pendingPurchase());
      final container = _container(fake);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.start(PurchaseRequestTarget.merchant(merchant));
      notifier.setBillAmount('500');
      notifier.review();
      await notifier.submit();

      expect(fake.requestCallCount, 1);
      final target = fake.lastTarget;
      expect(target, isA<MerchantPurchaseTarget>());
      expect(target!.toRequestJson(), {'merchant_id': 42, 'branch_id': 7});
      expect(container.read(customerPurchaseRequestControllerProvider).step, CounterStep.waiting);
    });

    // On web GoRouter JSON-encodes the extra into browser history and hands
    // the decoded map back on a rebuild, so the profile snapshot is gone and
    // only the ids remain. This is exactly the shape the route rebuilds.
    PurchaseRequestTarget afterBrowserRoundTrip(PurchaseRequestTarget target) =>
        PurchaseRequestTarget.fromExtra(jsonDecode(jsonEncode(target)));

    test('with only the ids left after a browser round trip, fetches the profile by id -- still no scan', () async {
      final fake = FakePurchasesRepository();
      final merchants = _FakeMerchantsRepository(merchant: merchant);
      final container = _container(fake, merchants: merchants);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      final target = afterBrowserRoundTrip(PurchaseRequestTarget.merchant(merchant));
      expect(target, isA<MerchantPurchaseTarget>().having((t) => t.merchant, 'merchant', isNull));

      await notifier.start(target);

      expect(merchants.showCallCount, 1);
      expect(fake.resolveCallCount, 0);
      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isResolving, isFalse);
      expect(state.resolution?.merchantName, 'Corner Cafe');
      expect(state.resolution?.branchName, 'Main Branch');
      expect(state.resolution?.canDiscount, isTrue);
    });

    test('a merchant that can no longer be fetched surfaces as a resolve error, like a bad QR', () async {
      final merchants = _FakeMerchantsRepository(showError: const NotFoundException());
      final container = _container(FakePurchasesRepository(), merchants: merchants);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.start(PurchaseRequestTarget.merchantId(42, branchId: 7));

      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isResolving, isFalse);
      expect(state.resolution, isNull);
      expect(state.resolveError, isA<NotFoundException>());
    });
  });
}
