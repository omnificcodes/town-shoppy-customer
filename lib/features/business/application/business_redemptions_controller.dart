import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../redemptions/data/models/redemption.dart';
import '../data/business_activity_repository.dart';
import '../data/models/management_totals.dart';
import 'business_context.dart';
import 'list_range.dart';

/// Filters for the merchant's Redemptions list -- `status` defaults to
/// `initiated` (what needs verifying), plus branch, range and search
/// (customer name, mobile number or redemption id).
class RedemptionListFilters {
  const RedemptionListFilters({this.status = 'initiated', this.branchId, this.range = ListRange.all, this.search = ''});

  final String status;
  final int? branchId;
  final ListRange range;
  final String search;

  String? get apiStatus => status == 'all' ? null : status;

  RedemptionListFilters copyWith({String? status, int? branchId, bool clearBranch = false, ListRange? range, String? search}) {
    return RedemptionListFilters(
      status: status ?? this.status,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      range: range ?? this.range,
      search: search ?? this.search,
    );
  }

  static const statusOptions = [
    ('initiated', 'Awaiting verification'),
    ('all', 'All redemptions'),
    ('verified', 'Verified'),
    ('settled', 'Settled'),
    ('expired', 'Expired'),
    ('cancelled', 'Cancelled'),
  ];
}

class RedemptionListFiltersController extends Notifier<RedemptionListFilters> {
  @override
  RedemptionListFilters build() => const RedemptionListFilters();

  void setStatus(String status) => state = state.copyWith(status: status);
  void setBranch(int? branchId) => state = state.copyWith(branchId: branchId, clearBranch: branchId == null);
  void setRange(ListRange range) => state = state.copyWith(range: range);
  void setSearch(String search) => state = state.copyWith(search: search);
}

final redemptionListFiltersProvider =
    NotifierProvider<RedemptionListFiltersController, RedemptionListFilters>(RedemptionListFiltersController.new);

class BusinessRedemptionsState {
  const BusinessRedemptionsState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.totals,
    this.isLoadingMore = false,
  });

  final List<Redemption> items;
  final int currentPage;
  final int lastPage;
  final RedemptionTotals totals;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  BusinessRedemptionsState copyWith({List<Redemption>? items, int? currentPage, int? lastPage, RedemptionTotals? totals, bool? isLoadingMore}) {
    return BusinessRedemptionsState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      totals: totals ?? this.totals,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The verification queue. Polls the first page every 30 s while the
/// "Awaiting verification" tab is open, like the web.
class BusinessRedemptionsController extends AsyncNotifier<BusinessRedemptionsState> {
  static const _pollInterval = Duration(seconds: 30);

  @override
  Future<BusinessRedemptionsState> build() async {
    ref.watch(sessionEpochProvider);
    final filters = ref.watch(redemptionListFiltersProvider);

    if (filters.status == 'initiated') {
      final timer = Timer.periodic(_pollInterval, (_) => _silentRefresh());
      ref.onDispose(timer.cancel);
    }

    final page = await _fetch(filters, page: 1);
    return BusinessRedemptionsState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, totals: page.totals);
  }

  Future<ManagementPage<Redemption, RedemptionTotals>> _fetch(RedemptionListFilters filters, {required int page}) {
    return ref.read(businessActivityRepositoryProvider).redemptionsPage(
          page: page,
          merchantId: ref.read(myMerchantIdProvider),
          status: filters.apiStatus,
          branchId: filters.branchId,
          from: filters.range.fromDate(),
          search: filters.search,
        );
  }

  Future<void> _silentRefresh() async {
    final current = state.value;
    if (current == null || current.isLoadingMore) return;
    try {
      final page = await _fetch(ref.read(redemptionListFiltersProvider), page: 1);
      final firstIds = page.items.map((r) => r.id).toSet();
      final rest = current.items.where((r) => !firstIds.contains(r.id)).toList();
      state = AsyncData(current.copyWith(items: [...page.items, ...rest], totals: page.totals, lastPage: page.lastPage));
    } on AppException {
      // Background poll; the visible list is left as it was.
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _fetch(ref.read(redemptionListFiltersProvider), page: current.currentPage + 1);
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

  Future<Redemption> verify(int id, {required String method, String? code}) =>
      _act(() => ref.read(businessActivityRepositoryProvider).verifyRedemption(id, method: method, code: code));

  Future<Redemption> cancel(int id, {String? reason}) =>
      _act(() => ref.read(businessActivityRepositoryProvider).cancelRedemption(id, reason: reason));

  Future<Redemption> _act(Future<Redemption> Function() action) async {
    final updated = await action();
    final current = state.value;
    if (current != null) {
      final filters = ref.read(redemptionListFiltersProvider);
      final stillMatches = filters.apiStatus == null || updated.status == filters.apiStatus;
      state = AsyncData(current.copyWith(
        items: [
          for (final r in current.items)
            if (r.id == updated.id)
              // The action responses carry no customer/merchant/branch
              // relations; keep the row's originals and take the new status.
              (stillMatches ? _merge(r, updated) : null)
            else
              r,
        ].whereType<Redemption>().toList(),
      ));
    }
    ref
      ..invalidate(dashboardAwaitingRedemptionsProvider)
      ..invalidate(businessRedemptionProvider(updated.id));
    return updated;
  }

  static Redemption _merge(Redemption original, Redemption updated) => Redemption(
        id: updated.id,
        merchant: updated.merchant ?? original.merchant,
        branch: updated.branch ?? original.branch,
        billAmount: updated.billAmount,
        discountAmount: updated.discountAmount,
        remainingBillAmount: updated.remainingBillAmount,
        coinsRequested: updated.coinsRequested,
        coinsDebited: updated.coinsDebited,
        status: updated.status,
        verificationMethod: updated.verificationMethod,
        verifiedAt: updated.verifiedAt,
        createdAt: updated.createdAt ?? original.createdAt,
        qrExpiresAt: updated.qrExpiresAt ?? original.qrExpiresAt,
        customer: updated.customer ?? original.customer,
        counterPresenceVerified: updated.counterPresenceVerified,
        merchantDiscountRate: updated.merchantDiscountRate ?? original.merchantDiscountRate,
        maxDiscountAmount: updated.maxDiscountAmount ?? original.maxDiscountAmount,
        updatedAt: updated.updatedAt ?? original.updatedAt,
      );
}

final businessRedemptionsControllerProvider =
    AsyncNotifierProvider<BusinessRedemptionsController, BusinessRedemptionsState>(BusinessRedemptionsController.new);

/// One redemption, merchant view (`GET /redemptions/{id}` -- no customer
/// relation on this endpoint; the list row is the only place it appears).
final businessRedemptionProvider = FutureProvider.autoDispose.family<Redemption, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(businessActivityRepositoryProvider).redemption(id);
});
