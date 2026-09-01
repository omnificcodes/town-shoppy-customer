import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
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
              // Static leading content (balance hero, redeem button, section
              // heading, and -- when there is no history yet -- the empty
              // state) followed by the paginated ledger itself. Built via
              // ListView.builder's index dispatch, same pattern as
              // DrawsListScreen's header-card-plus-paginated-list, so a long
              // transaction history isn't eagerly built off-screen the way a
              // plain ListView(children: [...]) would.
              final headerWidgets = <Widget>[
                const _BalanceHero(),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Redeem your coins',
                  icon: Icons.qr_code_2_rounded,
                  onPressed: () => context.push('/redeem'),
                ),
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
                itemCount: headerWidgets.length + data.items.length + (data.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < headerWidgets.length) return headerWidgets[index];

                  final itemIndex = index - headerWidgets.length;
                  if (itemIndex >= data.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
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
        color: AppColors.silverLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, color: AppColors.silverDark),
              const SizedBox(width: AppSpacing.xs),
              Text('Silver Town Coin balance', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.silverDark)),
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
          const SizedBox(height: AppSpacing.sm),
          switch (wallet) {
            AsyncData(:final value) => Text('${value.balance}', style: AppTypography.numericFinancialLarge),
            AsyncError() => Text('Unable to load', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error)),
            _ => const LoadingSkeleton(width: 140, height: 40),
          },
          if (wallet case AsyncData(:final value))
            Text(
              '≈ ₹${value.balanceInrEquivalent.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.silverDark),
            ),
        ],
      ),
    );
  }
}
