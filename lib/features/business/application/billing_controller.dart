import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../auth/application/auth_controller.dart';
import '../data/billing_repository.dart';
import '../data/models/billing.dart';
import 'business_context.dart';
import 'list_range.dart';

/// The date window a billing list is filtered to: one of the quick
/// [ListRange]s (from-only, like every other merchant list) or an explicit
/// custom from/to pair -- the web's two date inputs, as one native picker.
class DateWindow {
  const DateWindow({this.range = ListRange.all, this.customFrom, this.customTo});

  final ListRange range;
  final DateTime? customFrom;
  final DateTime? customTo;

  bool get isCustom => customFrom != null;
  bool get isActive => isCustom || range != ListRange.all;

  String? get from => isCustom ? apiDate(customFrom!) : range.fromDate();
  String? get to => customTo == null ? null : apiDate(customTo!);

  /// What the range control shows.
  String get label {
    if (!isCustom) return range.label;
    final start = formatDate(customFrom!);
    return customTo == null ? 'From $start' : '$start – ${formatDate(customTo!)}';
  }

  DateWindow quick(ListRange range) => DateWindow(range: range);

  DateWindow custom(DateTime from, DateTime to) => DateWindow(range: ListRange.all, customFrom: from, customTo: to);
}

// ---------------------------------------------------------------- Payments

/// Same set and default as the web's Payments page (`all`).
class PaymentListFilters {
  const PaymentListFilters({this.status = 'all', this.dates = const DateWindow(), this.search = ''});

  /// `initiated | pending | paid | failed | cancelled | refunded`, or `all`.
  final String status;
  final DateWindow dates;
  final String search;

  String? get apiStatus => status == 'all' ? null : status;
  bool get isFiltered => status != 'all' || dates.isActive || search.isNotEmpty;

  PaymentListFilters copyWith({String? status, DateWindow? dates, String? search}) {
    return PaymentListFilters(status: status ?? this.status, dates: dates ?? this.dates, search: search ?? this.search);
  }

  static const statusOptions = [
    ('all', 'All'),
    ('paid', 'Paid'),
    ('pending', 'Pending'),
    ('initiated', 'Initiated'),
    ('failed', 'Failed'),
    ('cancelled', 'Cancelled'),
    ('refunded', 'Refunded'),
  ];
}

class PaymentListFiltersController extends Notifier<PaymentListFilters> {
  @override
  PaymentListFilters build() => const PaymentListFilters();

  void setStatus(String status) => state = state.copyWith(status: status);
  void setRange(ListRange range) => state = state.copyWith(dates: state.dates.quick(range));
  void setCustomRange(DateTime from, DateTime to) => state = state.copyWith(dates: state.dates.custom(from, to));
  void setSearch(String search) => state = state.copyWith(search: search);
  void clear() => state = const PaymentListFilters();
}

final paymentListFiltersProvider = NotifierProvider<PaymentListFiltersController, PaymentListFilters>(PaymentListFiltersController.new);

class BusinessPaymentsState {
  const BusinessPaymentsState({required this.items, required this.currentPage, required this.lastPage, required this.totals, this.isLoadingMore = false});

  final List<MerchantPayment> items;
  final int currentPage;
  final int lastPage;
  final PaymentTotals totals;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  BusinessPaymentsState copyWith({List<MerchantPayment>? items, int? currentPage, int? lastPage, PaymentTotals? totals, bool? isLoadingMore}) {
    return BusinessPaymentsState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      totals: totals ?? this.totals,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The owner's payment history. Purely a read: nothing on this list is
/// ever mutated from the app (refunds are Town Shoppy staff actions).
class BusinessPaymentsController extends AsyncNotifier<BusinessPaymentsState> {
  @override
  Future<BusinessPaymentsState> build() async {
    ref.watch(sessionEpochProvider);
    final filters = ref.watch(paymentListFiltersProvider);
    final page = await ref.watch(billingRepositoryProvider).payments(
          merchantId: ref.watch(myMerchantIdProvider),
          status: filters.apiStatus,
          from: filters.dates.from,
          to: filters.dates.to,
          search: filters.search,
        );
    return BusinessPaymentsState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, totals: page.totals);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filters = ref.read(paymentListFiltersProvider);
      final page = await ref.read(billingRepositoryProvider).payments(
            page: current.currentPage + 1,
            merchantId: ref.read(myMerchantIdProvider),
            status: filters.apiStatus,
            from: filters.dates.from,
            to: filters.dates.to,
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
}

final businessPaymentsControllerProvider = AsyncNotifierProvider<BusinessPaymentsController, BusinessPaymentsState>(BusinessPaymentsController.new);

final businessPaymentProvider = FutureProvider.autoDispose.family<MerchantPayment, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(billingRepositoryProvider).payment(id);
});

// ---------------------------------------------------------------- Invoices

class InvoiceListFilters {
  const InvoiceListFilters({this.dates = const DateWindow()});

  final DateWindow dates;

  bool get isFiltered => dates.isActive;
}

class InvoiceListFiltersController extends Notifier<InvoiceListFilters> {
  @override
  InvoiceListFilters build() => const InvoiceListFilters();

  void setRange(ListRange range) => state = InvoiceListFilters(dates: state.dates.quick(range));
  void setCustomRange(DateTime from, DateTime to) => state = InvoiceListFilters(dates: state.dates.custom(from, to));
  void clear() => state = const InvoiceListFilters();
}

final invoiceListFiltersProvider = NotifierProvider<InvoiceListFiltersController, InvoiceListFilters>(InvoiceListFiltersController.new);

class BusinessInvoicesState {
  const BusinessInvoicesState({required this.items, required this.currentPage, required this.lastPage, required this.total, this.isLoadingMore = false});

  final List<MerchantInvoice> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  BusinessInvoicesState copyWith({List<MerchantInvoice>? items, int? currentPage, int? lastPage, int? total, bool? isLoadingMore}) {
    return BusinessInvoicesState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class BusinessInvoicesController extends AsyncNotifier<BusinessInvoicesState> {
  @override
  Future<BusinessInvoicesState> build() async {
    ref.watch(sessionEpochProvider);
    final filters = ref.watch(invoiceListFiltersProvider);
    final page = await ref.watch(billingRepositoryProvider).invoices(
          merchantId: ref.watch(myMerchantIdProvider),
          from: filters.dates.from,
          to: filters.dates.to,
        );
    return BusinessInvoicesState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, total: page.total);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filters = ref.read(invoiceListFiltersProvider);
      final page = await ref.read(billingRepositoryProvider).invoices(
            page: current.currentPage + 1,
            merchantId: ref.read(myMerchantIdProvider),
            from: filters.dates.from,
            to: filters.dates.to,
          );
      state = AsyncData(current.copyWith(
        items: [...current.items, ...page.items],
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        total: page.total,
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
}

final businessInvoicesControllerProvider = AsyncNotifierProvider<BusinessInvoicesController, BusinessInvoicesState>(BusinessInvoicesController.new);

final businessInvoiceProvider = FutureProvider.autoDispose.family<MerchantInvoice, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(billingRepositoryProvider).invoice(id);
});
