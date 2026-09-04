import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/notification_badge.dart';
import '../../notifications/application/unread_count_provider.dart';
import '../application/wallet_controller.dart';
import '../application/wallet_transactions_controller.dart';
import 'wallet_ledger_tile.dart';

/// The full Town Coin wallet -- a large, trustworthy balance up top (same
/// silver visual language as Home's own wallet card, just bigger since
/// this screen's whole job is showing it) and the complete earn/spend
/// timeline below it. The backend `balance_cache` is always a live read
/// (never client-cached), so this screen is the authoritative place to see
/// exactly what the server currently thinks the balance is.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      ref.read(walletTransactionsControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(walletTransactionsControllerProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: NotificationBadge(count: unreadCount, child: const Icon(Icons.notifications_outlined)),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(walletControllerProvider.notifier).refresh();
            await ref.read(walletTransactionsControllerProvider.notifier).refresh();
          },
          child: transactions.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                _BalanceHero(),
                SizedBox(height: AppSpacing.lg),
                LoadingSkeletonCard(),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeletonCard(),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeletonCard(),
              ],
            ),
            error: (error, _) => ErrorState(
              error: error is AppException ? error : const UnknownAppException(),
              onRetry: () => ref.read(walletTransactionsControllerProvider.notifier).refresh(),
            ),
            data: (data) {
              // Static leading content (balance hero, redeem CTA, quick
              // actions, promo banner, section heading, and -- when there is
              // no history yet -- the empty state) followed by the paginated
              // ledger itself. Built via ListView.builder's index dispatch,
              // same pattern as DrawsListScreen's header-card-plus-paginated-
              // list, so a long transaction history isn't eagerly built
              // off-screen the way a plain ListView(children: [...]) would.
              final headerWidgets = <Widget>[
                const _BalanceHero(),
                const SizedBox(height: AppSpacing.md),
                const _RedeemCoinsCta(),
                const SizedBox(height: AppSpacing.lg),
                const _QuickActionsRow(),
                const SizedBox(height: AppSpacing.lg),
                Text('Transaction history', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (data.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No activity yet',
                      message: 'Coins you earn from purchases, and coins you spend on redemptions, will show up here.',
                    ),
                  ),
              ];

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: headerWidgets.length + data.items.length + (data.hasMore ? 1 : 0) + 1,
                itemBuilder: (context, index) {
                  if (index < headerWidgets.length) return headerWidgets[index];

                  final itemIndex = index - headerWidgets.length;
                  if (itemIndex >= data.items.length) {
                    // The very last slot: a trailing loading spinner while
                    // more pages are still coming, or -- once hasMore is
                    // false -- the "earn more" nudge, so it reads as the
                    // natural end of the timeline rather than a random
                    // mid-list interruption.
                    if (data.hasMore && itemIndex == data.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: _EarnMoreBanner(),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: WalletLedgerTile(entry: data.items[itemIndex]),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BalanceHero extends ConsumerWidget {
  const _BalanceHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final isRefreshing = ref.watch(walletRefreshingProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.orange.withValues(alpha: 0.14), AppColors.orange.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Stack(
        children: [
          Positioned(right: -8, top: 4, child: _CoinStackGlyph()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(Icons.savings_rounded, color: AppColors.orange, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Silver Town Coin balance', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  if (isRefreshing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.silverDark),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              switch (wallet) {
                AsyncData(:final value) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${value.balance}', style: AppTypography.numericFinancialLarge),
                      const SizedBox(width: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('Coins', style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ],
                  ),
                AsyncError() => Text('Unable to load', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error)),
                _ => const LoadingSkeleton(width: 140, height: 40),
              },
              if (wallet case AsyncData(:final value))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '≈ ₹${value.balanceInrEquivalent.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A decorative stacked-coin motif -- no illustration asset exists for this
/// (see design-principles.md's zero-extra-asset stance), so this is built
/// entirely from layered circles + the same "T" token mark used on the
/// wallet's own icon elsewhere, in the silver tones already reserved for
/// Town Coin specifically (never the brand orange, so the coin itself still
/// reads as "silver currency" even though the card behind it is warm).
class _CoinStackGlyph extends StatelessWidget {
  const _CoinStackGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 16, child: _Coin(size: 52, color: AppColors.silver)),
          const Positioned(top: 6, child: _Coin(size: 52, color: AppColors.silverDark)),
          const Positioned(right: 4, top: 0, child: Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.orange)),
        ],
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        'T',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4),
      ),
    );
  }
}

class _RedeemCoinsCta extends StatelessWidget {
  const _RedeemCoinsCta();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => context.push('/redeem'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.orange, AppColors.crimson]),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Redeem your coins',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.description_outlined,
            iconColor: AppColors.orange,
            label: 'How it works',
            onTap: () => _showHowItWorks(context),
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.history_rounded,
            iconColor: AppColors.success,
            label: 'Redemption\nHistory',
            onTap: () => context.push('/redemptions'),
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.info,
            label: 'Terms &\nConditions',
            onTap: () => _showComingSoon(context, 'Terms & Conditions'),
          ),
        ),
        Expanded(
          child: _QuickAction(
            icon: Icons.support_agent_rounded,
            iconColor: AppColors.crimson,
            label: 'Help &\nSupport',
            onTap: () => _showComingSoon(context, 'Help & Support'),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How Silver Town Coin works', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.md),
              const _HowItWorksStep(
                number: '1',
                title: 'Earn coins on purchases',
                description: 'Shop at a participating merchant and they record your purchase — coins land in your wallet.',
              ),
              const _HowItWorksStep(
                number: '2',
                title: 'Watch your balance grow',
                description: 'Every coin you earn is visible here in real time, with a full history of how you got it.',
              ),
              const _HowItWorksStep(
                number: '3',
                title: 'Redeem for a discount',
                description: 'Show your redemption code at any Town Coin-accepting merchant to knock coins off your bill.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({required this.number, required this.title, required this.description});

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.iconColor, required this.label, required this.onTap});

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label.replaceAll('\n', ' '),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarnMoreBanner extends StatelessWidget {
  const _EarnMoreBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => context.push('/merchants'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                child: const Icon(Icons.card_giftcard_rounded, color: AppColors.onYellow),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earn more Town Coins', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Shop local, earn coins and unlock exciting rewards!',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.orange),
            ],
          ),
        ),
      ),
    );
  }
}
