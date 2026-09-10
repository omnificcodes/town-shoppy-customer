import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/coupons/application/coupons_list_controller.dart';
import 'package:customer/features/coupons/data/coupons_repository.dart';
import 'package:customer/features/coupons/data/models/coupon.dart';

Coupon _coupon(int id, {String status = 'active'}) {
  return Coupon(
    id: id,
    code: 'COUPON$id',
    status: status,
    sourceType: 'purchase',
    eligibilities: const [
      CouponEligibility(cadence: 'weekly', status: 'active'),
      CouponEligibility(cadence: 'monthly', status: 'active'),
      CouponEligibility(cadence: 'mega', status: 'active'),
    ],
    merchant: null,
    issuedAt: DateTime(2026, 1, 1),
    annualCycleExpiresAt: DateTime(2027, 1, 1),
  );
}

/// Scripted fake -- same shape as `purchases_list_controller_test.dart`'s
/// `FakePurchasesRepository`, duplicated per-file rather than shared.
class FakeCouponsRepository implements CouponsRepository {
  final List<Object> _responses = [];
  int listCallCount = 0;

  void queuePage(OffsetPage<Coupon> page) => _responses.add(page);
  void queueError(AppException error) => _responses.add(error);

  @override
  Future<OffsetPage<Coupon>> list({int page = 1, int perPage = 20, String? status}) async {
    listCallCount++;
    final next = _responses.first;
    if (next is AppException) throw next;
    _responses.removeAt(0);
    return next as OffsetPage<Coupon>;
  }

  @override
  Future<Coupon> show(int id) async => throw UnimplementedError();
}

/// Polls until the controller's [AsyncValue] reports an error -- Riverpod
/// 3.3.2 auto-retries a failed provider build with backoff, so it stays in
/// `AsyncLoading(error: ..., retrying)` rather than settling into a plain
/// `AsyncError`; see the identical helper in
/// `redemptions_list_controller_test.dart`/`purchases_list_controller_test.dart`.
Future<AsyncValue<CouponsListState>> _pollForError(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(couponsListControllerProvider);
    if (state.hasError) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Provider never reported an error');
}

void main() {
  group('CouponsListController', () {
    test('loads the first page successfully', () async {
      final fake = FakeCouponsRepository()
        ..queuePage(OffsetPage(items: [_coupon(1), _coupon(2)], currentPage: 1, lastPage: 2, total: 3));
      final container = ProviderContainer(overrides: [couponsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(couponsListControllerProvider.future);

      expect(state.items, hasLength(2));
      expect(state.hasMore, isTrue);
      expect(fake.listCallCount, 1);
    });

    test('surfaces an empty list distinctly from a failure', () async {
      final fake = FakeCouponsRepository()..queuePage(const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0));
      final container = ProviderContainer(overrides: [couponsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(couponsListControllerProvider.future);

      expect(state.items, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('propagates a backend error', () async {
      final fake = FakeCouponsRepository()..queueError(const NetworkException());
      final container = ProviderContainer(overrides: [couponsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await _pollForError(container);

      expect(state.error, isA<NetworkException>());
    });

    test('loadMore appends the next page and tracks currentPage/hasMore', () async {
      final fake = FakeCouponsRepository()
        ..queuePage(OffsetPage(items: [_coupon(1)], currentPage: 1, lastPage: 2, total: 2))
        ..queuePage(OffsetPage(items: [_coupon(2)], currentPage: 2, lastPage: 2, total: 2));
      final container = ProviderContainer(overrides: [couponsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      await container.read(couponsListControllerProvider.future);

      await container.read(couponsListControllerProvider.notifier).loadMore();

      final state = container.read(couponsListControllerProvider).value!;
      expect(state.items.map((c) => c.id), [1, 2]);
      expect(state.hasMore, isFalse);
      expect(fake.listCallCount, 2);
    });

    test('refresh re-fetches page 1 from the repository', () async {
      final fake = FakeCouponsRepository()
        ..queuePage(OffsetPage(items: [_coupon(1)], currentPage: 1, lastPage: 1, total: 1))
        ..queuePage(OffsetPage(items: [_coupon(1), _coupon(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(overrides: [couponsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      await container.read(couponsListControllerProvider.future);

      await container.read(couponsListControllerProvider.notifier).refresh();

      final state = container.read(couponsListControllerProvider).value!;
      expect(state.items, hasLength(2));
      expect(fake.listCallCount, 2);
    });
  });
}
