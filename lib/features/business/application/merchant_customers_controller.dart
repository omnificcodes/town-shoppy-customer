import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/merchant_customers_repository.dart';
import '../data/models/merchant_customer.dart';
import 'list_range.dart';

class CustomerListFilters {
  const CustomerListFilters({this.search = '', this.branchId, this.range = ListRange.all});

  final String search;
  final int? branchId;
  final ListRange range;

  CustomerListFilters copyWith({String? search, int? branchId, bool clearBranch = false, ListRange? range}) {
    return CustomerListFilters(search: search ?? this.search, branchId: clearBranch ? null : (branchId ?? this.branchId), range: range ?? this.range);
  }

  bool get isDefault => search.isEmpty && branchId == null && range == ListRange.all;
}

class CustomerListFiltersController extends Notifier<CustomerListFilters> {
  @override
  CustomerListFilters build() => const CustomerListFilters();

  void setSearch(String v) => state = state.copyWith(search: v);
  void setBranch(int? id) => state = state.copyWith(branchId: id, clearBranch: id == null);
  void setRange(ListRange r) => state = state.copyWith(range: r);
  void clear() => state = const CustomerListFilters();
}

final customerListFiltersProvider = NotifierProvider<CustomerListFiltersController, CustomerListFilters>(CustomerListFiltersController.new);

class MerchantCustomersState {
  const MerchantCustomersState({required this.items, required this.currentPage, required this.lastPage, required this.totals, this.isLoadingMore = false});

  final List<MerchantCustomer> items;
  final int currentPage;
  final int lastPage;
  final CustomerTotals totals;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  MerchantCustomersState copyWith({List<MerchantCustomer>? items, int? currentPage, int? lastPage, CustomerTotals? totals, bool? isLoadingMore}) {
    return MerchantCustomersState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      totals: totals ?? this.totals,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The customer directory, newest visit first (the backend's fixed order).
class MerchantCustomersController extends AsyncNotifier<MerchantCustomersState> {
  @override
  Future<MerchantCustomersState> build() async {
    ref.watch(sessionEpochProvider);
    final f = ref.watch(customerListFiltersProvider);
    final page = await ref.watch(merchantCustomersRepositoryProvider).list(search: f.search, branchId: f.branchId, from: f.range.fromDate());
    return MerchantCustomersState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, totals: page.totals);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final f = ref.read(customerListFiltersProvider);
      final page = await ref.read(merchantCustomersRepositoryProvider).list(page: current.currentPage + 1, search: f.search, branchId: f.branchId, from: f.range.fromDate());
      state = AsyncData(current.copyWith(items: [...current.items, ...page.items], currentPage: page.currentPage, lastPage: page.lastPage, totals: page.totals, isLoadingMore: false));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final merchantCustomersControllerProvider = AsyncNotifierProvider<MerchantCustomersController, MerchantCustomersState>(MerchantCustomersController.new);

final merchantCustomerDetailProvider = FutureProvider.autoDispose.family<MerchantCustomerDetail, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(merchantCustomersRepositoryProvider).show(id);
});
