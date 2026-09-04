import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/coupons_list_controller.dart';
import 'coupon_tile.dart';

const _tabs = <(String? status, String label)>[
  (null, 'All Coupons'),
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
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
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
      appBar: AppBar(
        title: const Text('Coupons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded),
            tooltip: 'My wins',
            onPressed: () => context.push('/lucky-draw/my-wins'),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: const [
              _TicketsBanner(),
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
            onRetry: () => ref.read(couponsListControllerProvider.notifier).refresh(),
          ),
          data: (data) {
            final headerWidgets = <Widget>[
              const _TicketsBanner(),
              const SizedBox(height: AppSpacing.lg),
              _FilterTabsRow(selected: data.statusFilter),
              const SizedBox(height: AppSpacing.md),
              if (data.items.isEmpty) _EmptyForFilter(status: data.statusFilter),
            ];

            return RefreshIndicator(
              onRefresh: () => ref.read(couponsListControllerProvider.notifier).refresh(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
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
                    return const Padding(padding: EdgeInsets.only(top: AppSpacing.sm), child: _ExploreMegaDrawsBanner());
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
      'active' => ('No active coupons', 'Coupons you can still use in an upcoming draw will show up here.'),
      'won' => ('No wins yet', 'Coupons that win a draw will show up here.'),
      'expired' => ('No expired coupons', "Coupons past their draw's window will show up here."),
      _ => ('No coupons yet', 'Make a purchase with a participating merchant to earn Lucky Draw coupons.'),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: EmptyState(icon: Icons.confirmation_number_outlined, title: title, message: message),
    );
  }
}

/// Decorative header -- no illustration asset exists for this (same stance
/// as the wallet screen's coin glyph), so the "gift + tickets" motif is
/// built from layered Material icons rather than adding image assets.
class _TicketsBanner extends StatelessWidget {
  const _TicketsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your tickets, your lucky chances!', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Use your active coupons and win exciting rewards.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.confirmation_number_rounded, color: AppColors.orange, size: 28),
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
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _FilterTab(
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

class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.orange : Colors.transparent, width: 2))),
        child: Text(
          count != null ? '$label ($count)' : label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _ExploreMegaDrawsBanner extends StatelessWidget {
  const _ExploreMegaDrawsBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => context.push('/lucky-draw'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.orange, AppColors.crimson]),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore Mega Draws',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
                    ),
                    Text(
                      'More draws, more rewards!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
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
