/// One merchant's Shop-Exclusive (TU) Coin balance within the wallet —
/// mirrors one entry of `SilverWalletResource`'s `shop_exclusive_breakdown`.
/// `expiresAt` is the nearest lot expiry among that merchant's still-live
/// credit lots; null only when the merchant has no Shop-Exclusive balance
/// left (shouldn't normally appear in the list at all, but the resource
/// doesn't guarantee it).
class ShopExclusiveBreakdownEntry {
  const ShopExclusiveBreakdownEntry({
    required this.merchantId,
    required this.merchantName,
    required this.balance,
    required this.balanceInrEquivalent,
    required this.expiresAt,
  });

  factory ShopExclusiveBreakdownEntry.fromJson(Map<String, dynamic> json) {
    return ShopExclusiveBreakdownEntry(
      merchantId: json['merchant_id'] as int,
      merchantName: json['merchant_name'] as String? ?? 'Merchant',
      balance: json['balance'] as int? ?? 0,
      balanceInrEquivalent: (json['balance_inr_equivalent'] as num?)?.toDouble() ?? 0,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
    );
  }

  final int merchantId;
  final String merchantName;
  final int balance;
  final double balanceInrEquivalent;
  final DateTime? expiresAt;
}

/// Mirrors `App\Domain\Wallet\Http\Resources\SilverWalletResource`. Silver
/// is the customer wallet — see design-principles.md's "Silver vs. Gold"
/// section for why this UI never borrows the platform's warm brand colors.
///
/// Coin Economy V2 (coin-economy-v2.md §1) split `balance` into two pools:
/// [universalBalance] (Universal "T" Coin, spendable anywhere) and
/// [shopExclusiveBalance] (Shop-Exclusive "TU" Coin, locked to whichever
/// merchant it was earned at — see [shopExclusiveBreakdown] for the
/// per-merchant detail and expiry). `balance` itself is still the true
/// total the FIFO redemption priority draws from.
class SilverWalletBalance {
  const SilverWalletBalance({
    required this.balance,
    required this.universalBalance,
    required this.shopExclusiveBalance,
    required this.shopExclusiveBreakdown,
    required this.balanceInrEquivalent,
    required this.updatedAt,
    this.totalRedeemedCoins = 0,
    this.totalSavedInr = 0,
  });

  factory SilverWalletBalance.fromJson(Map<String, dynamic> json) {
    return SilverWalletBalance(
      balance: json['balance'] as int? ?? 0,
      universalBalance: json['universal_balance'] as int? ?? json['balance'] as int? ?? 0,
      shopExclusiveBalance: json['shop_exclusive_balance'] as int? ?? 0,
      shopExclusiveBreakdown: (json['shop_exclusive_breakdown'] as List<dynamic>? ?? const [])
          .map((e) => ShopExclusiveBreakdownEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      balanceInrEquivalent: (json['balance_inr_equivalent'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      totalRedeemedCoins: json['total_redeemed_coins'] as int? ?? 0,
      totalSavedInr: (json['total_saved_inr'] as num?)?.toDouble() ?? 0,
    );
  }

  final int balance;
  final int universalBalance;
  final int shopExclusiveBalance;
  final List<ShopExclusiveBreakdownEntry> shopExclusiveBreakdown;
  final double balanceInrEquivalent;
  final DateTime? updatedAt;

  /// Lifetime coins spent on discounts, and the rupees those discounts
  /// saved (10 coins = ₹1). A saving already received, never cash.
  final int totalRedeemedCoins;
  final double totalSavedInr;

  bool get hasShopExclusiveCoins => shopExclusiveBalance > 0;
}
