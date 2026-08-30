/// A named merchant/branch reference, as returned by `PurchaseResource`'s
/// `merchant`/`branch` fields (`whenLoaded()` — present on `GET /purchases`
/// and `GET /purchases/{id}`, omitted only for a resource built without the
/// relation loaded, which the customer-facing endpoints never do).
class PurchaseMerchantRef {
  const PurchaseMerchantRef({required this.id, required this.name});

  factory PurchaseMerchantRef.fromJson(Map<String, dynamic> json) {
    return PurchaseMerchantRef(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}

/// Mirrors `App\Domain\Purchase\Http\Resources\PurchaseResource` — only the
/// fields a customer can usefully see about their own purchase (never the
/// merchant-facing `duplicate_flag_notes`/`coupon_rule_snapshot` internals,
/// which the backend does return but which are not customer-relevant).
class Purchase {
  const Purchase({
    required this.id,
    required this.merchantId,
    required this.merchant,
    required this.branch,
    required this.billAmount,
    required this.currency,
    required this.billReference,
    required this.coinsAwarded,
    required this.couponsIssued,
    required this.status,
    required this.createdAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as int,
      merchantId: json['merchant_id'] as int,
      merchant: json['merchant'] is Map
          ? PurchaseMerchantRef.fromJson(json['merchant'] as Map<String, dynamic>)
          : null,
      branch: json['branch'] is Map ? PurchaseMerchantRef.fromJson(json['branch'] as Map<String, dynamic>) : null,
      billAmount: (json['bill_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      billReference: json['bill_reference'] as String?,
      coinsAwarded: json['coins_awarded'] as int? ?? 0,
      couponsIssued: json['coupons_issued'] as int?,
      status: json['status'] as String,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int merchantId;
  final PurchaseMerchantRef? merchant;
  final PurchaseMerchantRef? branch;
  final double billAmount;
  final String currency;
  final String? billReference;
  final int coinsAwarded;
  final int? couponsIssued;
  final String status;
  final DateTime? createdAt;

  /// Falls back to a stable placeholder when the relation wasn't loaded
  /// (should not happen for any customer-facing call, but a purchase list
  /// must never crash or show a raw id if it ever does).
  String get merchantName => merchant?.name ?? 'Merchant #$merchantId';
}
