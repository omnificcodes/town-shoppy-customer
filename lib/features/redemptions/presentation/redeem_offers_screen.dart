import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../merchants/presentation/merchant_card.dart';
import '../../purchases/presentation/load_more_threshold.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/redeem_offers_controller.dart';

/// "Where can I spend my Town Coin" -- every merchant that currently
/// accepts Town Coin redemption, with its live discount rate, discoverable
/// WITHOUT already knowing a specific merchant (previously the only way in
/// was already being on that merchant's own detail page). Tapping a card
/// goes straight to that merchant, where the existing "Redeem Town Coin"
/// action already lives. The balance header answers the question that
/// naturally comes first -- "how much do I have to spend" -- from the same
/// provider the Wallet tab uses.
class RedeemOffersScreen extends ConsumerStatefulWidget {
  const RedeemOffersScreen({super.key});

  @override
  ConsumerState<RedeemOffersScreen> createState() => _RedeemOffersScreenState();
}

class _RedeemOffersScreenState extends ConsumerState<RedeemOffersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - kLoadMoreThreshold) {
      ref.read(redeemOffersControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redeemOffersControllerProvider);

    return AppScaffold(
      title: 'Redeem Town Coin',
      padded: false,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, 0),
            child: _WalletBalanceHeader(),
          ),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(),
              error: (error, _) => ErrorState(
                error: error is AppException ? error : const UnknownAppException(),
                onRetry: () => ref.read(redeemOffersControllerProvider.notifier).refresh(),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No redemption offers yet',
                    message: 'No merchants currently accept Town Coin redemption. Check back soon.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      ref.read(redeemOffersControllerProvider.notifier).refresh(),
                      ref.read(walletControllerProvider.notifier).refresh(),
                    ]);
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= data.items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading more merchants')),
                        );
                      }

                      final merchant = data.items[index];
                      return MerchantCard(merchant: merchant, onTap: () => context.push('/merchants/${merchant.id}'));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The customer's spendable balance, from the same `walletControllerProvider`
/// the Wallet tab reads (so the two never disagree). Keeps the last-known
/// value visible during a refresh, per that controller's own contract.
class _WalletBalanceHeader extends ConsumerWidget {
  const _WalletBalanceHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      tinted: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: BoxDecoration(
              color: AppColors.orangeTintStrong,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(Icons.savings_rounded, color: AppColors.orange, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Town Coins to spend', style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                switch (wallet) {
                  AsyncData(:final value) => Semantics(
                      label: '${value.balance} coins, about ₹${value.balanceInrEquivalent.toStringAsFixed(2)}',
                      excludeSemantics: true,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: AppSpacing.sm,
                        children: [
                          Text('${value.balance}', style: AppTypography.numericFinancialMedium),
                          Text('≈ ₹${value.balanceInrEquivalent.toStringAsFixed(2)}', style: AppTypography.caption),
                        ],
                      ),
                    ),
                  AsyncError() => Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      children: [
                        Text('Balance unavailable', style: textTheme.bodySmall),
                        AppButton(
                          label: 'Retry',
                          variant: AppButtonVariant.text,
                          size: AppButtonSize.sm,
                          expand: false,
                          onPressed: () => ref.invalidate(walletControllerProvider),
                        ),
                      ],
                    ),
                  _ => const LoadingSkeleton(width: 120, height: AppIconSize.lg),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }
}
