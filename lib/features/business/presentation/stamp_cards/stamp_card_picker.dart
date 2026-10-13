import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../stamp_cards/data/models/stamp_card.dart';
import '../../../stamp_cards/presentation/stamp_card_style.dart';

/// A sheet asking "Add a stamp with this bill?" -- one row per running
/// card, with the customer's progress on it when known, plus "No stamp".
/// Returns the chosen programme's id, null for no stamp, and nothing when
/// the sheet is dismissed.
Future<({int? programmeId})?> showStampCardPicker(
  BuildContext context,
  StampCardProgrammes programmes, {
  List<CustomerStampCard> progress = const [],
  double? billAmount,
}) {
  return showModalBottomSheet<({int? programmeId})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a stamp with this bill?', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text('One stamp per bill. Never required.', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final programme in programmes.active) ...[
                      StampProgrammeRow(
                        programme: programme,
                        progress: progress.where((c) => c.stampCardId == programme.id).firstOrNull,
                        billAmount: billAmount,
                        onTap: () => Navigator.of(context).pop((programmeId: programme.id)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop((programmeId: null)),
                icon: const Icon(Icons.block_rounded),
                label: const Text('No stamp this time'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One programme as a row for the counter: its icon, the offer, and --
/// when the customer is known -- where their card stands. Greyed out
/// when this bill cannot take a stamp (full card, or under the minimum).
class StampProgrammeRow extends StatelessWidget {
  const StampProgrammeRow({super.key, required this.programme, this.progress, this.billAmount, this.onTap, this.trailing, this.selected = false});

  final StampCardProgramme programme;
  final CustomerStampCard? progress;
  final double? billAmount;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final style = StampCardStyle.of(programme.icon);
    final textTheme = Theme.of(context).textTheme;
    final minimum = programme.minBillAmount;
    final underMinimum = minimum != null && billAmount != null && billAmount! < minimum;
    final full = progress?.isFull == true;
    final blocked = underMinimum || full;
    final note = full
        ? 'Card full — give the ${progress!.rewardText} first'
        : underMinimum
        ? 'Needs a bill of ${formatMoney(minimum)} or more'
        : progress != null
        ? '${progress!.stampsCount} of ${progress!.stampsRequired} stamps so far'
        : (minimum != null ? 'Bills of ${formatMoney(minimum)} or more' : null);

    return Opacity(
      opacity: blocked ? 0.55 : 1,
      child: Material(
        color: selected ? AppColors.businessTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: blocked ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.smd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: selected ? AppColors.businessInk : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: style.gradient, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  child: Text(style.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(programme.title, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(programme.summary, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (note != null)
                        Text(
                          note,
                          style: AppTypography.caption.copyWith(color: full ? AppColors.success : (underMinimum ? AppColors.error : AppColors.textSecondary), fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
