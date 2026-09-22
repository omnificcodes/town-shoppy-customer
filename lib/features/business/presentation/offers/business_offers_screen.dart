import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/load_more_indicator.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../notifications/application/unread_count_provider.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/business_context.dart';
import '../../application/business_offers_controller.dart';
import '../../data/models/business_offer.dart';
import '../business_routes.dart';
import '../growth_status.dart';
import '../widgets/business_page_header.dart';
import 'offer_actions.dart';

/// The Offers tab, following the Google Stitch redesign: a deep header with
/// the status counts, a search field, status pills, then every promotion
/// this business runs as image cards. Owners create, publish, withdraw and
/// end from here; staff read.
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
    final filterController = ref.read(offerListFiltersProvider.notifier);
    final state = ref.watch(businessOffersControllerProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final filtered = filters.status != 'all' || filters.search.isNotEmpty;
    // With no offers at all the empty state carries its own New offer button.
    final showsEmptyCta = !filtered && (state.value?.items.isEmpty ?? false);

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      // In the corner, where a floating action belongs. It used to be
      // lifted a whole FAB's height to "sit above the shell's docked
      // Counter button" -- but that button is centre-docked and this one
      // is at the end, so they never met: the lift only pushed this one
      // into the middle of the list, across the first card.
      floatingActionButton: isOwner && !showsEmptyCta
          ? FloatingActionButton.extended(
              heroTag: 'new-offer',
              backgroundColor: AppColors.orangeDeep,
              foregroundColor: AppColors.onCrimson,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New offer'),
              onPressed: () => context.push(BusinessRoutes.offerNew),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(businessOffersControllerProvider.notifier).refresh(),
        edgeOffset: 120,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Hero(isOwner: isOwner)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.smd),
                child: _SearchField(controller: _search, onSubmitted: filterController.setSearch),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.smd),
                child: _StatusPills(selected: filters.status, onSelected: filterController.setStatus),
              ),
            ),
            ...state.when(
              loading: () => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
                    itemBuilder: (_, _) =>
                        LoadingSkeleton(height: 200, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    error: e is AppException ? e : const UnknownAppException(),
                    title: 'Could not load offers.',
                    onRetry: () => ref.read(businessOffersControllerProvider.notifier).refresh(),
                  ),
                ),
              ],
              data: (data) {
                if (data.items.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyOffers(filtered: filtered, isOwner: isOwner),
                    ),
                  ];
                }
                return [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl * 2),
                    sliver: SliverList.separated(
                      itemCount: data.items.length + (data.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
                      itemBuilder: (context, i) {
                        if (i >= data.items.length) {
                          return const LoadMoreIndicator();
                        }
                        final offer = data.items[i];
                        return OfferCard(
                          offer: offer,
                          onTap: () => context.push('${BusinessRoutes.offers}/${offer.id}'),
                          onMore: isOwner && !offer.isExpired ? () => showOfferActionsSheet(context, ref, offer) : null,
                        );
                      },
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The deep espresso header: Business chip, notifications, the title and
/// the status counts as translucent cards.
class _Hero extends ConsumerWidget {
  const _Hero({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(businessOffersControllerProvider);
    final counts = state.value?.counts;
    final loading = counts == null && state.isLoading;
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.businessInkDeep, AppColors.businessInk],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSpacing.xl)),
        boxShadow: AppElevation.floating,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSpacing.xl)),
        child: Stack(
          children: [
            Positioned(
              right: -AppSpacing.xxl,
              top: -AppSpacing.xxl,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: -AppSpacing.xl,
              top: 90,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.08), shape: BoxShape.circle),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const BusinessModeChip(),
                              const Spacer(),
                              _BellButton(unread: unread),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            header: true,
                            child: Text(
                              'Offers',
                              style: textTheme.headlineMedium?.copyWith(
                                color: AppColors.onBusinessInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            isOwner ? 'Promotions your town can see' : 'Promotions your business runs · read only',
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CountCard(
                              label: 'Total offers',
                              value: counts?.total ?? 0,
                              hint: 'ALL CREATED',
                              loading: loading,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _CountCard(
                              label: 'Active',
                              value: counts?.active ?? 0,
                              hint: 'LIVE NOW',
                              loading: loading,
                              live: true,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _CountCard(
                              label: 'Scheduled',
                              value: counts?.draft ?? 0,
                              hint: 'NOT PUBLISHED',
                              loading: loading,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _CountCard(label: 'Expired', value: counts?.expired ?? 0, hint: 'ENDED', loading: loading),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      child: Material(
        color: AppColors.onBusinessInk.withValues(alpha: 0.12),
        shape: CircleBorder(side: BorderSide(color: AppColors.onBusinessInk.withValues(alpha: 0.15))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(BusinessRoutes.notifications),
          child: SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.onBusinessInk, size: AppIconSize.lg),
                if (unread > 0)
                  Positioned(
                    top: AppSpacing.smd,
                    right: AppSpacing.smd,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.businessInk, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One translucent count card; the Active card is outlined green with a
/// live dot and a LIVE NOW tag.
class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.loading,
    this.live = false,
  });

  final String label;
  final int value;
  final String hint;
  final bool loading;
  final bool live;

  static const _liveGreen = Color(0xFF6EE7A8);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: loading ? '$label, loading' : '$label: $value, $hint',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 116, maxWidth: 160),
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          color: live ? AppColors.success.withValues(alpha: 0.14) : AppColors.onBusinessInk.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: live ? _liveGreen.withValues(alpha: 0.4) : AppColors.onBusinessInk.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.onBusinessInkMuted),
                  ),
                ),
                if (live) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: _liveGreen, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (loading)
              const LoadingSkeleton(width: 40, height: 28)
            else
              Text(
                '$value',
                style: AppTypography.numericFinancialMedium.copyWith(
                  color: AppColors.onBusinessInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            if (live)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2, vertical: 2),
                  child: Text(
                    hint,
                    maxLines: 1,
                    style: AppTypography.overline.copyWith(
                      color: _liveGreen,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              )
            else
              Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.overline.copyWith(
                  color: AppColors.onBusinessInk.withValues(alpha: 0.45),
                  letterSpacing: 0.8,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A rounded white search field; the search is sent when submitted.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search offers',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.orangeDeep, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          for (final (value, label) in OfferListFilters.statusOptions) ...[
            _Pill(label: label, selected: value == selected, onTap: () => onSelected(value)),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.businessInk : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.businessInk : AppColors.border)),
        elevation: selected ? 1 : 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.controlSm, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? AppColors.onBusinessInk : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers({required this.filtered, required this.isOwner});

  final bool filtered;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl + AppSize.fab),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: SizedBox.square(
              dimension: 128,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.orange.withValues(alpha: 0.16), AppColors.orange.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: AppGradients.warmWash,
                      borderRadius: BorderRadius.circular(AppSpacing.xl),
                      border: Border.all(color: AppColors.orangeBorder),
                      boxShadow: AppElevation.card,
                    ),
                    child: Icon(
                      filtered ? Icons.search_off_rounded : Icons.campaign_rounded,
                      color: AppColors.businessInk.withValues(alpha: 0.55),
                      size: AppIconSize.display,
                    ),
                  ),
                  if (!filtered)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        width: AppIconSize.lg,
                        height: AppIconSize.lg,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.star_rounded, color: AppColors.onCrimson, size: AppIconSize.sm),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filtered ? 'No offers match this filter' : 'No offers yet',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              filtered
                  ? 'Try a different status, or clear the search.'
                  : isOwner
                  ? 'Create your first offer to promote your business to shoppers across your town.'
                  : 'Your business has no offers yet.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          if (isOwner && !filtered) ...[
            const SizedBox(height: AppSpacing.lg),
            _NewOfferButton(onTap: () => context.push(BusinessRoutes.offerNew)),
          ],
        ],
      ),
    );
  }
}

