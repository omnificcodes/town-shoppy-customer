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
    this.mrp,
    this.discountAmount,
    this.discountPercentage,
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
      townCoinPercentage: json['town_coin_percentage'] != null
          ? (json['town_coin_percentage'] as num).toDouble()
          : null,
      acceptsTownCoin: json['accepts_town_coin'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      mrp: (json['mrp'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble(),
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

  /// The price before the offer, when the merchant set one. [price] is
  /// always what the customer pays.
  final double? mrp;

  /// What the offer saves, as the server derived it from the two prices --
  /// null when there is no MRP or it does not beat the price. Recomputed
  /// locally only if an older API omits the fields entirely.
  final double? discountAmount;
  final double? discountPercentage;

  double? get saving {
    final shown = discountAmount;
    if (shown != null) return shown > 0 ? shown : null;
    final original = mrp;
    if (original == null) return null;
    final diff = double.parse((original - price).toStringAsFixed(2));
    return diff > 0 ? diff : null;
  }

  double? get savingPercentage {
    final shown = discountPercentage;
    if (shown != null) return shown > 0 ? shown : null;
    final amount = saving;
    final original = mrp;
    if (amount == null || original == null || original <= 0) return null;
    return double.parse((amount / original * 100).toStringAsFixed(1));
  }

  bool get hasDiscount => saving != null;

  String? get primaryImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  bool get isActive => status == 'active';
}

/// Body for `POST /products` / `PATCH /products/{id}` -- the merchant
/// catalog form's exact field set.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.price,
    this.mrp,
    this.description,
    this.imageUrls = const [],
    this.townCoinPercentage,
    this.status = 'active',
  });

  final String name;

  /// What the customer pays.
  final double price;

  /// The price before the offer; `null` clears it (no discount shown).
  final double? mrp;
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
      'mrp': mrp,
      'image_urls': imageUrls.isEmpty ? null : imageUrls,
      'town_coin_percentage': townCoinPercentage,
      'status': status,
    };
  }
}
