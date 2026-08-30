import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/redemptions/application/pending_otp_codes_provider.dart';
import 'package:customer/features/redemptions/application/redemption_initiation_controller.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:customer/features/redemptions/data/models/redemption_initiation_result.dart';
import 'package:customer/features/redemptions/data/redemptions_repository.dart';

class FakeRedemptionsRepository implements RedemptionsRepository {
  FakeRedemptionsRepository({this.result, this.error, this.delay});

  RedemptionInitiationResult? result;
  AppException? error;
  Completer<void>? delay;

  int initiateCallCount = 0;
  int? lastMerchantId;
  int? lastBranchId;
  double? lastBillAmount;
  String? lastIdempotencyKey;

  @override
  Future<RedemptionInitiationResult> initiate({
    required int merchantId,
    required int branchId,
    required double billAmount,
    required String idempotencyKey,
  }) async {
    initiateCallCount++;
    lastMerchantId = merchantId;
    lastBranchId = branchId;
    lastBillAmount = billAmount;
    lastIdempotencyKey = idempotencyKey;

    if (delay != null) await delay!.future;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<Redemption> show(int id) async => throw UnimplementedError();

  @override
  Future<OffsetPage<Redemption>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();
}

RedemptionInitiationResult _result({int id = 1, String? otpCode = '123456'}) {
  return RedemptionInitiationResult(
    redemption: Redemption(
      id: id,
      merchant: const RedemptionMerchantRef(id: 42, name: 'Test Merchant'),
      branch: const RedemptionMerchantRef(id: 7, name: 'Main Branch'),
      billAmount: 500,
      discountAmount: null,
      remainingBillAmount: null,
      coinsRequested: 250,
      coinsDebited: null,
      status: 'initiated',
      verificationMethod: null,
      verifiedAt: null,
      createdAt: DateTime(2026, 1, 1),
    ),
    otpCode: otpCode,
  );
}

void main() {
  group('RedemptionInitiationController', () {
    test('initial state has no branch/amount selected and cannot submit', () {
      final container = ProviderContainer(
        overrides: [redemptionsRepositoryProvider.overrideWithValue(FakeRedemptionsRepository())],
      );
      addTearDown(container.dispose);

      final state = container.read(redemptionInitiationControllerProvider(42));

      expect(state.selectedBranchId, isNull);
      expect(state.billAmount, isNull);
      expect(state.canSubmit, isFalse);
      expect(state.idempotencyKey, isNotEmpty);
    });

    test('selectBranch sets the branch and becomes a no-op on reselecting the same branch', () {
      final container = ProviderContainer(
        overrides: [redemptionsRepositoryProvider.overrideWithValue(FakeRedemptionsRepository())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      notifier.selectBranch(7);
      final afterFirstSelect = container.read(redemptionInitiationControllerProvider(42));
      notifier.selectBranch(7);
      final afterReselect = container.read(redemptionInitiationControllerProvider(42));

      expect(afterFirstSelect.selectedBranchId, 7);
      // Re-selecting the same branch must not rotate the Idempotency-Key —
      // otherwise a genuine retry would look like a brand-new request.
      expect(afterReselect.idempotencyKey, afterFirstSelect.idempotencyKey);
    });

    test('selecting a different branch rotates the Idempotency-Key', () {
      final container = ProviderContainer(
        overrides: [redemptionsRepositoryProvider.overrideWithValue(FakeRedemptionsRepository())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      notifier.selectBranch(7);
      final firstKey = container.read(redemptionInitiationControllerProvider(42)).idempotencyKey;
      notifier.selectBranch(8);
      final secondKey = container.read(redemptionInitiationControllerProvider(42)).idempotencyKey;

      expect(secondKey, isNot(firstKey));
    });

    test('billAmount rejects values outside the backend\'s 0.01-1000000 bound', () {
      final container = ProviderContainer(
        overrides: [redemptionsRepositoryProvider.overrideWithValue(FakeRedemptionsRepository())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      notifier.setBillAmount('0');
      expect(container.read(redemptionInitiationControllerProvider(42)).billAmount, isNull);

      notifier.setBillAmount('1000001');
      expect(container.read(redemptionInitiationControllerProvider(42)).billAmount, isNull);

      notifier.setBillAmount('500.50');
      expect(container.read(redemptionInitiationControllerProvider(42)).billAmount, 500.50);
    });

    test('canSubmit is true only once both a branch and a valid amount are set', () {
      final container = ProviderContainer(
        overrides: [redemptionsRepositoryProvider.overrideWithValue(FakeRedemptionsRepository())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      expect(container.read(redemptionInitiationControllerProvider(42)).canSubmit, isFalse);

      notifier.selectBranch(7);
      expect(container.read(redemptionInitiationControllerProvider(42)).canSubmit, isFalse);

      notifier.setBillAmount('500');
      expect(container.read(redemptionInitiationControllerProvider(42)).canSubmit, isTrue);
    });

    test('submit() sends the exact merchant/branch/amount/Idempotency-Key and stashes the OTP code', () async {
      final fake = FakeRedemptionsRepository(result: _result());
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      notifier.selectBranch(7);
      notifier.setBillAmount('500');
      final expectedKey = container.read(redemptionInitiationControllerProvider(42)).idempotencyKey;
      await notifier.submit();

      expect(fake.initiateCallCount, 1);
      expect(fake.lastMerchantId, 42);
      expect(fake.lastBranchId, 7);
      expect(fake.lastBillAmount, 500);
      expect(fake.lastIdempotencyKey, expectedKey);

      final state = container.read(redemptionInitiationControllerProvider(42));
      expect(state.isSubmitting, isFalse);
      expect(state.result?.redemption.id, 1);
      expect(container.read(pendingOtpCodesProvider.notifier).consume(1), '123456');
    });

    test('submit() is a no-op while a branch or amount is missing', () async {
      final fake = FakeRedemptionsRepository(result: _result());
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      await notifier.submit();

      expect(fake.initiateCallCount, 0);
    });

    test('a failed submit() sets the error, clears isSubmitting, and preserves the branch/amount', () async {
      final fake = FakeRedemptionsRepository(error: const NetworkException());
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      notifier.selectBranch(7);
      notifier.setBillAmount('500');
      await notifier.submit();

      final state = container.read(redemptionInitiationControllerProvider(42));
      expect(state.isSubmitting, isFalse);
      expect(state.error, isA<NetworkException>());
      expect(state.selectedBranchId, 7);
      expect(state.billAmountText, '500');
    });

    test('a second submit() call while the first is still in flight is a no-op (duplicate-tap guard)', () async {
      final delay = Completer<void>();
      final fake = FakeRedemptionsRepository(result: _result(), delay: delay);
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      final notifier = container.read(redemptionInitiationControllerProvider(42).notifier);

      notifier.selectBranch(7);
      notifier.setBillAmount('500');

      final first = notifier.submit();
      expect(container.read(redemptionInitiationControllerProvider(42)).isSubmitting, isTrue);
      final second = notifier.submit();

      delay.complete();
      await first;
      await second;

      expect(fake.initiateCallCount, 1);
    });
  });
}
