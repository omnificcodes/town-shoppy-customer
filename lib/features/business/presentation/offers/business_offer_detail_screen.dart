import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/detail_row.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/business_context.dart';
import '../../application/business_offers_controller.dart';
import '../growth_status.dart';
import '../widgets/business_page_header.dart';
import 'offer_actions.dart';

/// One offer, full-bleed image on top, everything the web detail page
/// lists underneath, and the Owner's next action pinned at the bottom.
class BusinessOfferDetailScreen extends ConsumerWidget {
  const BusinessOfferDetailScreen({super.key, required this.offerId});

  final int offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessOfferProvider(offerId));
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final textTheme = Theme.of(context).textTheme;
    final offer = async.value;

    return BusinessScaffold(
      title: 'Offer',
      padded: false,
      actions: [
        if (isOwner && offer != null && !offer.isExpired)
          IconButton(icon: const Icon(Icons.more_horiz_rounded), tooltip: 'Actions', onPressed: () => showOfferActionsSheet(context, ref, offer)),
      ],
      bottomBar: isOwner && offer != null && !offer.isExpired
          ? (offer.isDraft
              ? Row(
                  children: [
                    Expanded(child: AppButton(label: 'Edit', variant: AppButtonVariant.secondary, icon: Icons.edit_outlined, onPressed: () => runOfferAction(context, ref, offer, 'edit'))),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: AppButton(label: 'Publish', icon: Icons.send_rounded, onPressed: () => runOfferAction(context, ref, offer, 'publish'))),
                  ],
                )
              : AppButton(label: 'End offer', variant: AppButtonVariant.destructive, icon: Icons.stop_circle_outlined, onPressed: () => runOfferAction(context, ref, offer, 'end')))
          : null,
      body: async.when(
        loading: () => const LoadingSkeletonList(count: 4),
        error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load this offer', onRetry: () => ref.invalidate(businessOfferProvider(offerId))),
        data: (o) => RefreshIndicator(
          onRefresh: () => ref.refresh(businessOfferProvider(offerId).future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: o.imageUrl != null && o.imageUrl!.isNotEmpty
                    ? Image.network(o.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _Placeholder())
                    : const _Placeholder(),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusBadge(label: offerStatusLabel(o.status), tone: offerStatusTone(o.status), large: true, icon: o.isLiveNow ? Icons.bolt_rounded : null),
                        if (o.isCoinRedeemable) StatusBadge(label: '${_trim(o.coinDiscountRate!)}% Town Coin', tone: AppTone.success, large: true, icon: Icons.monetization_on_rounded),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.smd),
                    Text(o.title, style: textTheme.headlineMedium),
                    if (o.description != null && o.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(o.description!, style: textTheme.bodyMedium),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    const SectionHeader(title: 'Schedule', icon: Icons.schedule_rounded),
                    const SizedBox(height: AppSpacing.smd),
                    AppCard(
                      child: Column(
                        children: [
                          DetailRow(label: 'Starts', value: o.startsAt != null ? formatDateTime(o.startsAt!) : '—'),
                          DetailRow(label: 'Ends', value: o.endsAt != null ? formatDateTime(o.endsAt!) : '—'),
                          DetailRow(label: 'Branch', value: o.branchName ?? 'All branches'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    const SectionHeader(title: 'Town Coin discount', icon: Icons.monetization_on_outlined),
                    const SizedBox(height: AppSpacing.smd),
                    AppCard(
                      child: Column(
                        children: [
                          DetailRow(label: 'Redeemable with coins', child: StatusBadge(label: o.isCoinRedeemable ? 'Yes' : 'No', tone: o.isCoinRedeemable ? AppTone.success : AppTone.neutral)),
                          if (o.isCoinRedeemable) ...[
                            DetailRow(label: 'Coin discount rate', value: '${_trim(o.coinDiscountRate!)}%'),
                            DetailRow(label: 'Applicable item', value: o.applicableItem ?? 'Anything'),
                          ],
                        ],
                      ),
                    ),
                    if (o.terms != null && o.terms!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.section),
                      const SectionHeader(title: 'Terms', icon: Icons.gavel_rounded),
                      const SizedBox(height: AppSpacing.smd),
                      AppCard(child: Text(o.terms!, style: textTheme.bodyMedium)),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    const SectionHeader(title: 'Details', icon: Icons.info_outline_rounded),
                    const SizedBox(height: AppSpacing.smd),
                    AppCard(
                      child: Column(
                        children: [
                          DetailRow(label: 'Type', value: offerTypeLabel(o.offerType)),
                          if (o.discountValue != null) DetailRow(label: 'Discount value', value: o.offerType == 'percentage_discount' ? '${_trim(o.discountValue!)}%' : formatMoney(o.discountValue!)),
                          DetailRow(label: 'Created by', value: o.createdBy == null ? '—' : '${o.createdBy![0].toUpperCase()}${o.createdBy!.substring(1)}'),
                          if (o.createdAt != null) DetailRow(label: 'Created', value: formatDateTime(o.createdAt!)),
                          if (o.updatedAt != null) DetailRow(label: 'Last updated', value: formatDateTime(o.updatedAt!)),
                        ],
                      ),
                    ),
                    if (o.isExpired) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('An expired offer cannot be edited or republished — create a new one to run it again.', style: AppTypography.caption),
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

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep])),
      child: Center(child: Icon(Icons.campaign_rounded, color: AppColors.yellow, size: AppIconSize.hero)),
    );
  }
}
