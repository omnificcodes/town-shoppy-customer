/// Mirrors `MerchantBranchPrivateResource` -- the merchant's own view of a
/// branch (`GET/POST/PATCH /merchant-branches`). The public half of that
/// resource drops every null key (`array_filter`), so all the address parts
/// are nullable here; the private additions (`cover_image_url`, `status`)
/// are emitted even when null.
class MerchantBranch {
  const MerchantBranch({
    required this.id,
    required this.merchantId,
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
    required this.coverImageUrl,
    required this.status,
    required this.createdAt,
  });

  factory MerchantBranch.fromJson(Map<String, dynamic> json) {
    return MerchantBranch(
      id: json['id'] as int,
      merchantId: json['merchant_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Branch',
      isPrimary: json['is_primary'] as bool? ?? false,
      addressLine: json['address_line'] as String?,
      locality: json['locality'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      coverImageUrl: json['cover_image_url'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  final int id;
  final int merchantId;
  final String name;
  final bool isPrimary;
  final String? addressLine;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? coverImageUrl;

  /// `active | inactive` -- the only two values.
  final String status;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  /// Joined from whichever parts exist -- the web's card does the same.
  String get formattedAddress {
    final parts = [addressLine, locality, city, state, postalCode].whereType<String>().where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'No address on file.' : parts.join(', ');
  }
}

/// `POST /merchant-branches` / `PATCH /merchant-branches/{id}` body. Every
/// empty optional string is sent as `null` (clears the column), matching
/// the web app's payload builder; `country` is never sent.
class BranchInput {
  const BranchInput({
    required this.name,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    this.coverImageUrl,
    this.locality,
    this.city,
    this.state,
    this.postalCode,
    this.isPrimary = false,
  });

  final String name;
  final String addressLine;
  final double latitude;
  final double longitude;
  final String? coverImageUrl;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;
  final bool isPrimary;

  Map<String, dynamic> toJson() {
    String? orNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      'name': name.trim(),
      'cover_image_url': orNull(coverImageUrl),
      'address_line': addressLine.trim(),
      'locality': orNull(locality),
      'city': orNull(city),
      'state': orNull(state),
      'postal_code': orNull(postalCode),
      'latitude': latitude,
      'longitude': longitude,
      'is_primary': isPrimary,
    };
  }
}
