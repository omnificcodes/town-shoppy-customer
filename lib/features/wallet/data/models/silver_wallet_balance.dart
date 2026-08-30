/// Mirrors `App\Domain\Wallet\Http\Resources\SilverWalletResource`. Silver
/// is the customer wallet — see design-principles.md's "Silver vs. Gold"
/// section for why this UI never borrows the platform's warm brand colors.
class SilverWalletBalance {
  const SilverWalletBalance({required this.balance, required this.balanceInrEquivalent, required this.updatedAt});

  factory SilverWalletBalance.fromJson(Map<String, dynamic> json) {
    return SilverWalletBalance(
      balance: json['balance'] as int? ?? 0,
      balanceInrEquivalent: (json['balance_inr_equivalent'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  final int balance;
  final double balanceInrEquivalent;
  final DateTime? updatedAt;
}
