import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/errors/app_exception.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/features/lucky_draw/application/draws_list_controller.dart';
import 'package:customer/features/lucky_draw/application/my_vouchers_controller.dart';
import 'package:customer/features/lucky_draw/data/lucky_draw_repository.dart';
import 'package:customer/features/lucky_draw/data/models/draw.dart';
import 'package:customer/features/lucky_draw/data/models/draw_entry.dart';
import 'package:customer/features/lucky_draw/data/models/draw_winner.dart';
import 'package:customer/features/lucky_draw/data/models/voucher.dart';

Draw _draw(int id) {
  return Draw(
    id: id,
    associationId: 1,
    cadence: 'weekly',
    scope: 'all',
    status: 'complete',
    poolLockedAt: DateTime(2026, 1, 1),
    executedAt: DateTime(2026, 1, 2),
    prizes: const [],
    winnerCount: 2,
    createdAt: DateTime(2026, 1, 1),
  );
}

Voucher _voucher(int id) {
  return Voucher(
    id: id,
    code: 'ABCD$id',
    prize: null,
    sponsorMerchantName: 'Corner Cafe',
    status: 'active',
    expiresAt: DateTime(2027, 1, 1),
    claimedAt: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

class FakeLuckyDrawRepository implements LuckyDrawRepository {
  final List<Object> _drawResponses = [];
  final List<Object> _voucherResponses = [];
  int drawsCallCount = 0;
  int vouchersCallCount = 0;

  void queueDrawPage(OffsetPage<Draw> page) => _drawResponses.add(page);
  void queueDrawError(AppException error) => _drawResponses.add(error);
  void queueVoucherPage(OffsetPage<Voucher> page) => _voucherResponses.add(page);

  @override
  Future<OffsetPage<Draw>> draws({int page = 1, int perPage = 20, int? associationId}) async {
    drawsCallCount++;
    final next = _drawResponses.first;
    if (next is AppException) throw next;
    _drawResponses.removeAt(0);
    return next as OffsetPage<Draw>;
  }

  @override
  Future<OffsetPage<Voucher>> myVouchers({int page = 1, int perPage = 20}) async {
    vouchersCallCount++;
    final next = _voucherResponses.first;
    if (next is AppException) throw next;
    _voucherResponses.removeAt(0);
    return next as OffsetPage<Voucher>;
  }

  @override
  Future<Draw> draw(int id) async => throw UnimplementedError();

  @override
  Future<List<DrawWinner>> winners(int drawId) async => throw UnimplementedError();

  @override
  Future<DrawEntriesPage> entries(int drawId, {int page = 1, int perPage = 50}) async => throw UnimplementedError();

  @override
  Future<List<DrawEntry>> entriesSample(int drawId) async => throw UnimplementedError();

  @override
  Future<Voucher> voucher(int id) async => throw UnimplementedError();

  @override
  Future<String> voucherQrSecret(int id) async => throw UnimplementedError();
}

Future<AsyncValue<DrawsListState>> _pollForDrawError(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(drawsListControllerProvider);
    if (state.hasError) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Provider never reported an error');
}

void main() {
  group('DrawsListController', () {
    test('loads only what the repository returns, without filtering client-side', () async {
      final fake = FakeLuckyDrawRepository()..queueDrawPage(OffsetPage(items: [_draw(1), _draw(2)], currentPage: 1, lastPage: 1, total: 2));
      final container = ProviderContainer(overrides: [luckyDrawRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(drawsListControllerProvider.future);

      expect(state.items, hasLength(2));
      expect(state.items.every((d) => d.isComplete), isTrue);
    });

    test('propagates a backend error', () async {
      final fake = FakeLuckyDrawRepository()..queueDrawError(const NetworkException());
      final container = ProviderContainer(overrides: [luckyDrawRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await _pollForDrawError(container);

      expect(state.error, isA<NetworkException>());
    });

    test('loadMore appends the next page', () async {
      final fake = FakeLuckyDrawRepository()
        ..queueDrawPage(OffsetPage(items: [_draw(1)], currentPage: 1, lastPage: 2, total: 2))
        ..queueDrawPage(OffsetPage(items: [_draw(2)], currentPage: 2, lastPage: 2, total: 2));
      final container = ProviderContainer(overrides: [luckyDrawRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      await container.read(drawsListControllerProvider.future);

      await container.read(drawsListControllerProvider.notifier).loadMore();

      final state = container.read(drawsListControllerProvider).value!;
      expect(state.items.map((d) => d.id), [1, 2]);
      expect(state.hasMore, isFalse);
    });
  });

  group('MyVouchersController', () {
    test('loads the customer\'s own vouchers', () async {
      final fake = FakeLuckyDrawRepository()..queueVoucherPage(OffsetPage(items: [_voucher(1)], currentPage: 1, lastPage: 1, total: 1));
      final container = ProviderContainer(overrides: [luckyDrawRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(myVouchersControllerProvider.future);

      expect(state.items, hasLength(1));
      expect(state.items.first.isActive, isTrue);
    });

    test('surfaces an empty list for a customer with no wins', () async {
      final fake = FakeLuckyDrawRepository()..queueVoucherPage(const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0));
      final container = ProviderContainer(overrides: [luckyDrawRepositoryProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);

      final state = await container.read(myVouchersControllerProvider.future);

      expect(state.items, isEmpty);
    });
  });
}
