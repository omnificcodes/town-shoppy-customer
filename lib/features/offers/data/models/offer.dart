/// Mirrors `App\Domain\Offer\Http\Resources\PublicOfferResource` exactly —
/// the only shape a guest or customer ever receives from `GET /offers` /
/// `GET /offers/nearby` / `GET /offers/{id}`. Never includes `status`,
/// `created_by_owner`/`created_by_staff`, or any other moderation/internal
/// field — those exist only on `OfferResource`, which this app never
/// reaches (Slice 7 brief Part 8: "Customer should NEVER see... internal
/// moderation data").
class Offer {
  const Offer({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.merchantLogoUrl,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.offerType,
    required this.discountValue,
    required this.terms,
    required this.startsAt,
    required this.endsAt,
    required this.distanceKm,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    return Offer(
      id: json['id'] as int,
      merchantId: merchant?['id'] as int?,
      merchantName: merchant?['name'] as String? ?? '',
      merchantLogoUrl: merchant?['logo_url'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      offerType: json['offer_type'] as String,
      discountValue: json['discount_value'] != null ? (json['discount_value'] as num).toDouble() : null,
      terms: json['terms'] as String?,
      startsAt: json['starts_at'] != null ? DateTime.parse(json['starts_at'] as String) : null,
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
    );
  }

  final int id;
  final int? merchantId;
  final String merchantName;
  final String? merchantLogoUrl;
  final String title;
  final String? description;
  final String? imageUrl;
  final String offerType;
  final double? discountValue;
  final String? terms;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double? distanceKm;
}
