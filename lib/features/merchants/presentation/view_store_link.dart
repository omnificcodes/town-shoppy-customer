import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// The "View Store" affordance in a merchant card's footer row. Purely a
/// visual hint — the whole card is the tap target — so it is not a button
/// of its own and carries no semantics beyond its text.
class ViewStoreLink extends StatelessWidget {
  const ViewStoreLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'View Store',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: AppSpacing.xxs),
        const Icon(Icons.arrow_forward_rounded, size: AppIconSize.sm, color: AppColors.orange),
      ],
    );
  }
}
