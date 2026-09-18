import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/load_more_indicator.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../purchases/presentation/load_more_threshold.dart';
import '../application/redemptions_list_controller.dart';
import 'redemption_tile.dart';

class RedemptionsListScreen extends ConsumerStatefulWidget {
  const RedemptionsListScreen({super.key});

  @override
  ConsumerState<RedemptionsListScreen> createState() => _RedemptionsListScreenState();
}

class _RedemptionsListScreenState extends ConsumerState<RedemptionsListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - kLoadMoreThreshold) {
      ref.read(redemptionsListControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redemptionsListControllerProvider);

    return AppScaffold(
      title: 'Redemptions',
      padded: false,
      body: state.when(
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(redemptionsListControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyState(
              icon: Icons.qr_code_2_rounded,
              title: 'No redemptions yet',
              message: 'Town Coin redemptions you make at participating merchants will show up here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(redemptionsListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: data.items.length + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index >= data.items.length) {
                  return const LoadMoreIndicator(label: 'Loading more redemptions');
                }

                final redemption = data.items[index];
                return RedemptionTile(redemption: redemption, onTap: () => context.push('/redemptions/${redemption.id}'));
              },
            ),
          );
        },
      ),
    );
  }
}
