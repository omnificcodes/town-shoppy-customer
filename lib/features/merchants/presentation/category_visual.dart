import 'package:flutter/material.dart';

/// Icon + tint for a [MerchantCategory] tile — the backend category table
/// (`MerchantCategoryResource`) is `id`/`name`/`slug` only, no icon or color
/// column (see `merchant_category.dart`'s own doc comment), so this is a
/// client-side, keyword-matched lookup rather than something read from the
/// API. Matches on `name`/`slug` substrings so it degrades gracefully across
/// the real category list instead of requiring an exact name for every one
/// (seed/admin-entered category names vary: "Salon" vs "Salon & Spa" both
/// need to land on the same tile). [fallback] covers anything unmatched
/// (e.g. "General") so a tile never renders blank.
class CategoryVisual {
  const CategoryVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static const fallback = CategoryVisual(icon: Icons.storefront_rounded, color: Color(0xFFFF6B00));

  static const _rules = <(List<String>, CategoryVisual)>[
    (
      ['grocery', 'supermarket', 'general'],
      CategoryVisual(icon: Icons.shopping_cart_rounded, color: Color(0xFF2E7D32)),
    ),
    (
      ['restaurant', 'food', 'bakery', 'sweet'],
      CategoryVisual(icon: Icons.restaurant_rounded, color: Color(0xFFE64A19)),
    ),
    (
      ['salon', 'spa', 'beauty', 'cosmetic'],
      CategoryVisual(icon: Icons.face_retouching_natural_rounded, color: Color(0xFFD81B60)),
    ),
    (
      ['pharmacy', 'health', 'optical', 'eyewear'],
      CategoryVisual(icon: Icons.local_pharmacy_rounded, color: Color(0xFF00897B)),
    ),
    (
      ['electronics', 'mobile', 'gadget'],
      CategoryVisual(icon: Icons.devices_rounded, color: Color(0xFF1E88E5)),
    ),
    (
      ['automobile', 'auto ', 'vehicle', 'spare part'],
      CategoryVisual(icon: Icons.directions_car_rounded, color: Color(0xFF6A1B9A)),
    ),
    (
      ['cloth', 'fashion', 'textile', 'fabric', 'footwear'],
      CategoryVisual(icon: Icons.checkroom_rounded, color: Color(0xFFAD1457)),
    ),
    (
      ['furniture', 'decor', 'hardware', 'home improvement'],
      CategoryVisual(icon: Icons.chair_rounded, color: Color(0xFF6D4C41)),
    ),
    (
      ['jewellery', 'jewelry', 'gift', 'novelt'],
      CategoryVisual(icon: Icons.diamond_rounded, color: Color(0xFFC9A227)),
    ),
    (
      ['stationery', 'book'],
      CategoryVisual(icon: Icons.menu_book_rounded, color: Color(0xFF3949AB)),
    ),
    (
      ['sport', 'fitness', 'gym'],
      CategoryVisual(icon: Icons.fitness_center_rounded, color: Color(0xFFF4511E)),
    ),
    (
      ['toy', 'kid'],
      CategoryVisual(icon: Icons.toys_rounded, color: Color(0xFF8E24AA)),
    ),
    (
      ['agri', 'farm'],
      CategoryVisual(icon: Icons.agriculture_rounded, color: Color(0xFF558B2F)),
    ),
  ];

  static CategoryVisual forCategory({required String name, required String slug}) {
    final haystack = '${name.toLowerCase()} ${slug.toLowerCase()}';
    for (final (keywords, visual) in _rules) {
      if (keywords.any(haystack.contains)) return visual;
    }
    return fallback;
  }
}
