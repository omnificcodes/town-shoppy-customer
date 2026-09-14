import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../coupons/application/coupons_list_controller.dart';
import '../../../wallet/application/wallet_controller.dart';

/// The three at-a-glance numbers under the greeting.
///
/// Stitch's first tile is "Total Saved", which nothing in the backend
/// records. Rather than show an invented figure, that slot shows what the
/// customer's coins are worth in rupees -- real, from the same wallet
/// response -- and leads to where they can be spent.
class HomeStatsRow extends ConsumerWidget {
  const HomeStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final coupons = ref.watch(couponCountsProvider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.savings_rounded,
              tint: AppColors.orange,
              label: 'Coins\nworth',
              value: switch (wallet) {
                AsyncData(:final value) => '₹${_rupees(value.balanceInrEquivalent)}',
                AsyncError() => '—',
                _ => null,
              },
              actionLabel: 'Redeem',
              onTap: () => context.push('/redeem'),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: _StatTile(
              icon: Icons.toll_rounded,
              tint: AppColors.gold,
              label: 'Town\nCoins',
              value: switch (wallet) {
                AsyncData(:final value) => '${value.balance}',
                AsyncError() => '—',
                _ => null,
              },
              actionLabel: 'History',
              onTap: () => context.push('/wallet'),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: _StatTile(
              icon: Icons.confirmation_number_rounded,
              tint: AppColors.decorativeAccents[2],
              label: 'Coupons',
              value: switch (coupons) {
                AsyncData(:final value) => '${value.active}',
                AsyncError() => '—',
                _ => null,
              },
              actionLabel: 'Coupons',
              onTap: () => context.go('/coupons'),
            ),
          ),
        ],
      ),
    );
  }

  static String _rupees(double amount) =>
      amount.truncateToDouble() == amount ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;

  /// Null while loading.
  final String? value;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shownValue = value;
    final radius = BorderRadius.circular(AppSpacing.radiusControl);

    return Semantics(
      button: true,
      label: '${label.replaceAll('\n', ' ')}: ${shownValue ?? 'loading'}. $actionLabel',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.smd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppIconSize.xl,
                        height: AppIconSize.xl,
                        decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Icon(icon, size: AppIconSize.sm, color: tint),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Scaled rather than wrapped: a narrow tile would
                      // otherwise break "Coupons" mid-word.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(label, maxLines: 2, style: AppTypography.caption),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (shownValue == null)
                    const LoadingSkeleton(width: 48, height: 18)
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        shownValue,
                        maxLines: 1,
                        style: AppTypography.numericFinancialSmall.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '$actionLabel ›',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.orangeDeep, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
