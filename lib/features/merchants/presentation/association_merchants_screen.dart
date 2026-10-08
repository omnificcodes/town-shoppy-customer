import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/load_more_indicator.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../purchases/presentation/load_more_threshold.dart';
import '../application/association_merchants_controller.dart';
import '../application/associations_provider.dart';
import '../data/models/association_ref.dart';
import 'merchant_card.dart';

/// Every shop in one merchant association, opened from a Home association
/// tile. The association itself comes from the already-loaded public
/// `GET /associations` list; the shops from `GET /merchants?association_id=`.
class AssociationMerchantsScreen extends ConsumerStatefulWidget {
  const AssociationMerchantsScreen({super.key, required this.associationId});

  final int associationId;

  @override
  ConsumerState<AssociationMerchantsScreen> createState() => _AssociationMerchantsScreenState();
}

class _AssociationMerchantsScreenState extends ConsumerState<AssociationMerchantsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - kLoadMoreThreshold) {
      ref.read(associationMerchantsProvider(widget.associationId).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = associationMerchantsProvider(widget.associationId);
    final state = ref.watch(provider);
    final association = ref.watch(associationsProvider).value?.where((a) => a.id == widget.associationId).firstOrNull;

    return AppScaffold(
      title: association?.name ?? 'Association',
      padded: false,
      body: state.when(
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(provider.notifier).refresh(),
        ),
        data: (data) {
          return RefreshIndicator(
            onRefresh: () => ref.read(provider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
              // Header, then the shops (or the empty card), then load-more.
              itemCount: 1 + (data.items.isEmpty ? 1 : data.items.length) + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
              itemBuilder: (context, index) {
                if (index == 0) return _AssociationHeader(association: association, shopCount: data.total);
                if (data.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xl),
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No shops here yet',
                      message: 'Shops in this association will appear here once they join Town Shoppy.',
                    ),
                  );
                }
                final itemIndex = index - 1;
                if (itemIndex >= data.items.length) return const LoadMoreIndicator(label: 'Loading more shops');

                final merchant = data.items[itemIndex];
                return MerchantCard(
                  key: ValueKey(merchant.id),
                  merchant: merchant,
                  onTap: () => context.push('/merchants/${merchant.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AssociationHeader extends StatelessWidget {
  const _AssociationHeader({required this.association, required this.shopCount});

  final AssociationRef? association;
  final int shopCount;

  @override
  Widget build(BuildContext context) {
    final town = association?.town?.name;
    final logoUrl = association?.logoUrl;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppGradients.warmWash,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Row(
        children: [
          Container(
            width: AppSize.avatarLg,
            height: AppSize.avatarLg,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.goldLight),
            ),
            child: logoUrl == null
                ? const Icon(Icons.groups_rounded, color: AppColors.orangeDeep)
                : Image.network(
                    logoUrl,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.groups_rounded, color: AppColors.orangeDeep),
                  ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (association != null)
                  Text(
                    association!.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                if (town != null) ...[const SizedBox(height: AppSpacing.xxs), Text(town, style: AppTypography.caption)],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  shopCount == 1 ? '1 SHOP' : '$shopCount SHOPS',
                  style: AppTypography.overline.copyWith(color: AppColors.goldDark, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
