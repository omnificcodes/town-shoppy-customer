import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/my_vouchers_controller.dart';
import 'voucher_tile.dart';

/// "My winnings" -- every voucher this customer has ever won, across every
/// draw. Reached from the Lucky Draw screen's app-bar action.
class MyVouchersScreen extends ConsumerStatefulWidget {
  const MyVouchersScreen({super.key});

  @override
  ConsumerState<MyVouchersScreen> createState() => _MyVouchersScreenState();
}

class _MyVouchersScreenState extends ConsumerState<MyVouchersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      ref.read(myVouchersControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myVouchersControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My winnings')),
      body: SafeArea(
        child: state.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const LoadingSkeletonCard(),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.read(myVouchersControllerProvider.notifier).refresh(),
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'No wins yet',
                message: "Keep your eligible coupons active -- your wins will show up here the moment a draw picks you.",
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.read(myVouchersControllerProvider.notifier).refresh(),
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

                  final voucher = data.items[index];
                  return VoucherTile(voucher: voucher, onTap: () => context.push('/lucky-draw/vouchers/${voucher.id}'));
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
