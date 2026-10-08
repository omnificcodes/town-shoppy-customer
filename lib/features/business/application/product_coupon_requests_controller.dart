import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../product_coupons/data/models/product_coupon_request.dart';
import '../../product_coupons/data/product_coupons_repository.dart';

/// `pending | approved | rejected | all` -- defaults to the review queue.
class ProductCouponRequestFilterController extends Notifier<String> {
  @override
  String build() => 'pending';

  void set(String status) => state = status;

  static const options = [
    ('pending', 'Awaiting review'),
    ('all', 'All requests'),
    ('approved', 'Accepted'),
    ('rejected', 'Declined'),
  ];
}

final productCouponRequestFilterProvider =
    NotifierProvider<ProductCouponRequestFilterController, String>(ProductCouponRequestFilterController.new);

class ProductCouponRequestsState {
  const ProductCouponRequestsState({required this.items, required this.nextCursor, this.isLoadingMore = false});

  final List<ProductCouponRequest> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  ProductCouponRequestsState copyWith({
    List<ProductCouponRequest>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
  }) {
    return ProductCouponRequestsState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The shop's queue of customers asking for a product's Lucky Draw
/// coupons. Same shape as OffersRedemptionsController: cursor-paginated,
/// polls every 30 s while on the pending tab.
class ProductCouponRequestsController extends AsyncNotifier<ProductCouponRequestsState> {
  static const _pollInterval = Duration(seconds: 30);

  String? get _status {
    final status = ref.read(productCouponRequestFilterProvider);
    return status == 'all' ? null : status;
  }

  @override
  Future<ProductCouponRequestsState> build() async {
    ref.watch(sessionEpochProvider);
    final status = ref.watch(productCouponRequestFilterProvider);
    if (status == 'pending') {
      final timer = Timer.periodic(_pollInterval, (_) => _silentRefresh());
      ref.onDispose(timer.cancel);
    }
    final page = await ref
        .watch(productCouponsRepositoryProvider)
        .merchantRequests(status: status == 'all' ? null : status);
    return ProductCouponRequestsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> _silentRefresh() async {
    final current = state.value;
    if (current == null || current.isLoadingMore) return;
    try {
      final page = await ref.read(productCouponsRepositoryProvider).merchantRequests(status: _status);
      final ids = page.items.map((r) => r.id).toSet();
      state = AsyncData(current.copyWith(items: [...page.items, ...current.items.where((r) => !ids.contains(r.id))]));
    } on AppException {
      // Background poll; keep what is on screen.
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(productCouponsRepositoryProvider)
          .merchantRequests(status: _status, cursor: current.nextCursor);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<ProductCouponRequest> approve(int id) => _act(() => ref.read(productCouponsRepositoryProvider).approve(id));

  Future<ProductCouponRequest> reject(int id, {String? reason}) =>
      _act(() => ref.read(productCouponsRepositoryProvider).reject(id, reason: reason));

  Future<ProductCouponRequest> _act(Future<ProductCouponRequest> Function() action) async {
    final updated = await action();
    final current = state.value;
    if (current != null) {
      final status = ref.read(productCouponRequestFilterProvider);
      final keep = status == 'all' || updated.status == status;
      state = AsyncData(
        current.copyWith(
          items: [
            for (final r in current.items)
              if (r.id != updated.id) r else if (keep) updated,
          ],
        ),
      );
    }
    return updated;
  }
}

final productCouponRequestsControllerProvider =
    AsyncNotifierProvider<ProductCouponRequestsController, ProductCouponRequestsState>(
      ProductCouponRequestsController.new,
    );
