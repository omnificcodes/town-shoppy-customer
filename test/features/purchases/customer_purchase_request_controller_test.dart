import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/purchases/application/customer_purchase_request_controller.dart';
import 'package:customer/features/purchases/data/models/merchant_purchase_qr_resolution.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';

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
  double? lastBillAmount;
  String? lastIdempotencyKey;

  @override
  Future<MerchantPurchaseQrResolution> resolveMerchantQr(String token) async {
    resolveCallCount++;
    lastToken = token;
    if (resolveError != null) throw resolveError!;
    return resolution!;
  }

  @override
  Future<Purchase> requestPurchase({
    required String token,
    required double billAmount,
    required String idempotencyKey,
  }) async {
    requestCallCount++;
    lastToken = token;
    lastBillAmount = billAmount;
    lastIdempotencyKey = idempotencyKey;
    if (delay != null) await delay!.future;
    if (requestError != null) throw requestError!;
    return requestResult!;
  }

  @override
  Future<Purchase> show(int id) async => throw UnimplementedError();

  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => throw UnimplementedError();
}

const _resolution = MerchantPurchaseQrResolution(
  merchantId: 42,
  merchantName: 'Corner Cafe',
  branchId: 7,
  branchName: 'Main Branch',
  branchAddressLine: 'MG Road',
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
      final container = ProviderContainer(
        overrides: [purchasesRepositoryProvider.overrideWithValue(FakePurchasesRepository())],
      );
      addTearDown(container.dispose);

      final state = container.read(customerPurchaseRequestControllerProvider);

      expect(state.resolution, isNull);
      expect(state.billAmount, isNull);
      expect(state.canSubmit, isFalse);
      expect(state.idempotencyKey, isNotEmpty);
    });

    test('resolveScannedToken resolves the merchant/branch and clears a prior error', () async {
      final fake = FakePurchasesRepository(resolution: _resolution);
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
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
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('bad_token');

      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isResolving, isFalse);
      expect(state.resolution, isNull);
      expect(state.resolveError, isA<NotFoundException>());
    });

    test('billAmount rejects values outside the backend\'s 0.01-1000000 bound', () {
      final container = ProviderContainer(
        overrides: [purchasesRepositoryProvider.overrideWithValue(FakePurchasesRepository())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      notifier.setBillAmount('0');
      expect(container.read(customerPurchaseRequestControllerProvider).billAmount, isNull);

      notifier.setBillAmount('1000001');
      expect(container.read(customerPurchaseRequestControllerProvider).billAmount, isNull);

      notifier.setBillAmount('500.50');
      expect(container.read(customerPurchaseRequestControllerProvider).billAmount, 500.50);
    });

    test('setBillAmount rotates the Idempotency-Key, re-setting the same text is a no-op', () {
      final container = ProviderContainer(
        overrides: [purchasesRepositoryProvider.overrideWithValue(FakePurchasesRepository())],
      );
      addTearDown(container.dispose);
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

    test('canSubmit is true only once both a resolution and a valid amount are set', () async {
      final fake = FakePurchasesRepository(resolution: _resolution);
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      expect(container.read(customerPurchaseRequestControllerProvider).canSubmit, isFalse);

      await notifier.resolveScannedToken('tok_123');
      expect(container.read(customerPurchaseRequestControllerProvider).canSubmit, isFalse);

      notifier.setBillAmount('500');
      expect(container.read(customerPurchaseRequestControllerProvider).canSubmit, isTrue);
    });

    test('submit() sends the scanned token/amount/Idempotency-Key and yields a pending result', () async {
      final fake = FakePurchasesRepository(resolution: _resolution, requestResult: _pendingPurchase());
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('tok_123');
      notifier.setBillAmount('500');
      final expectedKey = container.read(customerPurchaseRequestControllerProvider).idempotencyKey;
      await notifier.submit();

      expect(fake.requestCallCount, 1);
      expect(fake.lastToken, 'tok_123');
      expect(fake.lastBillAmount, 500);
      expect(fake.lastIdempotencyKey, expectedKey);

      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.result?.status, 'pending');
      expect(state.result?.coinsAwarded, 0);
    });

    test('submit() is a no-op while unresolved or the amount is missing', () async {
      final fake = FakePurchasesRepository(resolution: _resolution, requestResult: _pendingPurchase());
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.submit();
      expect(fake.requestCallCount, 0);

      await notifier.resolveScannedToken('tok_123');
      await notifier.submit();
      expect(fake.requestCallCount, 0);
    });

    test('a failed submit() sets the error, clears isSubmitting, and preserves the resolution/amount', () async {
      final fake = FakePurchasesRepository(resolution: _resolution, requestError: const NetworkException());
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('tok_123');
      notifier.setBillAmount('500');
      await notifier.submit();

      final state = container.read(customerPurchaseRequestControllerProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.submitError, isA<NetworkException>());
      expect(state.resolution?.merchantName, 'Corner Cafe');
      expect(state.billAmountText, '500');
    });

    test('a second submit() call while the first is still in flight is a no-op (duplicate-tap guard)', () async {
      final delay = Completer<void>();
      final fake = FakePurchasesRepository(resolution: _resolution, requestResult: _pendingPurchase(), delay: delay);
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(customerPurchaseRequestControllerProvider.notifier);

      await notifier.resolveScannedToken('tok_123');
      notifier.setBillAmount('500');

      final first = notifier.submit();
      expect(container.read(customerPurchaseRequestControllerProvider).isSubmitting, isTrue);
      final second = notifier.submit();

      delay.complete();
      await first;
      await second;

      expect(fake.requestCallCount, 1);
    });
  });
}
