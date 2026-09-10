/// Mirrors `App\Domain\Offer\Http\Resources\OfferRedemptionResource`
/// exactly (coin-economy-v2.md §6.2). Distinct from `Redemption`
/// (`features/redemptions`) -- that one is the general OTP-verified
/// coin redemption at any accepting merchant; this one is a customer
/// requesting the specific coin discount a merchant set on one `Offer`,
/// which the merchant then approves or rejects (no OTP, no coins move
/// until approval).
class OfferRedemption {
  const OfferRedemption({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.merchantId,
    required this.billAmount,
    required this.maxDiscountAmount,
    required this.coinsRequested,
    required this.coinsApplied,
    required this.discountAmount,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
    required this.reviewedAt,
  });

  factory OfferRedemption.fromJson(Map<String, dynamic> json) {
    return OfferRedemption(
      id: json['id'] as int,
      offerId: json['offer_id'] as int,
      offerTitle: json['offer_title'] as String?,
      merchantId: json['merchant_id'] as int,
      billAmount: (json['bill_amount'] as num).toDouble(),
      maxDiscountAmount: (json['max_discount_amount'] as num).toDouble(),
      coinsRequested: json['coins_requested'] as int? ?? 0,
      coinsApplied: json['coins_applied'] as int?,
      discountAmount: json['discount_amount'] != null ? (json['discount_amount'] as num).toDouble() : null,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'] as String) : null,
    );
  }

  final int id;
  final int offerId;
  final String? offerTitle;
  final int merchantId;
  final double billAmount;
  final double maxDiscountAmount;
  final int coinsRequested;
  final int? coinsApplied;
  final double? discountAmount;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  String get title => offerTitle ?? 'Offer';

  /// Terminal per `OfferRedemptionStatus::allowedNextStates()` -- `pending`
  /// is the only state that can still change.
  bool get isTerminal => status != 'pending';
}
