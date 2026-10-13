/// Mirrors `PrizeResource`'s exact shape. On a draw (`DrawResource.prizes`)
/// the row also carries the BR-44 pivot: how many units went into THAT
/// draw (`unitsAllocated`, null = every unit the prize had left) and how
/// many found a winner there (`unitsAwarded`).
class Prize {
  const Prize({
    required this.id,
    required this.sponsorMerchantName,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.quantityTotal,
    required this.quantityRemaining,
    required this.status,
    this.sponsorMerchantId,
    this.value,
    this.unitsAllocated,
    this.unitsAwarded,
  });

  factory Prize.fromJson(Map<String, dynamic> json) {
    final sponsor = json['sponsor_merchant'] as Map<String, dynamic>?;
    return Prize(
      id: json['id'] as int,
      sponsorMerchantId: sponsor?['id'] as int?,
      sponsorMerchantName: sponsor?['name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      value: (json['value'] as num?)?.toDouble(),
      quantityTotal: json['quantity_total'] as int,
      quantityRemaining: json['quantity_remaining'] as int,
      status: json['status'] as String,
      unitsAllocated: json['units_allocated'] as int?,
      unitsAwarded: json['units_awarded'] as int?,
    );
  }

  final int id;
  final int? sponsorMerchantId;
  final String? sponsorMerchantName;
  final String name;
  final String? description;
  final String? imageUrl;
  final double? value;
  final int quantityTotal;
  final int quantityRemaining;
  final String status;
  final int? unitsAllocated;
  final int? unitsAwarded;

  /// Units that were up for grabs in the draw this row came from: the
  /// admin's allocation, or everything the prize had (what was won there
  /// plus what is still left).
  int get unitsInDraw => unitsAllocated ?? (unitsAwarded ?? 0) + quantityRemaining;
}
