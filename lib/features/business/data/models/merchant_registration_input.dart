import 'business_hours.dart';

/// Everything `POST /merchants` (`RegisterMerchantRequest`) accepts. The
/// required set is exactly the backend's; the optional strings are sent
/// only when non-empty, matching the merchant web app's payload builder.
class MerchantRegistrationInput {
  const MerchantRegistrationInput({
    required this.name,
    required this.ownerName,
    required this.associationId,
    required this.categoryId,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    required this.discountRate,
    this.city,
    this.state,
    this.postalCode,
    this.contactMobileNumber,
    this.description,
    this.logoUrl,
    this.coverImageUrl,
  });

  final String name;
  final String ownerName;
  final int associationId;
  final int categoryId;
  final String addressLine;
  final double latitude;
  final double longitude;

  /// The share of a bill (percent) a customer may pay with Town Coin.
  /// Required: every business accepts Town Coin, so every business has a
  /// rate. Acceptance itself is not sent -- the server switches it on.
  final double discountRate;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? contactMobileNumber;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;

  Map<String, dynamic> toJson() {
    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      'name': name.trim(),
      'owner_name': ownerName.trim(),
      'association_id': associationId,
      'category_id': categoryId,
      'address_line': addressLine.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'discount_rate': discountRate,
      // A new business starts open 9 to 6 every day; it can change this
      // from its profile at any time.
      'business_hours': BusinessHours.standard.toJson(),
      if (clean(city) != null) 'city': clean(city),
      if (clean(state) != null) 'state': clean(state),
      if (clean(postalCode) != null) 'postal_code': clean(postalCode),
      if (clean(contactMobileNumber) != null) 'contact_mobile_number': clean(contactMobileNumber),
      if (clean(description) != null) 'description': clean(description),
      if (clean(logoUrl) != null) 'logo_url': clean(logoUrl),
      if (clean(coverImageUrl) != null) 'cover_image_url': clean(coverImageUrl),
    };
  }
}
