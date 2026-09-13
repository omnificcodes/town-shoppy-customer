import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/business_offers_repository.dart';
import '../data/models/business_offer.dart';
import 'business_context.dart';

/// Offer list filters -- `status` is the tab (`all` sends nothing).
class OfferListFilters {
  const OfferListFilters({this.status = 'all', this.search = ''});

  final String status;
  final String search;

  String? get apiStatus => status == 'all' ? null : status;

  OfferListFilters copyWith({String? status, String? search}) => OfferListFilters(status: status ?? this.status, search: search ?? this.search);

  /// Merchant-facing wording: to an owner a `draft` is an offer they have
  /// scheduled but not put live yet (same relabelling as the web).
  static const statusOptions = [('all', 'All'), ('active', 'Active'), ('draft', 'Scheduled'), ('expired', 'Expired')];
}

class OfferListFiltersController extends Notifier<OfferListFilters> {
  @override
  OfferListFilters build() => const OfferListFilters();

  void setStatus(String status) => state = state.copyWith(status: status);
  void setSearch(String search) => state = state.copyWith(search: search);
}

final offerListFiltersProvider = NotifierProvider<OfferListFiltersController, OfferListFilters>(OfferListFiltersController.new);

class BusinessOffersState {
  const BusinessOffersState({required this.items, required this.currentPage, required this.lastPage, required this.counts, this.isLoadingMore = false});

  final List<BusinessOffer> items;
  final int currentPage;
  final int lastPage;
  final OfferStatusCounts counts;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  BusinessOffersState copyWith({List<BusinessOffer>? items, int? currentPage, int? lastPage, OfferStatusCounts? counts, bool? isLoadingMore}) {
    return BusinessOffersState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      counts: counts ?? this.counts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class BusinessOffersController extends AsyncNotifier<BusinessOffersState> {
  @override
  Future<BusinessOffersState> build() async {
    ref.watch(sessionEpochProvider);
    final filters = ref.watch(offerListFiltersProvider);
    final merchantId = ref.watch(myMerchantIdProvider);
    if (merchantId == null) return const BusinessOffersState(items: [], currentPage: 1, lastPage: 1, counts: OfferStatusCounts.empty);
    final page = await ref.watch(businessOffersRepositoryProvider).list(merchantId: merchantId, status: filters.apiStatus, search: filters.search);
    return BusinessOffersState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, counts: page.counts);
  }

  Future<void> loadMore() async {
    final current = state.value;
    final merchantId = ref.read(myMerchantIdProvider);
    if (current == null || merchantId == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filters = ref.read(offerListFiltersProvider);
      final page = await ref.read(businessOffersRepositoryProvider).list(merchantId: merchantId, page: current.currentPage + 1, status: filters.apiStatus, search: filters.search);
      state = AsyncData(current.copyWith(items: [...current.items, ...page.items], currentPage: page.currentPage, lastPage: page.lastPage, counts: page.counts, isLoadingMore: false));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<BusinessOffer> publish(int id) => _act(() => ref.read(businessOffersRepositoryProvider).publish(id));
  Future<BusinessOffer> withdraw(int id, {String? reason}) => _act(() => ref.read(businessOffersRepositoryProvider).withdraw(id, reason: reason));
  Future<BusinessOffer> end(int id, {String? reason}) => _act(() => ref.read(businessOffersRepositoryProvider).end(id, reason: reason));

  /// Publishing/withdrawing/ending changes the status counts too, so the
  /// whole first page is re-read rather than patching one row.
  Future<BusinessOffer> _act(Future<BusinessOffer> Function() action) async {
    final updated = await action();
    ref.invalidate(businessOfferProvider(updated.id));
    await refresh();
    return updated;
  }
}

final businessOffersControllerProvider = AsyncNotifierProvider<BusinessOffersController, BusinessOffersState>(BusinessOffersController.new);

final businessOfferProvider = FutureProvider.autoDispose.family<BusinessOffer, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(businessOffersRepositoryProvider).show(id);
});
