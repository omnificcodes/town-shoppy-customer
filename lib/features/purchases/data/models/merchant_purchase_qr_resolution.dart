import '../../../merchants/data/models/merchant.dart';

/// Method 1 (3-way purchase architecture) — who a counter purchase is
/// being requested from: what scanning a merchant/branch's Purchase QR
/// resolves to (mirroring `PurchaseController::resolveMerchantQr()`'s
/// response shape exactly), or the same picture built from a merchant
/// profile the customer is already looking at ([fromMerchant]).
class MerchantPurchaseQrResolution {
  const MerchantPurchaseQrResolution({
    required this.merchantId,
    required this.merchantName,
    required this.branchId,
    required this.branchName,
    required this.branchAddressLine,
    required this.acceptsTownCoin,
    required this.discountRate,
    this.logoUrl,
  });

  factory MerchantPurchaseQrResolution.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>;
    final branch = json['branch'] as Map<String, dynamic>;
    return MerchantPurchaseQrResolution(
      merchantId: merchant['id'] as int,
      merchantName: merchant['name'] as String,
      logoUrl: merchant['logo_url'] as String?,
      branchId: branch['id'] as int,
      branchName: branch['name'] as String,
      branchAddressLine: branch['address_line'] as String?,
      acceptsTownCoin: merchant['accepts_town_coin'] as bool? ?? false,
      discountRate: (merchant['discount_rate'] as num?)?.toDouble(),
    );
  }

  /// "Pay bill with coins" from the shop's profile: no scan, so nothing
  /// to resolve -- the profile already carries everything the request
  /// screen shows, and the server picks the branch (the primary, unless
  /// the profile names one) when the request is submitted.
  factory MerchantPurchaseQrResolution.fromMerchant(Merchant merchant) {
    final branch = merchant.branch;
    return MerchantPurchaseQrResolution(
      merchantId: merchant.id,
      merchantName: merchant.name,
      logoUrl: merchant.logoUrl,
      branchId: branch?.id,
      branchName: branch?.name ?? '',
      branchAddressLine: branch?.addressLine,
      acceptsTownCoin: merchant.acceptsTownCoin,
      discountRate: merchant.discountRate,
    );
  }

  final int merchantId;
  final String merchantName;
  final String? logoUrl;

  /// Null only for a profile-started request from a merchant whose
  /// primary branch is not listed; the server resolves it either way.
  final int? branchId;
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
