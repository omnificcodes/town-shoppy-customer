/// `meta.totals` of `GET /purchases?context=management` -- computed over
/// the merchant's recorded/disputed purchases *before* the status filter,
/// plus the pending count, so the stat strip stays stable while the user
/// flips between status tabs.
class PurchaseTotals {
  const PurchaseTotals({required this.purchases, required this.billAmount, required this.coinsAwarded, required this.pending});

  factory PurchaseTotals.fromJson(Map<String, dynamic>? json) {
    return PurchaseTotals(
      purchases: json?['purchases'] as int? ?? 0,
      billAmount: (json?['bill_amount'] as num?)?.toDouble() ?? 0,
      coinsAwarded: json?['coins_awarded'] as int? ?? 0,
      pending: json?['pending'] as int? ?? 0,
    );
  }

  static const empty = PurchaseTotals(purchases: 0, billAmount: 0, coinsAwarded: 0, pending: 0);

  final int purchases;
  final double billAmount;
  final int coinsAwarded;
  final int pending;
}

/// `meta.totals` of `GET /redemptions?context=management`.
class RedemptionTotals {
  const RedemptionTotals({required this.pending, required this.verified, required this.cancelled, required this.coinsRedeemed});

  factory RedemptionTotals.fromJson(Map<String, dynamic>? json) {
    return RedemptionTotals(
      pending: json?['pending'] as int? ?? 0,
      verified: json?['verified'] as int? ?? 0,
      cancelled: json?['cancelled'] as int? ?? 0,
      coinsRedeemed: json?['coins_redeemed'] as int? ?? 0,
    );
  }

  static const empty = RedemptionTotals(pending: 0, verified: 0, cancelled: 0, coinsRedeemed: 0);

  final int pending;
  final int verified;
  final int cancelled;
  final int coinsRedeemed;
}

/// A management list page: the rows, the pagination meta, and the totals
/// strip that the same response carries.
class ManagementPage<T, Totals> {
  const ManagementPage({required this.items, required this.currentPage, required this.lastPage, required this.total, required this.totals});

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final Totals totals;

  bool get hasMore => currentPage < lastPage;
}
