/// A named merchant/branch reference, as returned by `RedemptionResource`'s
/// `merchant`/`branch` fields.
class RedemptionMerchantRef {
  const RedemptionMerchantRef({required this.id, required this.name});

  factory RedemptionMerchantRef.fromJson(Map<String, dynamic> json) {
    return RedemptionMerchantRef(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}

/// Mirrors `App\Domain\Redemption\Http\Resources\RedemptionResource` —
/// never includes `qr_secret`/`otp_code`, which the backend only ever
/// returns once, inline from the initiate call this app does not perform
/// (redeeming — choosing a merchant and starting a new redemption — is out
/// of scope for this phase; see the phase report's known-limitations
/// section). This model only covers the customer's own redemption
/// *history*, i.e. `GET /redemptions` and `GET /redemptions/{id}`.
class Redemption {
  const Redemption({
    required this.id,
    required this.merchant,
    required this.branch,
    required this.billAmount,
    required this.discountAmount,
    required this.remainingBillAmount,
    required this.coinsRequested,
    required this.coinsDebited,
    required this.status,
    required this.verificationMethod,
    required this.verifiedAt,
    required this.createdAt,
  });

  factory Redemption.fromJson(Map<String, dynamic> json) {
    return Redemption(
      id: json['id'] as int,
      merchant: json['merchant'] is Map
          ? RedemptionMerchantRef.fromJson(json['merchant'] as Map<String, dynamic>)
          : null,
      branch: json['branch'] is Map ? RedemptionMerchantRef.fromJson(json['branch'] as Map<String, dynamic>) : null,
      billAmount: (json['bill_amount'] as num).toDouble(),
      discountAmount: json['discount_amount'] != null ? (json['discount_amount'] as num).toDouble() : null,
      remainingBillAmount: json['remaining_bill_amount'] != null ? (json['remaining_bill_amount'] as num).toDouble() : null,
      coinsRequested: json['coins_requested'] as int? ?? 0,
      coinsDebited: json['coins_debited'] as int?,
      status: json['status'] as String,
      verificationMethod: json['verification_method'] as String?,
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final RedemptionMerchantRef? merchant;
  final RedemptionMerchantRef? branch;
  final double billAmount;
  final double? discountAmount;
  final double? remainingBillAmount;
  final int coinsRequested;
  final int? coinsDebited;
  final String status;
  final String? verificationMethod;
  final DateTime? verifiedAt;
  final DateTime? createdAt;

  String get merchantName => merchant?.name ?? 'Merchant';
}
