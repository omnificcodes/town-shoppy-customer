/// Mirrors `App\Domain\Merchant\Http\Resources\MerchantBranchResource`'s
/// public fields. There is no opening-hours field anywhere in this resource
/// — none is rendered anywhere in the UI for that reason. `distanceKm` is
/// only ever populated by `GET /merchants/nearby` (see `NearbyMerchant`),
/// so it stays null for a merchant fetched via `GET /merchants` or
/// `GET /merchants/{id}`.
class MerchantBranchRef {
  const MerchantBranchRef({
    required this.id,
    required this.name,
    required this.isPrimary,
    required this.addressLine,
    required this.locality,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  factory MerchantBranchRef.fromJson(Map<String, dynamic> json) {
    return MerchantBranchRef(
      id: json['id'] as int,
      name: json['name'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      addressLine: json['address_line'] as String?,
      locality: json['locality'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
    );
  }

  final int id;
  final String? name;
  final bool isPrimary;
  final String? addressLine;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  /// A single-line address built only from whichever parts the backend
  /// actually returned (the resource omits null fields entirely — see its
  /// `array_filter()`), never a hardcoded template with blank gaps.
  String get formattedAddress {
    final parts = [addressLine, locality, city, state, postalCode].whereType<String>().where((p) => p.isNotEmpty);
    return parts.join(', ');
  }
}
