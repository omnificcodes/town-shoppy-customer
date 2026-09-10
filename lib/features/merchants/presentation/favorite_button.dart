import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// The heart action on a merchant card. A UI-only stub — there is no
/// favorites/wishlist concept anywhere in the backend yet, so it surfaces a
/// "coming soon" message rather than pretending to persist anything (same
/// pattern Wallet's Terms & Conditions/Help & Support use). Shared by
/// [MerchantCard] and [NearbyMerchantCard] so both keep the same 48dp
/// target and the same message.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.merchantName});

  final String merchantName;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Save to favorites',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: AppSpacing.touchTarget, minHeight: AppSpacing.touchTarget),
      icon: const Icon(Icons.favorite_border_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorites is coming soon.'))),
    );
  }
}
