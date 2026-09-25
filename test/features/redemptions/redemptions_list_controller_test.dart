import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/redemptions/application/redemptions_list_controller.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:customer/features/redemptions/data/redemptions_repository.dart';

Redemption _redemption(int id) {
  return Redemption(
    id: id,
    merchant: const RedemptionMerchantRef(id: 1, name: 'Test Merchant'),
    branch: null,
    billAmount: 300,
    discountAmount: null,
    remainingBillAmount: null,
    coinsRequested: 100,
    coinsDebited: null,
    status: 'initiated',
    verificationMethod: null,
    verifiedAt: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// See `purchases_list_controller_test.dart`'s identical fake for why a
/// queued error is peeked, not popped: Riverpod 3.3.2 auto-retries a failed
/// provider build, so the fake must keep failing the same way on every
/// retry rather than running out of scripted responses.
class FakeRedemptionsRepository implements RedemptionsRepository {
  final List<Object> _responses = [];
  int listCallCount = 0;

  void queuePage(OffsetPage<Redemption> page) => _responses.add(page);
  void queueError(AppException error) => _responses.add(error);

  @override
  Future<OffsetPage<Redemption>> list({int page = 1, int perPage = 20}) async {
    listCallCount++;
    final next = _responses.first;
    if (next is AppException) throw next;
    _responses.removeAt(0);
    return next as OffsetPage<Redemption>;
  }

  @override
  Future<Redemption> show(int id) async => throw UnimplementedError();
}

/// Polls until the controller's [AsyncValue] reports an error — see the
/// identical helper in `purchases_list_controller_test.dart` for why.
Future<AsyncValue<RedemptionsListState>> _pollForError(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(redemptionsListControllerProvider);
    if (state.hasError) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Provider never reported an error');
}

void main() {
  group('RedemptionsListController', () {
    test('loads the first page successfully', () async {
      final fake = FakeRedemptionsRepository()
        ..queuePage(OffsetPage(items: [_redemption(1), _redemption(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(redemptionsListControllerProvider.future);

      expect(state.items, hasLength(2));
      expect(state.hasMore, isFalse);
    });

    test('surfaces an empty list distinctly from a failure', () async {
      final fake = FakeRedemptionsRepository()..queuePage(const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0));
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(redemptionsListControllerProvider.future);

      expect(state.items, isEmpty);
    });

    test('propagates a backend error', () async {
      final fake = FakeRedemptionsRepository()..queueError(const ServerException());
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await _pollForError(container);

      expect(state.error, isA<ServerException>());
    });

    test('loadMore appends the next page and tracks currentPage/hasMore', () async {
      final fake = FakeRedemptionsRepository()
        ..queuePage(OffsetPage(items: [_redemption(1)], currentPage: 1, lastPage: 2, total: 2))
        ..queuePage(OffsetPage(items: [_redemption(2)], currentPage: 2, lastPage: 2, total: 2));
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(redemptionsListControllerProvider.future);
      await container.read(redemptionsListControllerProvider.notifier).loadMore();

      final state = container.read(redemptionsListControllerProvider).value!;
      expect(state.items.map((r) => r.id), [1, 2]);
      expect(state.hasMore, isFalse);
    });

    test('refresh re-fetches page 1 from the repository', () async {
      final fake = FakeRedemptionsRepository()
        ..queuePage(OffsetPage(items: [_redemption(1)], currentPage: 1, lastPage: 1, total: 1))
        ..queuePage(OffsetPage(items: [_redemption(1), _redemption(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(overrides: [redemptionsRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(redemptionsListControllerProvider.future);
      await container.read(redemptionsListControllerProvider.notifier).refresh();

      expect(fake.listCallCount, 2);
      expect(container.read(redemptionsListControllerProvider).value!.items, hasLength(2));
    });
  });
}
