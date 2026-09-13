import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/business_prizes_repository.dart';
import '../data/models/business_prize.dart';
import 'business_context.dart';

class PrizeListFilters {
  const PrizeListFilters({this.status = 'all', this.search = ''});

  final String status;
  final String search;

  String? get apiStatus => status == 'all' ? null : status;

  PrizeListFilters copyWith({String? status, String? search}) => PrizeListFilters(status: status ?? this.status, search: search ?? this.search);

  /// Merchant-facing relabelling of `PrizeStatus`, as on the web.
  static const statusOptions = [
    ('all', 'All'),
    ('draft', 'Pending approval'),
    ('available', 'Approved'),
    ('allocated', 'In a draw'),
    ('awarded', 'Awarded'),
    ('withdrawn', 'Withdrawn'),
  ];
}

class PrizeListFiltersController extends Notifier<PrizeListFilters> {
  @override
  PrizeListFilters build() => const PrizeListFilters();

  void setStatus(String s) => state = state.copyWith(status: s);
  void setSearch(String s) => state = state.copyWith(search: s);
}

final prizeListFiltersProvider = NotifierProvider<PrizeListFiltersController, PrizeListFilters>(PrizeListFiltersController.new);

class BusinessPrizesState {
  const BusinessPrizesState({required this.items, required this.currentPage, required this.lastPage, required this.totals, this.isLoadingMore = false});

  final List<BusinessPrize> items;
  final int currentPage;
  final int lastPage;
  final PrizeTotals totals;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  BusinessPrizesState copyWith({List<BusinessPrize>? items, int? currentPage, int? lastPage, PrizeTotals? totals, bool? isLoadingMore}) {
    return BusinessPrizesState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      totals: totals ?? this.totals,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class BusinessPrizesController extends AsyncNotifier<BusinessPrizesState> {
  @override
  Future<BusinessPrizesState> build() async {
    ref.watch(sessionEpochProvider);
    final f = ref.watch(prizeListFiltersProvider);
    final merchantId = ref.watch(myMerchantIdProvider);
    if (merchantId == null) return const BusinessPrizesState(items: [], currentPage: 1, lastPage: 1, totals: PrizeTotals.empty);
    final page = await ref.watch(businessPrizesRepositoryProvider).list(merchantId: merchantId, status: f.apiStatus, search: f.search);
    return BusinessPrizesState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, totals: page.totals);
  }

  Future<void> loadMore() async {
    final current = state.value;
    final merchantId = ref.read(myMerchantIdProvider);
    if (current == null || merchantId == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final f = ref.read(prizeListFiltersProvider);
      final page = await ref.read(businessPrizesRepositoryProvider).list(merchantId: merchantId, page: current.currentPage + 1, status: f.apiStatus, search: f.search);
      state = AsyncData(current.copyWith(items: [...current.items, ...page.items], currentPage: page.currentPage, lastPage: page.lastPage, totals: page.totals, isLoadingMore: false));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<BusinessPrize> propose(PrizeInput input) async {
    final merchant = await ref.read(myMerchantProvider.future);
    final associationId = merchant.association?.id;
    if (associationId == null) throw StateError('no association');
    final created = await ref.read(businessPrizesRepositoryProvider).propose(merchantId: merchant.id, associationId: associationId, input: input);
    await refresh();
    return created;
  }

  Future<BusinessPrize> withdraw(int id) async {
    final updated = await ref.read(businessPrizesRepositoryProvider).withdraw(id);
    ref.invalidate(businessPrizeProvider(id));
    await refresh();
    return updated;
  }
}

final businessPrizesControllerProvider = AsyncNotifierProvider<BusinessPrizesController, BusinessPrizesState>(BusinessPrizesController.new);

final businessPrizeProvider = FutureProvider.autoDispose.family<BusinessPrize, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(businessPrizesRepositoryProvider).show(id);
});
