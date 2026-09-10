import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/models/wallet_ledger_entry.dart';
import 'wallet_ledger_source_display.dart';

/// One ledger row -- an earn/spend timeline entry, not a bank statement
/// line: a colored direction icon carries the credit/debit distinction at
/// a glance, the amount is the visual anchor (large, tabular), and the
/// running balance stays a quiet caption rather than its own column.
class WalletLedgerTile extends StatelessWidget {
  const WalletLedgerTile({super.key, required this.entry});

  final WalletLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final display = WalletLedgerSourceDisplay.forSource(entry.source);
    final tone = entry.isCredit ? AppColors.success : AppColors.goldDark;
    final toneBg = entry.isCredit ? AppColors.successBg : AppColors.goldLight;
    final amountLabel = '${entry.isCredit ? '+' : '−'}${entry.amount}';

    return Semantics(
      label: '${display.label}, ${entry.isCredit ? 'earned' : 'spent'} ${entry.amount} coins, balance ${entry.balanceAfter}',
      excludeSemantics: true,
      child: AppCard(
        compact: true,
        child: Row(
          children: [
            Container(
              width: AppSize.avatarMd,
              height: AppSize.avatarMd,
              decoration: BoxDecoration(color: toneBg, shape: BoxShape.circle),
              child: Icon(
                entry.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: tone,
                size: AppIconSize.md,
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(display.icon, size: AppIconSize.xs, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          display.label,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isShopExclusive) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const _ShopExclusiveTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _subtitle(entry),
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountLabel,
                    style: AppTypography.numericFinancialSmall.copyWith(color: tone, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Bal. ${entry.balanceAfter}',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small "at MerchantName" pill for a Shop-Exclusive (TU) Coin credit —
/// the one thing that distinguishes it from a Universal coin at a glance,
/// since [WalletLedgerSourceDisplay] already covers the earn/spend reason.
class _ShopExclusiveTag extends StatelessWidget {
  const _ShopExclusiveTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      child: Text('TU', style: AppTypography.badgeLabel.copyWith(color: AppColors.goldDark)),
    );
  }
}

String _subtitle(WalletLedgerEntry entry) {
  final time = entry.createdAt != null ? '${relativeTime(entry.createdAt!)} · ${_absoluteTime(entry.createdAt!)}' : '';
  if (entry.isShopExclusive && entry.merchantName != null) {
    return 'At ${entry.merchantName}${time.isEmpty ? '' : ' · $time'}';
  }
  return time;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "12 May, 05:30 PM" -- paired with [relativeTime] rather than replacing it
/// (same "16h ago · 12 May, 05:30 PM" shape the reference design uses), so
/// a glance gets the recency and a closer look gets the exact moment.
String _absoluteTime(DateTime dateTime) {
  final hour24 = dateTime.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '${dateTime.day} ${_months[dateTime.month - 1]}, $hour12:$minute $period';
}
