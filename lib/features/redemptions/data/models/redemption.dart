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
/// returns once, inline from the initiate call (see
/// `RedemptionInitiationResult`). This model covers the customer's own
/// redemption *history*, i.e. `GET /redemptions` and `GET /redemptions/{id}`,
/// plus the resource fields the initiate response shares with them.
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
    this.qrExpiresAt,
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
      qrExpiresAt: json['qr_expires_at'] != null ? DateTime.tryParse(json['qr_expires_at'] as String) : null,
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

  /// When the verification window closes (`qr_expires_at`). The backend
  /// stamps this and the (unexposed) OTP expiry from the same
  /// `now() + config minutes` at initiation, so it is the only client-side
  /// signal for "how long do I have to show this code". Null when the
  /// resource omitted it.
  final DateTime? qrExpiresAt;

  String get merchantName => merchant?.name ?? 'Merchant';

  /// Terminal per `RedemptionStatus::allowedNextStates()` — nothing can
  /// change after these, so pollers stop.
  bool get isTerminal => status == 'settled' || status == 'expired' || status == 'cancelled';
}
