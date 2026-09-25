import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../offer_redemptions/data/models/offer_redemption.dart';
import '../data/business_offers_repository.dart';
import 'business_context.dart';

/// `pending | approved | rejected | all` -- defaults to the review queue.
class OfferRedemptionFilterController extends Notifier<String> {
  @override
  String build() => 'pending';

  void set(String status) => state = status;

  static const options = [('pending', 'Awaiting review'), ('all', 'All requests'), ('approved', 'Approved'), ('rejected', 'Rejected')];
}

final offerRedemptionFilterProvider = NotifierProvider<OfferRedemptionFilterController, String>(OfferRedemptionFilterController.new);

class OfferRedemptionsState {
  const OfferRedemptionsState({required this.items, required this.nextCursor, this.isLoadingMore = false});

  final List<OfferRedemption> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  OfferRedemptionsState copyWith({List<OfferRedemption>? items, String? nextCursor, bool clearCursor = false, bool? isLoadingMore}) {
    return OfferRedemptionsState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The merchant's queue of customers asking for a coin discount on one of
/// its offers. Cursor-paginated; polls every 30 s while on the pending
/// tab, like the web. There is no code or QR: the merchant recognises the
/// request by offer, bill and time.
class OfferRedemptionsController extends AsyncNotifier<OfferRedemptionsState> {
  static const _pollInterval = Duration(seconds: 30);

  @override
  Future<OfferRedemptionsState> build() async {
    ref.watch(sessionEpochProvider);
    final status = ref.watch(offerRedemptionFilterProvider);
    if (status == 'pending') {
      final timer = Timer.periodic(_pollInterval, (_) => _silentRefresh());
      ref.onDispose(timer.cancel);
    }
    final page = await ref.watch(businessOffersRepositoryProvider).offerRedemptions(status: status == 'all' ? null : status);
    return OfferRedemptionsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> _silentRefresh() async {
    final current = state.value;
    if (current == null || current.isLoadingMore) return;
    try {
      final status = ref.read(offerRedemptionFilterProvider);
      final page = await ref.read(businessOffersRepositoryProvider).offerRedemptions(status: status == 'all' ? null : status);
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
      final status = ref.read(offerRedemptionFilterProvider);
      final page = await ref.read(businessOffersRepositoryProvider).offerRedemptions(status: status == 'all' ? null : status, cursor: current.nextCursor);
      state = AsyncData(current.copyWith(items: [...current.items, ...page.items], nextCursor: page.nextCursor, clearCursor: page.nextCursor == null, isLoadingMore: false));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<OfferRedemption> approve(int id) => _act(() => ref.read(businessOffersRepositoryProvider).approveOfferRedemption(id));
  Future<OfferRedemption> reject(int id, {String? reason}) => _act(() => ref.read(businessOffersRepositoryProvider).rejectOfferRedemption(id, reason: reason));

  Future<OfferRedemption> _act(Future<OfferRedemption> Function() action) async {
    final updated = await action();
    final current = state.value;
    if (current != null) {
      final status = ref.read(offerRedemptionFilterProvider);
      final keep = status == 'all' || updated.status == status;
      state = AsyncData(current.copyWith(
        items: [
          for (final r in current.items)
            if (r.id == updated.id)
              // The action response drops `offer_title`; keep the row's.
              (keep ? _merge(r, updated) : null)
            else
              r,
        ].whereType<OfferRedemption>().toList(),
      ));
    }
    // So the dashboard's count and feed agree with what was just done.
    ref.invalidate(dashboardPendingOfferRedemptionsProvider);
    return updated;
  }

  static OfferRedemption _merge(OfferRedemption original, OfferRedemption updated) => OfferRedemption(
        id: updated.id,
        offerId: updated.offerId,
        offerTitle: updated.offerTitle ?? original.offerTitle,
        merchantId: updated.merchantId,
        billAmount: updated.billAmount,
        maxDiscountAmount: updated.maxDiscountAmount,
        coinsRequested: updated.coinsRequested,
        coinsApplied: updated.coinsApplied,
        discountAmount: updated.discountAmount,
        status: updated.status,
        rejectionReason: updated.rejectionReason,
        createdAt: updated.createdAt ?? original.createdAt,
        reviewedAt: updated.reviewedAt,
      );
}

final offerRedemptionsControllerProvider = AsyncNotifierProvider<OfferRedemptionsController, OfferRedemptionsState>(OfferRedemptionsController.new);
