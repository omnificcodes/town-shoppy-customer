import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/business_context.dart';
import '../../application/business_offers_controller.dart';
import '../../data/models/business_offer.dart';
import '../business_routes.dart';
import '../growth_status.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';
import 'offer_actions.dart';

/// The Offers tab: every promotion this business runs, as image cards.
/// Owners create, publish, withdraw and end from here; staff read.
class BusinessOffersScreen extends ConsumerStatefulWidget {
  const BusinessOffersScreen({super.key});

  @override
  ConsumerState<BusinessOffersScreen> createState() => _BusinessOffersScreenState();
}

class _BusinessOffersScreenState extends ConsumerState<BusinessOffersScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessOffersControllerProvider.notifier).loadMore();
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
    final filters = ref.watch(offerListFiltersProvider);
    final state = ref.watch(businessOffersControllerProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final counts = state.value?.counts;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: isOwner
          ? Padding(
              // Sits above the shell's docked Counter button.
              padding: const EdgeInsets.only(bottom: AppSize.fab),
              child: FloatingActionButton.extended(
                heroTag: 'new-offer',
                backgroundColor: AppColors.businessInk,
                foregroundColor: AppColors.onBusinessInk,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New offer'),
                onPressed: () => context.push(BusinessRoutes.offerNew),
              ),
            )
          : null,
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Offers',
            subtitle: isOwner ? 'Promotions your town can see' : 'Promotions your business runs · read only',
            child: BusinessStatStrip(
              isLoading: counts == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Total offers', value: '${counts?.total ?? 0}'),
                BusinessStat(label: 'Active', value: '${counts?.active ?? 0}', hint: 'LIVE NOW'),
                BusinessStat(label: 'Scheduled', value: '${counts?.draft ?? 0}', hint: 'NOT PUBLISHED'),
                BusinessStat(label: 'Expired', value: '${counts?.expired ?? 0}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(labelText: 'Search offers', hintText: 'By title', prefixIcon: Icon(Icons.search_rounded)),
              textInputAction: TextInputAction.search,
              onSubmitted: ref.read(offerListFiltersProvider.notifier).setSearch,
            ),
          ),
          SizedBox(
            height: AppSize.controlSm,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final (value, label) in OfferListFilters.statusOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: value == filters.status,
                      selectedColor: AppColors.businessTintStrong,
                      labelStyle: textTheme.labelMedium?.copyWith(color: value == filters.status ? AppColors.businessInk : AppColors.textSecondary),
                      side: BorderSide(color: value == filters.status ? AppColors.businessInk : AppColors.border),
                      showCheckmark: false,
                      onSelected: (_) => ref.read(offerListFiltersProvider.notifier).setStatus(value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(count: 3),
              error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load offers.', onRetry: () => ref.read(businessOffersControllerProvider.notifier).refresh()),
              data: (data) {
                if (data.items.isEmpty) {
                  final filtered = filters.status != 'all' || filters.search.isNotEmpty;
                  return EmptyState(
                    icon: Icons.campaign_outlined,
                    title: filtered ? 'No offers match this filter' : 'No offers yet',
                    message: filtered
                        ? 'Try a different status, or clear the search.'
                        : isOwner
                            ? 'Create your first offer to promote your business.'
                            : 'Your business has no offers yet.',
                    action: isOwner && !filtered ? AppButton(label: 'New offer', icon: Icons.add_rounded, expand: false, onPressed: () => context.push(BusinessRoutes.offerNew)) : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(businessOffersControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl * 2),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
                    itemBuilder: (context, i) {
                      if (i >= data.items.length) {
                        return const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Center(child: CircularProgressIndicator()));
                      }
                      final offer = data.items[i];
                      return OfferCard(
                        offer: offer,
                        onTap: () => context.push('${BusinessRoutes.offers}/${offer.id}'),
                        onMore: isOwner && !offer.isExpired ? () => showOfferActionsSheet(context, ref, offer) : null,
                      );
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

/// One promotion: image (or a branded placeholder), status, title, the
/// schedule line and a coin chip when redeemable.
class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, required this.onTap, this.onMore});

  final BusinessOffer offer;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${offer.title}, ${offerStatusLabel(offer.status)}',
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (offer.imageUrl != null && offer.imageUrl!.isNotEmpty)
                      Image.network(offer.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _OfferPlaceholder())
                    else
                      const _OfferPlaceholder(),
                    Positioned(
                      left: AppSpacing.smd,
                      top: AppSpacing.smd,
                      child: StatusBadge(label: offerStatusLabel(offer.status), tone: offerStatusTone(offer.status), icon: offer.isLiveNow ? Icons.bolt_rounded : null),
                    ),
                    if (onMore != null)
                      Positioned(
                        right: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: Material(
                          color: AppColors.surface.withValues(alpha: 0.9),
                          shape: const CircleBorder(),
                          child: IconButton(icon: const Icon(Icons.more_horiz_rounded), tooltip: 'Actions for ${offer.title}', onPressed: onMore),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.title, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: AppIconSize.xs, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '${offer.startsAt != null ? formatDate(offer.startsAt!) : '—'} → ${offer.endsAt != null ? formatDate(offer.endsAt!) : '—'}'
                            '${offer.branchName != null ? ' · ${offer.branchName}' : ''}',
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (offer.isCoinRedeemable) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          StatusBadge(label: '${_trim(offer.coinDiscountRate!)}% Town Coin', tone: AppTone.success, icon: Icons.monetization_on_rounded),
                          if (offer.applicableItem != null && offer.applicableItem!.isNotEmpty) StatusBadge(label: offer.applicableItem!, tone: AppTone.neutral),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _OfferPlaceholder extends StatelessWidget {
  const _OfferPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.businessTintStrong, AppColors.businessTint])),
      child: Center(child: Icon(Icons.campaign_rounded, color: AppColors.businessInk, size: AppIconSize.display)),
    );
  }
}
