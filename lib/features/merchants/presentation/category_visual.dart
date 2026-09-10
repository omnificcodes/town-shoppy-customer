import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Icon + tint for a [MerchantCategory] tile — the backend category table
/// (`MerchantCategoryResource`) is `id`/`name`/`slug` only, no icon or color
/// column (see `merchant_category.dart`'s own doc comment), so this is a
/// client-side, keyword-matched lookup rather than something read from the
/// API. Matches on `name`/`slug` substrings so it degrades gracefully across
/// the real category list instead of requiring an exact name for every one
/// (seed/admin-entered category names vary: "Salon" vs "Salon & Spa" both
/// need to land on the same tile). [fallback] covers anything unmatched
/// (e.g. "General") so a tile never renders blank.
///
/// Every tint is one of [AppColors.decorativeAccents] — purely visual
/// variety, never a status meaning — so this file owns no hex of its own.
class CategoryVisual {
  const CategoryVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static const fallback = CategoryVisual(icon: Icons.storefront_rounded, color: AppColors.orange);

  static final _rules = <(List<String>, CategoryVisual)>[
    (
      ['grocery', 'supermarket', 'general'],
      CategoryVisual(icon: Icons.shopping_cart_rounded, color: AppColors.decorativeAccents[0]),
    ),
    (
      ['restaurant', 'food', 'bakery', 'sweet'],
      CategoryVisual(icon: Icons.restaurant_rounded, color: AppColors.decorativeAccents[1]),
    ),
    (
      ['salon', 'spa', 'beauty', 'cosmetic'],
      CategoryVisual(icon: Icons.face_retouching_natural_rounded, color: AppColors.decorativeAccents[2]),
    ),
    (
      ['pharmacy', 'health', 'optical', 'eyewear'],
      CategoryVisual(icon: Icons.local_pharmacy_rounded, color: AppColors.decorativeAccents[3]),
    ),
    (
      ['electronics', 'mobile', 'gadget'],
      CategoryVisual(icon: Icons.devices_rounded, color: AppColors.decorativeAccents[4]),
    ),
    (
      ['automobile', 'auto ', 'vehicle', 'spare part'],
      CategoryVisual(icon: Icons.directions_car_rounded, color: AppColors.decorativeAccents[5]),
    ),
    (
      ['cloth', 'fashion', 'textile', 'fabric', 'footwear'],
      CategoryVisual(icon: Icons.checkroom_rounded, color: AppColors.decorativeAccents[6]),
    ),
    (
      ['furniture', 'decor', 'hardware', 'home improvement'],
      CategoryVisual(icon: Icons.chair_rounded, color: AppColors.decorativeAccents[7]),
    ),
    (
      ['jewellery', 'jewelry', 'gift', 'novelt'],
      CategoryVisual(icon: Icons.diamond_rounded, color: AppColors.decorativeAccents[8]),
    ),
    (
      ['stationery', 'book'],
      CategoryVisual(icon: Icons.menu_book_rounded, color: AppColors.decorativeAccents[9]),
    ),
    (
      ['sport', 'fitness', 'gym'],
      CategoryVisual(icon: Icons.fitness_center_rounded, color: AppColors.decorativeAccents[10]),
    ),
    (
      ['toy', 'kid'],
      CategoryVisual(icon: Icons.toys_rounded, color: AppColors.decorativeAccents[11]),
    ),
    (
      ['agri', 'farm'],
      CategoryVisual(icon: Icons.agriculture_rounded, color: AppColors.decorativeAccents[12]),
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
