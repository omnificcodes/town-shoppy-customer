import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/business_prizes_controller.dart';
import '../../data/models/business_prize.dart';
import '../business_routes.dart';
import '../growth_status.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';

/// Prizes this business sponsors for the Lucky Draw. Owner only. Each one
/// needs the association's approval before a draw can use it.
class BusinessPrizesScreen extends ConsumerStatefulWidget {
  const BusinessPrizesScreen({super.key});

  @override
  ConsumerState<BusinessPrizesScreen> createState() => _BusinessPrizesScreenState();
}

class _BusinessPrizesScreenState extends ConsumerState<BusinessPrizesScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessPrizesControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(prizeListFiltersProvider);
    final state = ref.watch(businessPrizesControllerProvider);
    final totals = state.value?.totals;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-prize',
        backgroundColor: AppColors.businessInk,
        foregroundColor: AppColors.onBusinessInk,
        icon: const Icon(Icons.emoji_events_rounded),
        label: const Text('Sponsor a prize'),
        onPressed: () => context.push(BusinessRoutes.prizeNew),
      ),
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Sponsored prizes',
            subtitle: 'Put your brand on the Lucky Draw',
            leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root)),
            child: BusinessStatStrip(
              isLoading: totals == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Total prizes', value: '${totals?.prizes ?? 0}', hint: 'ALL TIME'),
                BusinessStat(label: 'Approved', value: '${totals?.approved ?? 0}', hint: 'READY FOR A DRAW'),
                BusinessStat(label: 'Pending', value: '${totals?.pending ?? 0}', hint: 'ASSOCIATION REVIEW'),
                BusinessStat(label: 'Withdrawn', value: '${totals?.rejected ?? 0}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(labelText: 'Search prizes', hintText: 'By name', prefixIcon: Icon(Icons.search_rounded)),
              textInputAction: TextInputAction.search,
              onSubmitted: ref.read(prizeListFiltersProvider.notifier).setSearch,
            ),
          ),
          SizedBox(
            height: AppSize.controlSm,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final (value, label) in PrizeListFilters.statusOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: value == filters.status,
                      selectedColor: AppColors.businessTintStrong,
                      labelStyle: textTheme.labelMedium?.copyWith(color: value == filters.status ? AppColors.businessInk : AppColors.textSecondary),
                      side: BorderSide(color: value == filters.status ? AppColors.businessInk : AppColors.border),
                      showCheckmark: false,
                      onSelected: (_) => ref.read(prizeListFiltersProvider.notifier).setStatus(value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(count: 3),
              error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load your prizes.', onRetry: () => ref.read(businessPrizesControllerProvider.notifier).refresh()),
              data: (data) {
                if (data.items.isEmpty) {
                  final filtered = filters.status != 'all' || filters.search.isNotEmpty;
                  return EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: filtered ? 'No prizes match these filters' : 'No prizes sponsored yet',
                    message: filtered ? 'Try a different name or status.' : 'Sponsor a prize to give your customers a reason to keep coming back.',
                    action: filtered ? null : AppButton(label: 'Sponsor a prize', icon: Icons.emoji_events_rounded, expand: false, onPressed: () => context.push(BusinessRoutes.prizeNew)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(businessPrizesControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl * 2),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i >= data.items.length) {
                        return const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Center(child: CircularProgressIndicator()));
                      }
                      final p = data.items[i];
                      return _PrizeRow(prize: p, onTap: () => context.push('${BusinessRoutes.prizes}/${p.id}'));
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

class _PrizeRow extends StatelessWidget {
  const _PrizeRow({required this.prize, required this.onTap});

  final BusinessPrize prize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = prize;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${p.name}, ${prizeStatusLabel(p.status)}',
      child: AppCard(
        onTap: onTap,
        compact: true,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: SizedBox(
                width: AppSize.avatarLg,
                height: AppSize.avatarLg,
                child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                    ? Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _PrizeIcon())
                    : const _PrizeIcon(),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      if (p.value != null) formatMoney(p.value!),
                      '${p.quantityRemaining} / ${p.quantityTotal} remaining',
                      if (p.createdAt != null) formatDate(p.createdAt!),
                    ].join(' · '),
                    style: AppTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: StatusBadge(label: prizeStatusLabel(p.status), tone: prizeStatusTone(p.status))),
          ],
        ),
      ),
    );
  }
}

class _PrizeIcon extends StatelessWidget {
  const _PrizeIcon();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppColors.goldLight, child: Icon(Icons.emoji_events_rounded, color: AppColors.goldDark));
  }
}
