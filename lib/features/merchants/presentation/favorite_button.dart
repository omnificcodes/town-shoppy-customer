import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../favorites/application/favorites_controller.dart';

/// The heart on a merchant card and on the merchant detail bar: saves the
/// shop to (or removes it from) the customer's Favorites. The fill flips
/// the instant it is tapped — [FavoriteMerchantIdsController.toggle] is
/// optimistic and rolls back on failure — so there is no spinner state.
/// One widget for every call site keeps the same 48dp target, the same
/// messages and the same screen-reader wording everywhere.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.merchantId, required this.merchantName});

  final int merchantId;
  final String merchantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteMerchantProvider(merchantId));

    return IconButton(
      // Names the shop and the action it will perform, since a row of
      // identical "Save to favorites" buttons is useless to a screen reader.
      tooltip: isFavorite ? 'Remove $merchantName from favorites' : 'Save $merchantName to favorites',
      isSelected: isFavorite,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: AppSpacing.touchTarget, minHeight: AppSpacing.touchTarget),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFavorite),
          size: AppIconSize.md,
          color: isFavorite ? AppColors.crimson : AppColors.textSecondary,
        ),
      ),
      onPressed: () => _toggle(context, ref),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.selectionClick();

    try {
      final nowFavorite = await ref.read(favoriteMerchantIdsProvider.notifier).toggle(merchantId);
      if (nowFavorite == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(nowFavorite ? 'Saved to favorites' : 'Removed from favorites')));
    } on AppException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
