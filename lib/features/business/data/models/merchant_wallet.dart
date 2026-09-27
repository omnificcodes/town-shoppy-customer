/// `GET /merchant-wallet` (`MerchantWalletResource`) -- Coin Economy V2 §3.
///
/// * **Blue Coin** is spendable: earned at full value whenever a customer
///   redeems coins at this shop, and spendable for a discount on the
///   shop's own bill at *another* Town Shoppy merchant, at the platform's
///   coin-to-rupee rate ([coinToInrRate], published by the server).
/// * **Red Coin** is recorded only: credited alongside Blue, plus
///   subscription-spend bonuses, kept for a future feature. Never
///   spendable today.
class MerchantWallet {
  const MerchantWallet({
    required this.blueBalance,
    required this.redBalance,
    required this.updatedAt,
    this.coinToInrRate = 1,
  });

  factory MerchantWallet.fromJson(Map<String, dynamic> json) {
    return MerchantWallet(
      blueBalance: json['blue_balance'] as int? ?? 0,
      redBalance: json['red_balance'] as int? ?? 0,
      updatedAt: json['updated_at'] is String ? DateTime.tryParse(json['updated_at'] as String) : null,
      coinToInrRate: json['coin_to_inr_rate'] as int? ?? 1,
    );
  }

  static const empty = MerchantWallet(blueBalance: 0, redBalance: 0, updatedAt: null);

  final int blueBalance;
  final int redBalance;
  final DateTime? updatedAt;

  /// How many coins make ₹1 -- the same rate the customer wallet reports,
  /// never hardcoded here (1 coin = ₹1 since 2026-09-26).
  final int coinToInrRate;

  double get blueInr => blueBalance / coinToInrRate;
  double get redInr => redBalance / coinToInrRate;
}

/// `POST /merchant-wallet/blue-coin/redeem` (`MerchantBlueRedemptionResource`).
/// Money fields are strings on this one resource ("100.00").
class MerchantBlueRedemption {
  const MerchantBlueRedemption({
    required this.id,
    required this.redeemingMerchantId,
    required this.redeemingMerchantName,
    required this.billAmount,
    required this.discountAmount,
    required this.coinsDebited,
    required this.createdAt,
  });

  factory MerchantBlueRedemption.fromJson(Map<String, dynamic> json) {
    return MerchantBlueRedemption(
      id: json['id'] as int,
      redeemingMerchantId: json['redeeming_merchant_id'] as int? ?? 0,
      redeemingMerchantName: json['redeeming_merchant_name'] as String?,
      billAmount: double.tryParse('${json['bill_amount']}') ?? 0,
      discountAmount: double.tryParse('${json['discount_amount']}') ?? 0,
      coinsDebited: json['coins_debited'] as int? ?? 0,
      createdAt: json['created_at'] is String ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int redeemingMerchantId;
  final String? redeemingMerchantName;
  final double billAmount;
  final double discountAmount;
  final int coinsDebited;
  final DateTime? createdAt;
}
