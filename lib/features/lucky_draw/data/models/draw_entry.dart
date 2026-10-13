/// Mirrors `DrawEntryResource`'s exact shape (BR-44): one coupon in a
/// completed draw's locked pool. Masked for everyone but the association's
/// admins -- `entrantName`/`entrantMobileNumber` arrive only for them.
class DrawEntry {
  const DrawEntry({
    required this.id,
    required this.couponId,
    required this.entrantLabel,
    required this.couponCode,
    required this.shopName,
    required this.isWinner,
    this.entrantName,
    this.entrantMobileNumber,
  });

  factory DrawEntry.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>?;
    return DrawEntry(
      id: json['id'] as int,
      couponId: json['coupon_id'] as int,
      entrantLabel: json['entrant_label'] as String,
      entrantName: json['entrant_name'] as String?,
      entrantMobileNumber: json['entrant_mobile_number'] as String?,
      couponCode: json['coupon_code'] as String?,
      shopName: shop?['name'] as String?,
      isWinner: json['is_winner'] as bool? ?? false,
    );
  }

  final int id;
  final int couponId;
  final String entrantLabel;
  final String? entrantName;
  final String? entrantMobileNumber;
  final String? couponCode;
  final String? shopName;
  final bool isWinner;

  String get displayName => entrantName ?? entrantLabel;
}
