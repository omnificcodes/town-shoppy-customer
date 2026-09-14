import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/coupons_list_controller.dart';
import 'coupon_tile.dart';

const _tabs = <(String? status, String label)>[
  (null, 'All'),
  ('active', 'Active'),
  ('won', 'Won'),
  ('expired', 'Expired'),
];

/// The Coupons tab, following the Google Stitch redesign: a title with a
/// shortcut to the customer's wins, a banner explaining the draws, status
/// pills with counts, then every coupon as a ticket.
///
/// Stitch's "Next draw in 2 days, 14 hrs" is replaced by the number of
/// coupons entered in upcoming draws: customers only ever receive completed
/// draws, so there is no scheduled time to count down to.
class CouponsListScreen extends ConsumerStatefulWidget {
  const CouponsListScreen({super.key});

  @override
  ConsumerState<CouponsListScreen> createState() => _CouponsListScreenState();
}

class _CouponsListScreenState extends ConsumerState<CouponsListScreen> {
  static const _loadMoreThreshold = 300.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(couponsListControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(couponsListControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(couponCountsProvider);
            await ref.read(couponsListControllerProvider.notifier).refresh();
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.smd),
                sliver: SliverList.list(
                  children: [
                    const _Header(),
                    const SizedBox(height: AppSpacing.md),
                    const _DrawsBanner(),
                    const SizedBox(height: AppSpacing.md),
                    _FilterTabsRow(selected: state.value?.statusFilter),
                  ],
                ),
              ),
              ...state.when(
                loading: () => [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                    sliver: SliverList.separated(
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
                      itemBuilder: (_, _) => LoadingSkeleton(
                        height: 120,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                    ),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(
                      error: error is AppException ? error : const UnknownAppException(),
                      onRetry: () => ref.read(couponsListControllerProvider.notifier).refresh(),
                    ),
                  ),
                ],
                data: (data) {
                  if (data.items.isEmpty) {
                    return [SliverToBoxAdapter(child: _EmptyForFilter(status: data.statusFilter))];
                  }

                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl * 2),
                      sliver: SliverList.separated(
                        itemCount: data.items.length + (data.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
                        itemBuilder: (context, index) {
                          if (index >= data.items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                              child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading more coupons')),
                            );
                          }

                          final coupon = data.items[index];
                          return CouponTile(coupon: coupon, onTap: () => context.push('/coupons/${coupon.id}'));
                        },
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasWins = (ref.watch(couponCountsProvider).value?.won ?? 0) > 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('Lucky Draw coupons', style: AppTypography.greeting)),
              const SizedBox(height: AppSpacing.xxs),
              Text('Shop, collect coupons and win prizes', style: AppTypography.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Semantics(
          button: true,
          label: hasWins ? 'My wins, you have prizes' : 'My wins',
          excludeSemantics: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: AppColors.goldLight,
                shape: CircleBorder(side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4))),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/lucky-draw/my-wins'),
                  child: const SizedBox.square(
                    dimension: AppSpacing.touchTarget,
                    child: Icon(Icons.emoji_events_rounded, color: AppColors.orangeDeep, size: AppIconSize.lg),
                  ),
                ),
              ),
              if (hasWins)
                Positioned(
                  top: AppSpacing.xxs,
                  right: AppSpacing.xxs,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What a coupon is, how many of the customer's coupons are waiting on a
/// draw, and the way to the draws themselves.
class _DrawsBanner extends ConsumerWidget {
  const _DrawsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(couponCountsProvider).value?.active;

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.warmWash,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSize.controlLg,
                  height: AppSize.controlLg,
                  decoration: BoxDecoration(
                    gradient: AppGradients.promoHero,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                  child: const Icon(Icons.confirmation_number_rounded, color: AppColors.onCrimson, size: AppIconSize.lg),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Every purchase earns a coupon',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.goldLight,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                          child: Text('Weekly • Monthly • Mega', style: AppTypography.badgeLabel.copyWith(color: AppColors.goldDark)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Each coupon is an entry in the weekly, monthly and year-end mega draws.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.orangeBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: active == null
                      ? Text('Your coupons enter every upcoming draw', style: AppTypography.caption)
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: active == 1 ? '1 coupon' : '$active coupons',
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(text: ' in upcoming draws'),
                            ],
                          ),
                          style: AppTypography.caption,
                        ),
                ),
                TextButton(
                  onPressed: () => context.push('/lucky-draw'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.orangeDeep),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Draws & prizes'),
                      Icon(Icons.chevron_right_rounded, size: AppIconSize.sm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabsRow extends ConsumerWidget {
  const _FilterTabsRow({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(couponCountsProvider).value;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (status, label) in _tabs)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _FilterPill(
                status: status,
                label: label,
                count: counts == null
                    ? null
                    : switch (status) {
                        'active' => counts.active,
                        'won' => counts.won,
                        'expired' => counts.expired,
                        _ => counts.all,
                      },
                selected: selected == status,
                onTap: () => ref.read(couponsListControllerProvider.notifier).filterByStatus(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.status,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String? status;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWon = status == 'won';
    final background = selected ? AppColors.orangeDeep : AppColors.surface;
    final foreground = selected ? AppColors.onCrimson : (isWon ? AppColors.goldDark : AppColors.textPrimary);
    final borderColor = selected ? AppColors.orangeDeep : (isWon ? AppColors.gold.withValues(alpha: 0.6) : AppColors.border);
    final shownCount = count;

    return Semantics(
      button: true,
      selected: selected,
      label: shownCount == null ? 'Show $label coupons' : 'Show $label coupons, $shownCount',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSize.controlSm),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
                if (shownCount != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _CountBubble(count: shownCount, selected: selected, won: isWon),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count, required this.selected, required this.won});

  final int count;
  final bool selected;
  final bool won;

  @override
  Widget build(BuildContext context) {
    if (!selected && !won) {
      return Text('($count)', style: AppTypography.caption);
    }

    final background = selected ? AppColors.onCrimson.withValues(alpha: 0.22) : AppColors.goldLight;
    final foreground = selected ? AppColors.onCrimson : AppColors.goldDark;

    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 2, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count', style: AppTypography.badgeLabel.copyWith(color: foreground, fontWeight: FontWeight.w800)),
            if (won) ...[
              const SizedBox(width: AppSpacing.xxs),
              Icon(Icons.emoji_events_rounded, size: AppIconSize.xs, color: selected ? AppColors.onCrimson : AppColors.gold),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyForFilter extends StatelessWidget {
  const _EmptyForFilter({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (status) {
      'active' => ('No active coupons', 'Coupons entered in an upcoming draw will show up here.'),
      'won' => ('No wins yet', 'Coupons that win a draw will show up here.'),
      'expired' => ('No expired coupons', "Coupons past their draw's window will show up here."),
      _ => ('No coupons yet', 'Shop with a participating merchant to earn Lucky Draw coupons.'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl),
      child: EmptyState(icon: Icons.confirmation_number_outlined, title: title, message: message),
    );
  }
}
