import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/nav_link_card.dart';
import '../application/coupons_list_controller.dart';
import 'coupon_tile.dart';

const _tabs = <(String? status, String label)>[
  (null, 'All'),
  ('active', 'Active'),
  ('won', 'Won'),
  ('expired', 'Expired'),
];

class CouponsListScreen extends ConsumerStatefulWidget {
  const CouponsListScreen({super.key});

  @override
  ConsumerState<CouponsListScreen> createState() => _CouponsListScreenState();
}

class _CouponsListScreenState extends ConsumerState<CouponsListScreen> {
  static const _loadMoreThreshold = 200.0;

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

    return AppScaffold(
      title: 'Lucky Draw coupons',
      padded: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.emoji_events_rounded),
          tooltip: 'My wins',
          onPressed: () => context.push('/lucky-draw/my-wins'),
        ),
      ],
      body: state.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: const [
            _IntroBanner(),
            SizedBox(height: AppSpacing.md),
            LoadingSkeletonCard(),
            SizedBox(height: AppSpacing.sm),
            LoadingSkeletonCard(),
            SizedBox(height: AppSpacing.sm),
            LoadingSkeletonCard(),
          ],
        ),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(couponsListControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          final headerWidgets = <Widget>[
            const _IntroBanner(),
            const SizedBox(height: AppSpacing.md),
            _FilterTabsRow(selected: data.statusFilter),
            const SizedBox(height: AppSpacing.smd),
            if (data.items.isEmpty) _EmptyForFilter(status: data.statusFilter),
          ];

          return RefreshIndicator(
            onRefresh: () => ref.read(couponsListControllerProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: headerWidgets.length + data.items.length + (data.items.isEmpty ? 0 : 1),
              itemBuilder: (context, index) {
                if (index < headerWidgets.length) return headerWidgets[index];

                final itemIndex = index - headerWidgets.length;
                if (itemIndex >= data.items.length) {
                  if (data.hasMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: NavLinkCard(
                      icon: Icons.card_giftcard_rounded,
                      title: 'See the draws',
                      subtitle: 'Prizes, dates and past winners for every draw',
                      onTap: () => context.push('/lucky-draw'),
                    ),
                  );
                }

                final coupon = data.items[itemIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CouponTile(coupon: coupon, onTap: () => context.push('/coupons/${coupon.id}')),
                );
              },
            ),
          );
        },
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
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: EmptyState(icon: Icons.confirmation_number_outlined, title: title, message: message),
    );
  }
}

/// One factual banner explaining what a coupon is — replaces the previous
/// pair of promotional banners ("Your tickets, your lucky chances!" +
/// "Explore Mega Draws") that said the same thing twice in ad copy.
class _IntroBanner extends StatelessWidget {
  const _IntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.orangeTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Row(
        children: [
          Container(
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: BoxDecoration(color: AppColors.orangeTintStrong, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            child: const Icon(Icons.confirmation_number_rounded, color: AppColors.orange, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Every purchase earns a coupon', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Each coupon is an entry in the weekly, monthly and year-end mega draws.',
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

class _FilterTabsRow extends ConsumerWidget {
  const _FilterTabsRow({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(couponCountsProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (status, label) in _tabs)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _FilterChip(
                label: label,
                count: counts.whenOrNull(
                  data: (value) => switch (status) {
                    'active' => value.active,
                    'won' => value.won,
                    'expired' => value.expired,
                    _ => value.all,
                  },
                ),
                selected: selected == status,
                onTap: () => ref.read(couponsListControllerProvider.notifier).filterByStatus(status),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filter as a pill chip (48dp tall, full ripple) rather than an underlined
/// text tab whose hit area was the text height only.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = count != null ? '$label ($count)' : label;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Show $text coupons',
      child: Material(
        color: selected ? AppColors.orange : AppColors.surfaceMuted,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.orange : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSize.controlSm),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            alignment: Alignment.center,
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? AppColors.onOrange : AppColors.textPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
