import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class BusinessStat {
  const BusinessStat({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;
}

/// The row of totals under a list screen's title, inside the maroon band --
/// the mobile form of the web's four `StatTile`s. Scrolls sideways on a
/// narrow phone rather than wrapping into a tall block.
class BusinessStatStrip extends StatelessWidget {
  const BusinessStatStrip({super.key, required this.stats, this.isLoading = false});

  final List<BusinessStat> stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, s) in stats.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Semantics(
              label: '${s.label}: ${s.value}${s.hint != null ? ', ${s.hint}' : ''}',
              child: Container(
                constraints: const BoxConstraints(minWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.onBusinessInk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.onBusinessInk.withValues(alpha: 0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label, style: AppTypography.caption.copyWith(color: AppColors.onBusinessInkMuted)),
                    const SizedBox(height: AppSpacing.xxs),
                    if (isLoading)
                      Container(
                        width: 48,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.onBusinessInk.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        ),
                      )
                    else
                      Text(s.value, style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.onBusinessInk, fontSize: 20)),
                    if (s.hint != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(s.hint!, style: AppTypography.overline.copyWith(color: AppColors.onBusinessInkMuted, letterSpacing: 0.4)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
