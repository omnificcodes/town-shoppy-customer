import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
    final tone = entry.isCredit ? AppColors.success : AppColors.silverDark;
    final toneBg = entry.isCredit ? AppColors.successBg : AppColors.silverLight;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: toneBg, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: Icon(
              entry.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: tone,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(display.icon, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(display.label, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.createdAt != null ? '${relativeTime(entry.createdAt!)} · ${_absoluteTime(entry.createdAt!)}' : '',
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.isCredit ? '+' : '−'}${entry.amount}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tone, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text('Balance ${entry.balanceAfter}', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
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