class _NewOfferButton extends StatelessWidget {
  const _NewOfferButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      label: 'New offer',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.floating),
        child: Material(
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: AppGradients.promoHero),
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.controlLg + AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: AppColors.onCrimson),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'New offer',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Semantics(
      button: true,
      label: '${offer.title}, ${offerStatusLabel(offer.status)}',
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: offer.isLiveNow ? AppColors.success.withValues(alpha: 0.35) : AppColors.border),
          ),
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
                        ColoredBox(
                          color: AppColors.surfaceMuted,
                          // Contained, not cropped: a merchant uploads
                          // whatever they have -- a tall poster, a phone
                          // screenshot -- and `cover` on this wide banner
                          // cut those down to an unreadable middle band.
                          // The whole image now shows, on the card's own
                          // ground rather than against black.
                          child: Image.network(
                            key: ValueKey(offer.imageUrl),
                            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                            offer.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const _OfferPlaceholder(),
                          ),
                        )
                      else
                        const _OfferPlaceholder(),
                      Positioned(
                        left: AppSpacing.smd,
                        top: AppSpacing.smd,
                        child: StatusBadge(
                          label: offerStatusLabel(offer.status),
                          tone: offerStatusTone(offer.status),
                          icon: offer.isLiveNow ? Icons.bolt_rounded : null,
                        ),
                      ),
                      if (onMore != null)
                        Positioned(
                          right: AppSpacing.xs,
                          top: AppSpacing.xs,
                          child: Material(
                            color: AppColors.surface.withValues(alpha: 0.9),
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.more_horiz_rounded),
                              tooltip: 'Actions for ${offer.title}',
                              onPressed: onMore,
                            ),
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
                      Text(
                        offer.title,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                          runSpacing: AppSpacing.xs,
                          children: [
                            StatusBadge(
                              label: '${_trim(offer.coinDiscountRate!)}% Town Coin',
                              tone: AppTone.success,
                              icon: Icons.monetization_on_rounded,
                            ),
                            if (offer.applicableItem != null && offer.applicableItem!.isNotEmpty)
                              StatusBadge(label: offer.applicableItem!, tone: AppTone.neutral),
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
      decoration: BoxDecoration(gradient: AppGradients.warmWash),
      child: Center(
        child: Icon(Icons.campaign_rounded, color: AppColors.orangeDeep, size: AppIconSize.display),
      ),
    );
  }
}
