import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/purchases/application/purchases_list_controller.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/purchases/data/purchases_repository.dart';

Purchase _purchase(int id) {
  return Purchase(
    id: id,
    merchantId: 1,
    merchant: const PurchaseMerchantRef(id: 1, name: 'Test Merchant'),
    branch: null,
    billAmount: 100,
    currency: 'INR',
    billReference: null,
    coinsAwarded: 10,
    couponsIssued: null,
    status: 'recorded',
    createdAt: DateTime(2026, 1, 1),
  );
}

/// A scripted fake — each call to [list] pops the next page queued for it,
/// so a test can arrange exactly the sequence a real paginated flow
/// (initial load, then a load-more, then a refresh) would produce. A queued
/// error is left in place (not popped) rather than consumed: Riverpod 3.3.2
/// auto-retries a failed provider build with backoff, so a real repository
/// (and this fake) must keep failing the same way on every retry, not run
/// out of scripted responses.
class FakePurchasesRepository implements PurchasesRepository {
  final List<Object> _responses = [];
  int listCallCount = 0;

  void queuePage(OffsetPage<Purchase> page) => _responses.add(page);
  void queueError(AppException error) => _responses.add(error);

  @override
  Future<OffsetPage<Purchase>> list({int page = 1, int perPage = 20}) async {
    listCallCount++;
    final next = _responses.first;
    if (next is AppException) throw next;
    _responses.removeAt(0);
    return next as OffsetPage<Purchase>;
  }

  @override
  Future<Purchase> show(int id) async => throw UnimplementedError();

  @override
  Future<List<Purchase>> recent({int limit = 3}) async => throw UnimplementedError();
}

/// Polls the controller until its [AsyncValue] reports an error — Riverpod
/// 3.3.2 keeps a failed provider in `AsyncLoading(error: ..., retrying)`
/// while it auto-retries rather than settling into a plain `AsyncError`, so
/// `hasError`/`error` (which are set on both variants) is the only
/// version-stable way to observe a failure from a test.
Future<AsyncValue<PurchasesListState>> _pollForError(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(purchasesListControllerProvider);
    if (state.hasError) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Provider never reported an error');
}

void main() {
  group('PurchasesListController', () {
    test('loads the first page successfully', () async {
      final fake = FakePurchasesRepository()
        ..queuePage(OffsetPage(items: [_purchase(1), _purchase(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(purchasesListControllerProvider.future);

      expect(state.items, hasLength(2));
      expect(state.hasMore, isFalse);
    });

    test('surfaces an empty list distinctly from a failure', () async {
      final fake = FakePurchasesRepository()..queuePage(const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0));
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(purchasesListControllerProvider.future);

      expect(state.items, isEmpty);
    });

    test('propagates a backend error, not a silent empty list', () async {
      final fake = FakePurchasesRepository()..queueError(const NetworkException());
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await _pollForError(container);

      expect(state.error, isA<NetworkException>());
    });

    test('loadMore appends the next page and tracks currentPage/hasMore', () async {
      final fake = FakePurchasesRepository()
        ..queuePage(OffsetPage(items: [_purchase(1)], currentPage: 1, lastPage: 2, total: 2))
        ..queuePage(OffsetPage(items: [_purchase(2)], currentPage: 2, lastPage: 2, total: 2));
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(purchasesListControllerProvider.future);
      expect(container.read(purchasesListControllerProvider).value!.hasMore, isTrue);

      await container.read(purchasesListControllerProvider.notifier).loadMore();

      final state = container.read(purchasesListControllerProvider).value!;
      expect(state.items.map((p) => p.id), [1, 2]);
      expect(state.hasMore, isFalse);
    });

    test('a loadMore failure keeps the already-loaded items intact', () async {
      final fake = FakePurchasesRepository()
        ..queuePage(OffsetPage(items: [_purchase(1)], currentPage: 1, lastPage: 2, total: 2))
        ..queueError(const NetworkException());
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(purchasesListControllerProvider.future);
      await container.read(purchasesListControllerProvider.notifier).loadMore();

      final state = container.read(purchasesListControllerProvider).value!;
      expect(state.items, hasLength(1));
      expect(state.isLoadingMore, isFalse);
    });

    test('refresh re-fetches page 1 from the repository', () async {
      final fake = FakePurchasesRepository()
        ..queuePage(OffsetPage(items: [_purchase(1)], currentPage: 1, lastPage: 1, total: 1))
        ..queuePage(OffsetPage(items: [_purchase(1), _purchase(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(overrides: [purchasesRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      await container.read(purchasesListControllerProvider.future);
      await container.read(purchasesListControllerProvider.notifier).refresh();

      expect(fake.listCallCount, 2);
      expect(container.read(purchasesListControllerProvider).value!.items, hasLength(2));
    });
  });
}
