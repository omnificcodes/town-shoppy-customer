/// Mirrors `SilverLedgerEntryResource`'s exact shape -- deliberately never
/// includes `reference_type`/`reference_id` (audit-only, not meant for
/// client traversal, per the backend resource's own docblock).
///
/// Coin Economy V2 (coin-economy-v2.md §1) -- [coinType] and
/// [merchantName] are only ever set on a credit row (a debit is an
/// aggregate spend, not tied to one coin type -- see
/// `CoinLedgerService::debit()`'s own docblock); both are null on every
/// pre-V2 row and on all debit rows.
class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.direction,
    required this.amount,
    required this.source,
    required this.coinType,
    required this.merchantName,
    required this.balanceAfter,
    required this.lotExpiresAt,
    required this.createdAt,
  });

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return WalletLedgerEntry(
      id: json['id'] as int,
      direction: json['direction'] as String,
      amount: json['amount'] as int,
      source: json['source'] as String,
      coinType: json['coin_type'] as String?,
      merchantName: json['merchant_name'] as String?,
      balanceAfter: json['balance_after'] as int,
      lotExpiresAt: json['lot_expires_at'] != null ? DateTime.tryParse(json['lot_expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final String direction;
  final int amount;
  final String source;
  final String? coinType;
  final String? merchantName;
  final int balanceAfter;
  final DateTime? lotExpiresAt;
  final DateTime? createdAt;

  bool get isCredit => direction == 'credit';
  bool get isShopExclusive => coinType == 'shop_exclusive';
}
