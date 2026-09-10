import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/models/merchant_branch_ref.dart';

/// A reusable branch list/picker. Pass [onSelected] to make it an
/// interactive picker (a future redemption-initiation flow's use case);
/// leave it null for a read-only info display (how `MerchantDetailScreen`
/// uses it today).
///
/// There is no opening-hours field anywhere in `MerchantBranchResource`, so
/// none is ever rendered here — showing invented hours would be exactly the
/// kind of fabricated field the phase brief prohibits.
///
/// Fed by `merchantBranchesProvider` (`GET /merchants/{id}/branches`, Phase
/// 4), which can return zero, one, or many branches — the "Primary" label
/// below only ever renders when there's more than one, so a merchant with a
/// single branch still displays it plainly, as it always has.
class BranchSelector extends StatelessWidget {
  const BranchSelector({super.key, required this.branches, this.selectedId, this.onSelected});

  final List<MerchantBranchRef> branches;
  final int? selectedId;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No branch information available',
        message: 'This merchant has not published a branch location yet.',
      );
    }

    final showPrimaryLabel = branches.length > 1;

    return Column(
      children: [
        for (final branch in branches) ...[
          _BranchTile(
            branch: branch,
            selected: selectedId == branch.id,
            showPrimaryLabel: showPrimaryLabel,
            onTap: onSelected == null ? null : () => onSelected!(branch.id),
          ),
          if (branch != branches.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({required this.branch, required this.selected, required this.showPrimaryLabel, this.onTap});

  final MerchantBranchRef branch;
  final bool selected;
  final bool showPrimaryLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelectable = onTap != null;
    final address = branch.formattedAddress;
    final isPrimaryLabeled = showPrimaryLabel && branch.isPrimary;

    return Semantics(
      button: isSelectable,
      selected: isSelectable ? selected : null,
      label:
          '${isPrimaryLabeled ? 'Primary branch, ' : ''}${branch.name ?? 'Branch'}${address.isNotEmpty ? ', $address' : ''}',
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectable) ...[
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: AppIconSize.lg,
                color: selected ? AppColors.orange : AppColors.textDisabled,
              ),
              const SizedBox(width: AppSpacing.sm),
            ] else ...[
              const Icon(Icons.storefront_rounded, size: AppIconSize.lg, color: AppColors.silverDark),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPrimaryLabeled) ...[
                    Text(
                      'Primary',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  Text(branch.name ?? 'Branch', style: Theme.of(context).textTheme.titleSmall),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(address, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
