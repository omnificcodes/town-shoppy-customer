import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
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

/// The customer's landing screen. Section order follows the reference
/// layout this was redesigned from: header, greeting, wallet, discovery
/// CTA, categories, featured businesses, trending offers, then the
/// existing recent-purchases/coupons/redemptions sections unchanged.
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
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
                  children: [
                    _GreetingRow(name: account?.displayName),
                    const SizedBox(height: AppSpacing.lg),
                    const _WalletCard(),
                    const SizedBox(height: AppSpacing.lg),
                    const _DiscoverMerchantsCard(),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeader(title: 'Categories', onSeeAll: null),
                    const SizedBox(height: AppSpacing.sm),
                    const CategorySlider(),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(title: 'Featured businesses', onSeeAll: () => context.push('/merchants')),
                    const SizedBox(height: AppSpacing.sm),
                    const FeaturedBusinessesSection(),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeader(title: 'Trending offers near you', onSeeAll: null),
                    const SizedBox(height: AppSpacing.sm),
                    const TrendingOffersSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(title: 'Recent purchases', onSeeAll: () => context.push('/purchases')),
                    const SizedBox(height: AppSpacing.sm),
                    const _RecentPurchases(),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(title: 'Coupons', onSeeAll: () => context.push('/coupons')),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      onTap: () => context.push('/coupons'),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number_outlined, color: AppColors.orange),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(child: Text('View your Lucky Draw coupons')),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(title: 'Redemptions', onSeeAll: () => context.push('/redemptions')),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      onTap: () => context.push('/redemptions'),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code_2_rounded, color: AppColors.silverDark),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(child: Text('View your Town Coin redemption history')),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      onTap: () => context.push('/redeem'),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: AppColors.orange),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(child: Text('See where you can redeem Town Coin')),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.orange,
          child: Text(
            _initials(name),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi, ${name ?? 'there'} 👋', style: Theme.of(context).textTheme.headlineMedium),
              Text('Welcome back to your Town Shoppy account.', style: Theme.of(context).textTheme.bodyMedium),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
        ),
        if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

/// The Home entry point into merchant discovery (phase brief section 9) —
/// deliberately the most visually distinct card on Home, since discovery is
/// meant to be the strongest part of the customer app, not a buried link.
class _DiscoverMerchantsCard extends StatelessWidget {
  const _DiscoverMerchantsCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => context.push('/merchants'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.orange, AppColors.crimson],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: AppColors.onCrimson, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover merchants',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.onCrimson),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Find participating businesses near you',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onCrimson.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.onCrimson),
            ],
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
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.silverLight, shape: BoxShape.circle),
            child: const Icon(Icons.savings_rounded, color: AppColors.silverDark),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Silver balance', style: Theme.of(context).textTheme.titleSmall),
                    if (isRefreshing) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.silverDark),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                switch (wallet) {
                  AsyncData(:final value) => Text(
                      '${value.balance} coins',
                      style: AppTypography.numericFinancialMedium,
                    ),
                  AsyncError() => Text('Unable to load', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
                  _ => const LoadingSkeleton(width: 100, height: 22),
                },
                if (wallet case AsyncData(:final value))
                  Text(
                    '≈ ₹${value.balanceInrEquivalent.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
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
      error: (error, _) => ErrorState(
        error: error is AppException ? error : const UnknownAppException(),
        onRetry: () => ref.invalidate(recentPurchasesProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return AppCard(
            child: Text(
              'No purchases recorded yet. Recent purchases will appear here once you shop with a participating merchant.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }

        return Column(
          children: [
            for (final purchase in items) ...[
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(purchase.merchantName, style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            '₹${purchase.billAmount.toStringAsFixed(2)} · ${purchase.createdAt != null ? relativeTime(purchase.createdAt!) : ''}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (purchase.coinsAwarded > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Text('+${purchase.coinsAwarded} coins', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    StatusBadge(label: purchase.status, tone: purchaseStatusTone(purchase.status)),
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
