import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../merchants/presentation/merchant_card.dart';
import '../application/redeem_offers_controller.dart';

/// "Where can I spend my Town Coin" -- every merchant that currently
/// accepts Town Coin redemption, with its live discount rate, discoverable
/// WITHOUT already knowing a specific merchant (previously the only way in
/// was already being on that merchant's own detail page). Tapping a card
/// goes straight to that merchant, where the existing "Redeem Town Coin"
/// action already lives.
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
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Redeem Town Coin')),
      body: SafeArea(
        child: state.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const LoadingSkeletonCard(),
          ),
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
              onRefresh: () => ref.read(redeemOffersControllerProvider.notifier).refresh(),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: data.items.length + (data.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index >= data.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
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
    );
  }
}
