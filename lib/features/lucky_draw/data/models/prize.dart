/// Mirrors `PrizeResource`'s exact shape.
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
  });

  factory Prize.fromJson(Map<String, dynamic> json) {
    final sponsor = json['sponsor_merchant'] as Map<String, dynamic>?;
    return Prize(
      id: json['id'] as int,
      sponsorMerchantName: sponsor?['name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      quantityTotal: json['quantity_total'] as int,
      quantityRemaining: json['quantity_remaining'] as int,
      status: json['status'] as String,
    );
  }

  final int id;
  final String? sponsorMerchantName;
  final String name;
  final String? description;
  final String? imageUrl;
  final int quantityTotal;
  final int quantityRemaining;
  final String status;
}
