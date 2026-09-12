/// Method 1 (3-way purchase architecture) — what scanning a merchant/
/// branch's Purchase QR resolves to, mirroring `PurchaseController::
/// resolveMerchantQr()`'s response shape exactly.
class MerchantPurchaseQrResolution {
  const MerchantPurchaseQrResolution({
    required this.merchantId,
    required this.merchantName,
    required this.branchId,
    required this.branchName,
    required this.branchAddressLine,
    required this.acceptsTownCoin,
    required this.discountRate,
  });

  factory MerchantPurchaseQrResolution.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>;
    final branch = json['branch'] as Map<String, dynamic>;
    return MerchantPurchaseQrResolution(
      merchantId: merchant['id'] as int,
      merchantName: merchant['name'] as String,
      branchId: branch['id'] as int,
      branchName: branch['name'] as String,
      branchAddressLine: branch['address_line'] as String?,
      acceptsTownCoin: merchant['accepts_town_coin'] as bool? ?? false,
      discountRate: (merchant['discount_rate'] as num?)?.toDouble(),
    );
  }

  final int merchantId;
  final String merchantName;
  final int branchId;
  final String branchName;
  final String? branchAddressLine;

  /// Whether this merchant takes Town Coin at all, and at what percentage
  /// of the bill. Both arrive with the scan so the savings line can update
  /// as the customer types, with no round trip per keystroke. The server
  /// recomputes the real figure when the request is submitted.
  final bool acceptsTownCoin;
  final double? discountRate;

  bool get canDiscount => acceptsTownCoin && (discountRate ?? 0) > 0;
}
