import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../purchases/data/models/purchase.dart';
import '../data/business_activity_repository.dart';
import '../data/models/management_totals.dart';
import 'business_context.dart';
import 'list_range.dart';

/// Filters for the merchant's Purchases list -- same set and defaults as
/// the web (`status` defaults to `pending`: the queue that needs a
/// decision is what an owner opens this screen for).
class PurchaseListFilters {
  const PurchaseListFilters({this.status = 'pending', this.range = ListRange.all, this.search = ''});

  /// `pending | recorded | rejected | disputed | voided`, or `all`.
  final String status;
  final ListRange range;
  final String search;

  String? get apiStatus => status == 'all' ? null : status;

  PurchaseListFilters copyWith({String? status, ListRange? range, String? search}) {
    return PurchaseListFilters(status: status ?? this.status, range: range ?? this.range, search: search ?? this.search);
  }

  static const statusOptions = [
    ('pending', 'Awaiting approval'),
    ('all', 'All purchases'),
    ('recorded', 'Recorded'),
    ('rejected', 'Rejected'),
    ('disputed', 'Disputed'),
    ('voided', 'Voided'),
  ];
}

class PurchaseListFiltersController extends Notifier<PurchaseListFilters> {
  @override
  PurchaseListFilters build() => const PurchaseListFilters();

  void setStatus(String status) => state = state.copyWith(status: status);
  void setRange(ListRange range) => state = state.copyWith(range: range);
  void setSearch(String search) => state = state.copyWith(search: search);
}

final purchaseListFiltersProvider = NotifierProvider<PurchaseListFiltersController, PurchaseListFilters>(PurchaseListFiltersController.new);

class BusinessPurchasesState {
  const BusinessPurchasesState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.totals,
    this.isLoadingMore = false,
  });

  final List<Purchase> items;
  final int currentPage;
  final int lastPage;
  final PurchaseTotals totals;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  BusinessPurchasesState copyWith({List<Purchase>? items, int? currentPage, int? lastPage, PurchaseTotals? totals, bool? isLoadingMore}) {
    return BusinessPurchasesState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      totals: totals ?? this.totals,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The merchant's purchase queue. Rebuilds whenever the filters change;
/// while the "Awaiting approval" tab is open it re-polls the first page
/// every 30 s (same cadence as the web) so a new scan-and-submit request
/// appears without a pull-to-refresh.
class BusinessPurchasesController extends AsyncNotifier<BusinessPurchasesState> {
  static const _pollInterval = Duration(seconds: 30);

  @override
  Future<BusinessPurchasesState> build() async {
    ref.watch(sessionEpochProvider);
    final filters = ref.watch(purchaseListFiltersProvider);
    final merchantId = ref.watch(myMerchantIdProvider);

    if (filters.status == 'pending') {
      final timer = Timer.periodic(_pollInterval, (_) => _silentRefresh());
      ref.onDispose(timer.cancel);
    }

    final page = await ref.watch(businessActivityRepositoryProvider).purchasesPage(
          merchantId: merchantId,
          status: filters.apiStatus,
          from: filters.range.fromDate(),
          search: filters.search,
        );
    return BusinessPurchasesState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, totals: page.totals);
  }

  Future<void> _silentRefresh() async {
    final current = state.value;
    if (current == null || current.isLoadingMore) return;
    try {
      final filters = ref.read(purchaseListFiltersProvider);
      final page = await ref.read(businessActivityRepositoryProvider).purchasesPage(
            merchantId: ref.read(myMerchantIdProvider),
            status: filters.apiStatus,
            from: filters.range.fromDate(),
            search: filters.search,
          );
      // Only the first page is re-read; anything the user had paged into
      // is kept below it minus rows now present on page 1.
      final firstIds = page.items.map((p) => p.id).toSet();
      final rest = current.items.where((p) => !firstIds.contains(p.id)).skip(page.items.isEmpty ? 0 : 0).toList();
      state = AsyncData(current.copyWith(items: [...page.items, ...rest], totals: page.totals, lastPage: page.lastPage));
    } on AppException {
      // A background poll failing is not worth an error screen.
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filters = ref.read(purchaseListFiltersProvider);
      final page = await ref.read(businessActivityRepositoryProvider).purchasesPage(
            page: current.currentPage + 1,
            merchantId: ref.read(myMerchantIdProvider),
            status: filters.apiStatus,
            from: filters.range.fromDate(),
            search: filters.search,
          );
      state = AsyncData(current.copyWith(
        items: [...current.items, ...page.items],
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        totals: page.totals,
        isLoadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Approve/reject a `pending` request. The row is swapped for the
  /// backend's updated copy; the dashboard counters are invalidated so the
  /// KPI tiles agree with what the merchant just did.
  Future<Purchase> approve(int id) => _act(() => ref.read(businessActivityRepositoryProvider).approvePurchase(id));

  Future<Purchase> reject(int id, {String? reason}) =>
      _act(() => ref.read(businessActivityRepositoryProvider).rejectPurchase(id, reason: reason));

  Future<Purchase> _act(Future<Purchase> Function() action) async {
    final updated = await action();
    final current = state.value;
    if (current != null) {
      final filters = ref.read(purchaseListFiltersProvider);
      final stillMatches = filters.apiStatus == null || updated.status == filters.apiStatus;
      state = AsyncData(current.copyWith(
        items: [for (final p in current.items) if (p.id == updated.id) (stillMatches ? updated : null) else p].whereType<Purchase>().toList(),
        totals: current.totals,
      ));
    }
    ref
      ..invalidate(dashboardPendingPurchasesCountProvider)
      ..invalidate(dashboardRecentPurchasesProvider)
      ..invalidate(businessPurchaseProvider(updated.id));
    return updated;
  }
}

final businessPurchasesControllerProvider =
    AsyncNotifierProvider<BusinessPurchasesController, BusinessPurchasesState>(BusinessPurchasesController.new);

/// One purchase, merchant view. `GET /purchases/{id}` returns the same
/// resource to owner/staff as it does to the customer, so the customer
/// repository's `show()` is reused verbatim.
final businessPurchaseProvider = FutureProvider.autoDispose.family<Purchase, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(businessActivityRepositoryProvider).purchase(id);
});
