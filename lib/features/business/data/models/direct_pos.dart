import '../../../purchases/data/models/purchase.dart';

/// `GET /purchases/customer-lookup` -- who a mobile number belongs to and
/// this merchant's own history with them. Never includes a wallet balance.
class CustomerLookupResult {
  const CustomerLookupResult({
    required this.registered,
    required this.customerProfileId,
    required this.name,
    required this.mobileNumber,
    required this.purchaseCount,
    required this.totalSpent,
    required this.lastPurchaseAt,
  });

  factory CustomerLookupResult.fromJson(Map<String, dynamic> json) {
    return CustomerLookupResult(
      registered: json['registered'] as bool? ?? false,
      customerProfileId: json['id'] as int?,
      name: json['name'] as String?,
      mobileNumber: json['mobile_number'] as String? ?? '',
      purchaseCount: json['purchase_count'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      // A raw DB datetime ("2026-09-01 10:11:12"), not ISO-8601 -- the one
      // timestamp in this API that is not. DateTime.tryParse accepts it.
      lastPurchaseAt: json['last_purchase_at'] is String ? DateTime.tryParse(json['last_purchase_at'] as String) : null,
    );
  }

  final bool registered;
  final int? customerProfileId;
  final String? name;
  final String mobileNumber;
  final int purchaseCount;
  final double totalSpent;
  final DateTime? lastPurchaseAt;
}

/// `POST /purchases/direct-pos/preview`. The money fields arrive as
/// strings (`(string)(float)` on the backend -- "10", not "10.00"), hence
/// the parsing.
class DirectPosPreview {
  const DirectPosPreview({
    required this.billAmount,
    required this.customerName,
    required this.availableBalance,
    required this.maxDiscountAmount,
    required this.maxRedeemableCoins,
    required this.payableAmount,
  });

  factory DirectPosPreview.fromJson(Map<String, dynamic> json) {
    return DirectPosPreview(
      billAmount: double.tryParse('${json['bill_amount']}') ?? 0,
      customerName: json['customer_name'] as String? ?? 'Customer',
      availableBalance: json['available_balance'] as int? ?? 0,
      maxDiscountAmount: double.tryParse('${json['max_discount_amount']}') ?? 0,
      maxRedeemableCoins: json['max_redeemable_coins'] as int? ?? 0,
      payableAmount: double.tryParse('${json['payable_amount']}') ?? 0,
    );
  }

  final double billAmount;
  final String customerName;
  final int availableBalance;
  final double maxDiscountAmount;
  final int maxRedeemableCoins;
  final double payableAmount;
}

/// `POST /purchases/direct-pos` -- the recorded purchase plus what was
/// redeemed on the same bill. [duplicateWarning] is the soft
/// `meta.duplicate_warning` (same customer, amount and merchant within 10
/// minutes); non-blocking, but worth showing.
class DirectPosResult {
  const DirectPosResult({
    required this.purchase,
    required this.redeemedCoins,
    required this.discountAmount,
    required this.payableAmount,
    required this.duplicateWarning,
  });

  factory DirectPosResult.fromJson(Map<String, dynamic> data, {Map<String, dynamic>? meta}) {
    return DirectPosResult(
      purchase: Purchase.fromJson(data['purchase'] as Map<String, dynamic>),
      redeemedCoins: data['redeemed_coins'] as int? ?? 0,
      discountAmount: double.tryParse('${data['discount_amount']}') ?? 0,
      payableAmount: double.tryParse('${data['payable_amount']}') ?? 0,
      duplicateWarning: meta?['duplicate_warning'] as String?,
    );
  }

  final Purchase purchase;
  final int redeemedCoins;
  final double discountAmount;
  final double payableAmount;
  final String? duplicateWarning;
}

/// What identifies the customer at the counter: their typed mobile number
/// (with a name when they are new to Town Shoppy) or the raw string
/// scanned off their identity QR. Exactly one is set.
class DirectPosIdentity {
  const DirectPosIdentity.mobile(this.mobileNumber, {this.customerName}) : qrToken = null;

  const DirectPosIdentity.qr(this.qrToken)
      : mobileNumber = null,
        customerName = null;

  final String? mobileNumber;
  final String? customerName;
  final String? qrToken;

  bool get isQr => qrToken != null;

  Map<String, dynamic> toJson() => {
        if (qrToken != null) 'customer_qr_token': qrToken,
        if (qrToken == null && mobileNumber != null) 'customer_mobile_number': mobileNumber!.trim(),
        if (qrToken == null && customerName != null && customerName!.trim().isNotEmpty) 'customer_name': customerName!.trim(),
      };
}
