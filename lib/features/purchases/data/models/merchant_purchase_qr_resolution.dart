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
    );
  }

  final int merchantId;
  final String merchantName;
  final int branchId;
  final String branchName;
  final String? branchAddressLine;
}
