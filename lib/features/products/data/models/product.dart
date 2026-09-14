/// Mirrors `App\Domain\Product\Http\Resources\ProductResource` — one shape
/// for every caller (public/customer and merchant management alike), since
/// a Product has no draft/moderation fields to hide. `status` is present
/// for everyone; the public listing endpoint simply never returns an
/// `inactive` row to begin with (see `ProductsRepository.list`'s docblock).
class Product {
  const Product({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.merchantLogoUrl,
    required this.merchantContactMobileNumber,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrls,
    required this.townCoinPercentage,
    required this.acceptsTownCoin,
    required this.status,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    return Product(
      id: json['id'] as int,
      merchantId: merchant?['id'] as int?,
      merchantName: merchant?['name'] as String? ?? '',
      merchantLogoUrl: merchant?['logo_url'] as String?,
      merchantContactMobileNumber: merchant?['contact_mobile_number'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      imageUrls: (json['image_urls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      townCoinPercentage: json['town_coin_percentage'] != null ? (json['town_coin_percentage'] as num).toDouble() : null,
      acceptsTownCoin: json['accepts_town_coin'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
    );
  }

  final int id;
  final int? merchantId;
  final String merchantName;
  final String? merchantLogoUrl;
  final String? merchantContactMobileNumber;
  final String name;
  final String? description;
  final double price;
  final List<String> imageUrls;
  final double? townCoinPercentage;
  final bool acceptsTownCoin;
  final String status;

  String? get primaryImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  bool get isActive => status == 'active';
}

/// Body for `POST /products` / `PATCH /products/{id}` -- the merchant
/// catalog form's exact field set.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.price,
    this.description,
    this.imageUrls = const [],
    this.townCoinPercentage,
    this.status = 'active',
  });

  final String name;
  final double price;
  final String? description;
  final List<String> imageUrls;

  /// `null` = this product does not accept Town Coin.
  final double? townCoinPercentage;
  final String status;

  Map<String, dynamic> toJson() {
    String? orNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      'name': name.trim(),
      'description': orNull(description),
      'price': price,
      'image_urls': imageUrls.isEmpty ? null : imageUrls,
      'town_coin_percentage': townCoinPercentage,
      'status': status,
    };
  }
}
