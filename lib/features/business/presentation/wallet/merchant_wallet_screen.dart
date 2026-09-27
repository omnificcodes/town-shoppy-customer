import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../application/merchant_wallet_controller.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// The business's own coins. Blue is spendable at other Town Shoppy
/// merchants; Red is a running record. Gold is the merchant-wallet
/// identity (design-principles.md "Silver vs. Gold"), so the two balance
/// cards are the one place Business mode paints with it.
class MerchantWalletScreen extends ConsumerWidget {
  const MerchantWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(merchantWalletProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: BusinessPageHeader(
              title: 'Wallet',
              subtitle: 'Coins your business has earned from customer redemptions',
              leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.page),
            sliver: SliverList.list(
              children: [
                wallet.when(
                  loading: () => const Column(children: [LoadingSkeleton(height: 140, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg))), SizedBox(height: AppSpacing.smd), LoadingSkeleton(height: 110, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg)))]),
                  error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load your wallet.', onRetry: () => ref.invalidate(merchantWalletProvider)),
                  data: (w) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BalanceCard(
                        title: 'Blue Coin',
                        subtitle: 'Also in your customer wallet as Universal Town Coin',
                        coins: w.blueBalance,
                        inr: w.blueInr,
                        icon: Icons.toll_rounded,
                        colors: const [Color(0xFF1E3A8A), Color(0xFF3B5BA9)],
                      ),
                      const SizedBox(height: AppSpacing.smd),
                      _BalanceCard(
                        title: 'Red Coin',
                        subtitle: 'Recorded for a future feature — not spendable yet',
                        coins: w.redBalance,
                        inr: w.redInr,
                        icon: Icons.savings_rounded,
                        colors: const [AppColors.businessInk, AppColors.crimson],
                        muted: true,
                      ),
                      // Blue Coin is spent in Customer mode, not from here: the
                      // same coins sit in the owner's customer wallet as
                      // Universal Town Coin (BlueCoinMirrorService on the API).
                      if (w.blueBalance <= 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Blue Coin arrives when customers redeem Town Coin at your shop.', style: AppTypography.caption, textAlign: TextAlign.center),
                      ],
                      if (w.updatedAt != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Updated ${formatDateTime(w.updatedAt!)}', style: AppTypography.caption, textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Text('How it works', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.smd),
                const _HowItWorks(icon: Icons.storefront_rounded, title: 'Earn on every redemption', body: 'When a customer spends Town Coin at your counter, your business receives the full coin value as Blue Coin — and the same again as Red Coin.'),
                const SizedBox(height: AppSpacing.sm),
                const _HowItWorks(icon: Icons.shopping_bag_rounded, title: 'Spend it as a customer', body: 'Blue Coin also appears in your customer wallet as Universal Town Coin. Switch to Customer mode to pay with it at any shop; what you spend comes off your Blue Coin here too.'),
                const SizedBox(height: AppSpacing.sm),
                const _HowItWorks(icon: Icons.workspace_premium_rounded, title: 'Subscription bonus', body: 'Every ₹500 of plan spend in a month adds bonus Blue and Red Coin to your wallet.'),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.title, required this.subtitle, required this.coins, required this.inr, required this.icon, required this.colors, this.muted = false});

  final String title;
  final String subtitle;
  final int coins;
  final double inr;
  final IconData icon;
  final List<Color> colors;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$title: $coins coins, about ${formatMoney(inr)}. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppTypography.overline.copyWith(color: AppColors.goldLight)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('$coins', style: AppTypography.numericFinancialLarge.copyWith(color: AppColors.surface)),
                  Text('coins · ≈ ${formatMoney(inr)}', style: textTheme.bodyMedium?.copyWith(color: AppColors.surface.withValues(alpha: 0.85))),
                  const SizedBox(height: AppSpacing.sm),
                  Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.surface.withValues(alpha: 0.75))),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: AppSize.avatarLg,
              height: AppSize.avatarLg,
              decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: muted ? 0.12 : 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.goldLight, size: AppIconSize.xl),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: const BoxDecoration(color: AppColors.goldLight, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.goldDark, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(body, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
