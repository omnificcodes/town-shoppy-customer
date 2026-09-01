import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/coupons/application/coupon_detail_provider.dart';
import 'package:customer/features/coupons/data/coupons_repository.dart';
import 'package:customer/features/coupons/data/models/coupon.dart';

class FakeCouponsRepository implements CouponsRepository {
  FakeCouponsRepository({this.coupon, this.error});

  final Coupon? coupon;
  final AppException? error;

  @override
  Future<Coupon> show(int id) async {
    if (error != null) throw error!;
    return coupon!;
  }

  @override
  Future<OffsetPage<Coupon>> list({int page = 1, int perPage = 20}) async => throw UnimplementedError();
}

void main() {
  test('couponDetailProvider surfaces the loaded coupon', () async {
    final coupon = Coupon(
      id: 5,
      code: 'ABCD1234EFGH',
      status: 'active',
      sourceType: 'purchase',
      eligibilities: const [
        CouponEligibility(cadence: 'weekly', status: 'active'),
        CouponEligibility(cadence: 'monthly', status: 'active'),
        CouponEligibility(cadence: 'mega', status: 'closed'),
      ],
      issuedAt: DateTime(2026, 1, 1),
      annualCycleExpiresAt: DateTime(2027, 1, 1),
    );
    final container = ProviderContainer(
      overrides: [couponsRepositoryProvider.overrideWithValue(FakeCouponsRepository(coupon: coupon))],
    );
    addTearDown(container.dispose);

    final result = await container.read(couponDetailProvider(5).future);

    expect(result.code, 'ABCD1234EFGH');
    expect(result.eligibilityFor('mega')?.status, 'closed');
    expect(result.eligibilityFor('weekly')?.isActive, isTrue);
  });

  test('couponDetailProvider surfaces a 404 for an unavailable coupon', () async {
    final container = ProviderContainer(
      overrides: [couponsRepositoryProvider.overrideWithValue(FakeCouponsRepository(error: const NotFoundException()))],
    );
    addTearDown(container.dispose);

    // Riverpod 3.3.2 auto-retries a failed provider build with backoff, so
    // it stays in `AsyncLoading(error: ..., retrying)` rather than settling
    // into `AsyncError` -- `hasError`/`error` are the version-stable way to
    // observe the failure here (mirrors purchase_detail_provider_test.dart).
    var state = container.read(couponDetailProvider(999));
    for (var i = 0; i < 50 && !state.hasError; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = container.read(couponDetailProvider(999));
    }

    expect(state.hasError, isTrue);
    expect(state.error, isA<NotFoundException>());
  });
}
