import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/nav_link_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../merchants/application/featured_merchants_provider.dart';
import '../../offers/application/trending_offers_provider.dart';
import '../../purchases/application/recent_purchases_provider.dart';
import '../../purchases/presentation/purchase_status.dart';
import '../../wallet/application/wallet_controller.dart';
import 'widgets/category_slider.dart';
import 'widgets/featured_businesses_section.dart';
import 'widgets/home_drawer.dart';
import 'widgets/home_header.dart';
import 'widgets/trending_offers_section.dart';

/// The customer's landing screen. Hierarchy, top to bottom: who you are and
/// what you have (greeting + wallet), the one primary action (discover
/// merchants), then discovery content (categories, featured, offers), then
/// your own recent activity, and finally a single grouped "More" card for
/// the secondary destinations — so the screen has a clear first fold instead
/// of twelve equally-weighted sections.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final account = authState is AuthAuthenticated ? authState.account : null;

    return Scaffold(
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(walletControllerProvider.notifier).refresh();
                  ref.invalidate(recentPurchasesProvider);
                  ref.invalidate(featuredMerchantsProvider);
                  ref.invalidate(trendingOffersProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl),
                  children: [
                    _GreetingRow(name: account?.displayName),
                    const SizedBox(height: AppSpacing.section),
                    const _WalletCard(),
                    const SizedBox(height: AppSpacing.md),
                    const _DiscoverMerchantsCard(),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Browse by category'),
                    const SizedBox(height: AppSpacing.smd),
                    const CategorySlider(),
                    // Both carousels own their section header, so a section
                    // with nothing to show (no featured merchants yet, no
                    // location for nearby offers) disappears entirely
                    // rather than leaving an orphaned heading.
                    const FeaturedBusinessesSection(),
                    const TrendingOffersSection(),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'Recent purchases',
                      actionLabel: 'See all',
                      onAction: () => context.push('/purchases'),
                    ),
                    const SizedBox(height: AppSpacing.smd),
                    const _RecentPurchases(),
                    const SizedBox(height: AppSpacing.section),
                    const SectionHeader(title: 'More'),
                    const SizedBox(height: AppSpacing.smd),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          NavLinkRow(
                            icon: Icons.confirmation_number_rounded,
                            title: 'Lucky Draw coupons',
                            subtitle: 'Your entries for the weekly, monthly and mega draws',
                            onTap: () => context.push('/coupons'),
                          ),
                          const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                          NavLinkRow(
                            icon: Icons.qr_code_2_rounded,
                            iconColor: AppColors.goldDark,
                            title: 'Redemption history',
                            subtitle: 'Every time you spent Town Coin',
                            onTap: () => context.push('/redemptions'),
                          ),
                          const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                          NavLinkRow(
                            icon: Icons.storefront_rounded,
                            title: 'Where to redeem',
                            subtitle: 'Merchants that accept Town Coin',
                            onTap: () => context.push('/redeem'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppSize.avatarLg,
          height: AppSize.avatarLg,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.orangeTintStrong, shape: BoxShape.circle),
          child: Text(
            _initials(name),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.orange),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${name ?? 'there'}',
                style: Theme.of(context).textTheme.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text('Welcome back to Town Shoppy.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

/// The Home entry point into merchant discovery (phase brief section 9) —
/// deliberately the one saturated card on Home, since discovery is the
/// customer app's primary action. Crimson, not a gradient: white text is
/// only AA-readable on crimson (see `AppColors.onCrimson`), and the design
/// doc reserves gradients/full-bleed accent for exactly one CTA moment.
class _DiscoverMerchantsCard extends StatelessWidget {
  const _DiscoverMerchantsCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Discover merchants, find participating businesses near you',
      child: Material(
        color: AppColors.crimson,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: () => context.push('/merchants'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: AppSize.avatarMd,
                  height: AppSize.avatarMd,
                  decoration: BoxDecoration(
                    color: AppColors.onCrimson.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.onCrimson, size: AppIconSize.lg),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover merchants',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.onCrimson),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Find participating businesses near you',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.onCrimson.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.onCrimson, size: AppIconSize.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final isRefreshing = ref.watch(walletRefreshingProvider);

    return AppCard(
      onTap: () => context.push('/wallet'),
      child: Row(
        children: [
          Container(
            width: AppSize.avatarLg - AppSpacing.sm,
            height: AppSize.avatarLg - AppSpacing.sm,
            decoration: const BoxDecoration(color: AppColors.goldLight, shape: BoxShape.circle),
            child: const Icon(Icons.savings_rounded, color: AppColors.goldDark, size: AppIconSize.lg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Town Coins', style: Theme.of(context).textTheme.bodySmall),
                    if (isRefreshing) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const SizedBox(
                        width: AppIconSize.xs,
                        height: AppIconSize.xs,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldDark),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                switch (wallet) {
                  AsyncData(:final value) => Text('${value.balance} coins', style: AppTypography.numericFinancialMedium),
                  AsyncError() => Text(
                      'Unable to load balance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  _ => const LoadingSkeleton(width: 100, height: 22),
                },
                if (wallet case AsyncData(:final value))
                  Text('≈ ₹${value.balanceInrEquivalent.toStringAsFixed(2)}', style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: AppIconSize.lg),
        ],
      ),
    );
  }
}

class _RecentPurchases extends ConsumerWidget {
  const _RecentPurchases();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(recentPurchasesProvider);

    return purchases.when(
      loading: () => const Column(
        children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()],
      ),
      error: (error, _) => AppCard(
        child: ErrorState(
          compact: true,
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(recentPurchasesProvider),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No purchases yet',
              message: 'Shop with a participating merchant and your purchases will show up here.',
            ),
          );
        }

        return Column(
          children: [
            for (final purchase in items) ...[
              AppCard(
                compact: true,
                onTap: () => context.push('/purchases/${purchase.id}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            purchase.merchantName,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '₹${purchase.billAmount.toStringAsFixed(2)}'
                            '${purchase.createdAt != null ? ' · ${relativeTime(purchase.createdAt!)}' : ''}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(label: purchaseStatusLabel(purchase.status), tone: purchaseStatusTone(purchase.status)),
                        if (purchase.coinsAwarded > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '+${purchase.coinsAwarded} coins',
                            style: AppTypography.numericFinancialInline.copyWith(color: AppColors.success),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}
