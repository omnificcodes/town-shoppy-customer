import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/features/wallet/application/wallet_transactions_controller.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

WalletLedgerEntry _entry(int id, {String direction = 'credit'}) {
  return WalletLedgerEntry(
    id: id,
    direction: direction,
    amount: 10,
    source: 'purchase_reward',
    coinType: null,
    merchantName: null,
    balanceAfter: 100,
    lotExpiresAt: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Same scripted-fake shape as `purchases_list_controller_test.dart`'s
/// FakePurchasesRepository, adapted for cursor pagination.
class FakeWalletRepository implements WalletRepository {
  final List<Object> _responses = [];
  int transactionsCallCount = 0;

  void queuePage(CursorPage<WalletLedgerEntry> page) => _responses.add(page);
  void queueError(AppException error) => _responses.add(error);

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async {
    transactionsCallCount++;
    final next = _responses.first;
    if (next is AppException) throw next;
    _responses.removeAt(0);
    return next as CursorPage<WalletLedgerEntry>;
  }

  @override
  Future<SilverWalletBalance> balance() async => throw UnimplementedError();
}

Future<AsyncValue<WalletTransactionsState>> _pollForError(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(walletTransactionsControllerProvider);
    if (state.hasError) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Provider never reported an error');
}

void main() {
  group('WalletTransactionsController', () {
    test('loads the first page successfully', () async {
      final fake = FakeWalletRepository()..queuePage(CursorPage(items: [_entry(1), _entry(2)], nextCursor: 'abc'));
      final container = ProviderContainer(overrides: [walletRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(walletTransactionsControllerProvider.future);

      expect(state.items, hasLength(2));
      expect(state.hasMore, isTrue);
      expect(fake.transactionsCallCount, 1);
    });

    test('surfaces an empty list distinctly from a failure', () async {
      final fake = FakeWalletRepository()..queuePage(const CursorPage(items: [], nextCursor: null));
      final container = ProviderContainer(overrides: [walletRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(walletTransactionsControllerProvider.future);

      expect(state.items, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('propagates a backend error', () async {
      final fake = FakeWalletRepository()..queueError(const NetworkException());
      final container = ProviderContainer(overrides: [walletRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await _pollForError(container);

      expect(state.error, isA<NetworkException>());
    });

    test('loadMore appends the next page using the returned cursor', () async {
      final fake = FakeWalletRepository()
        ..queuePage(CursorPage(items: [_entry(1)], nextCursor: 'page2'))
        ..queuePage(CursorPage(items: [_entry(2)], nextCursor: null));

      final container = ProviderContainer(overrides: [walletRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      await container.read(walletTransactionsControllerProvider.future);

      await container.read(walletTransactionsControllerProvider.notifier).loadMore();

      final state = container.read(walletTransactionsControllerProvider).value!;
      expect(state.items.map((e) => e.id), [1, 2]);
      expect(state.hasMore, isFalse);
      expect(fake.transactionsCallCount, 2);
    });

    test('refresh re-fetches from the beginning', () async {
      final fake = FakeWalletRepository()
        ..queuePage(CursorPage(items: [_entry(1)], nextCursor: null))
        ..queuePage(CursorPage(items: [_entry(1), _entry(2)], nextCursor: null));
      final container = ProviderContainer(overrides: [walletRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      await container.read(walletTransactionsControllerProvider.future);

      await container.read(walletTransactionsControllerProvider.notifier).refresh();

      final state = container.read(walletTransactionsControllerProvider).value!;
      expect(state.items, hasLength(2));
      expect(fake.transactionsCallCount, 2);
    });
  });
}
