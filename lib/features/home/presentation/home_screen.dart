import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../purchases/application/recent_purchases_provider.dart';
import '../../purchases/presentation/purchase_status.dart';
import '../../wallet/application/wallet_controller.dart';

/// The customer's landing screen — sections 20/21/30: personal greeting
/// first, then whatever the backend actually supports for this account
/// (wallet balance, recent purchases). No section here renders anything
/// the backend didn't return; there is no lucky-draw/rewards section
/// because that backend domain doesn't exist yet (see the final report's
/// backend-limitations list).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final account = authState is AuthAuthenticated ? authState.account : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Town Shoppy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(walletControllerProvider.notifier).refresh();
            ref.invalidate(recentPurchasesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Hi, ${account?.displayName ?? 'there'}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Welcome back to your Town Shoppy account.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              const _WalletCard(),
              const SizedBox(height: AppSpacing.lg),
              const _DiscoverMerchantsCard(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent purchases',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(onPressed: () => context.push('/purchases'), child: const Text('See all')),
                ],
              ),
              const _RecentPurchases(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Redemptions',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(onPressed: () => context.push('/redemptions'), child: const Text('See all')),
                ],
              ),
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
            ],
          ),
        ),
      ),
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
                      style: Theme.of(context).textTheme.headlineSmall,
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
