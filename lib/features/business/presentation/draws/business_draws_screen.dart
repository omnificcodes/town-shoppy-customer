import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/load_more_indicator.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../lucky_draw/presentation/draw_tile.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/business_context.dart';
import '../../application/business_draws_controller.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';

/// Business mode's Lucky Draw results (BR-44): every completed draw of this
/// shop's association. Public information, so Owner and Staff both see it,
/// with the full details of the winners of the shop's own sponsored gifts
/// on the detail page.
class BusinessDrawsScreen extends ConsumerStatefulWidget {
  const BusinessDrawsScreen({super.key});

  @override
  ConsumerState<BusinessDrawsScreen> createState() => _BusinessDrawsScreenState();
}

class _BusinessDrawsScreenState extends ConsumerState<BusinessDrawsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessDrawsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessDrawsControllerProvider);
    final merchant = ref.watch(myMerchantProvider).value;
    final items = state.value?.items;
    final winners = items?.fold<int>(0, (sum, d) => sum + (d.winnerCount ?? 0));
    final prizes = items?.fold<int>(0, (sum, d) => sum + d.prizes.length);

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Lucky Draw',
            subtitle: merchant?.association?.name ?? "Your association's draws",
            leading: BusinessHeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root),
            ),
            child: BusinessStatStrip(
              isLoading: items == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Draws', value: '${items?.length ?? 0}', hint: 'COMPLETED'),
                BusinessStat(label: 'Winners', value: '${winners ?? 0}', hint: 'ACROSS THEM'),
                BusinessStat(label: 'Prizes', value: '${prizes ?? 0}', hint: 'GIVEN AWAY'),
              ],
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(count: 5),
              error: (error, _) => ErrorState(
                error: error is AppException ? error : const UnknownAppException(),
                onRetry: () => ref.read(businessDrawsControllerProvider.notifier).refresh(),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'No draws yet',
                    message: 'When your association runs a Lucky Draw, every prize, winner and sponsor shop appears here.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.businessInk,
                  onRefresh: () => ref.read(businessDrawsControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= data.items.length) return const LoadMoreIndicator();
                      final draw = data.items[index];
                      return DrawTile(draw: draw, onTap: () => context.push('${BusinessRoutes.draws}/${draw.id}'));
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
