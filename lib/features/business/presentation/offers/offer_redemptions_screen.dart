import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/load_more_indicator.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../offer_redemptions/data/models/offer_redemption.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/offer_redemptions_controller.dart';
import '../business_routes.dart';
import '../growth_status.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// Customers asking for a Town Coin discount on one of this business's
/// offers. Owner and Staff both decide. No code or QR exists for these --
/// the merchant matches the request to the person at the counter by offer,
/// bill and time.
class OfferRedemptionsScreen extends ConsumerStatefulWidget {
  const OfferRedemptionsScreen({super.key});

  @override
  ConsumerState<OfferRedemptionsScreen> createState() => _OfferRedemptionsScreenState();
}

class _OfferRedemptionsScreenState extends ConsumerState<OfferRedemptionsScreen> {
  final _scroll = ScrollController();
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(offerRedemptionsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _approve(OfferRedemption r) async {
    final ok = await showBusinessConfirmDialog(
      context,
      title: 'Approve this offer redemption?',
      message: "This debits ${r.coinsRequested} coins from the customer's wallet (capped at what they actually have) and applies the discount immediately. This cannot be undone.",
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = r.id);
    try {
      await ref.read(offerRedemptionsControllerProvider.notifier).approve(r.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer redemption approved — coins debited.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(OfferRedemption r) async {
    final reason = await showBusinessReasonDialog(context, title: 'Reject this offer redemption?', message: 'No coins move. The customer is notified.', confirmLabel: 'Reject', placeholder: 'Why is this being rejected?');
    if (reason == null || !mounted) return;
    setState(() => _busyId = r.id);
    try {
      await ref.read(offerRedemptionsControllerProvider.notifier).reject(r.id, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer redemption rejected.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(offerRedemptionFilterProvider);
    final state = ref.watch(offerRedemptionsControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Offer redemptions',
            subtitle: 'Customers asking for a Town Coin discount on your offers',
            leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root)),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSize.controlSm,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final (value, label) in OfferRedemptionFilterController.options)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: value == status,
                      selectedColor: AppColors.businessTintStrong,
                      labelStyle: textTheme.labelMedium?.copyWith(color: value == status ? AppColors.businessInk : AppColors.textSecondary),
                      side: BorderSide(color: value == status ? AppColors.businessInk : AppColors.border),
                      showCheckmark: false,
                      onSelected: (_) => ref.read(offerRedemptionFilterProvider.notifier).set(value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(),
              error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load offer redemptions.', onRetry: () => ref.read(offerRedemptionsControllerProvider.notifier).refresh()),
              data: (data) {
                if (data.items.isEmpty) {
                  final pending = status == 'pending';
                  return EmptyState(
                    icon: Icons.redeem_rounded,
                    title: pending ? 'Nothing awaiting review' : 'No offer redemptions yet',
                    message: pending ? "You're all caught up. New requests will appear here as customers make them." : 'Requests will appear here once a customer redeems Town Coin on one of your offers.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(offerRedemptionsControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0) + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return const InfoBox(
                          icon: Icons.person_pin_circle_outlined,
                          message: 'Match each request to the customer at your counter by the offer, the bill amount and when it was raised.',
                        );
                      }
                      final index = i - 1;
                      if (index >= data.items.length) {
                        return const LoadMoreIndicator();
                      }
                      final r = data.items[index];
                      return _RequestCard(redemption: r, busy: _busyId == r.id, onApprove: () => _approve(r), onReject: () => _reject(r));
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.redemption, required this.busy, required this.onApprove, required this.onReject});

  final OfferRedemption redemption;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final r = redemption;
    final textTheme = Theme.of(context).textTheme;
    final pending = r.status == 'pending';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSize.avatarMd,
                height: AppSize.avatarMd,
                decoration: BoxDecoration(color: AppColors.businessTint, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: const Icon(Icons.local_offer_rounded, color: AppColors.businessInk, size: AppIconSize.md),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(r.createdAt != null ? '${relativeTime(r.createdAt!)} · ${formatDateTime(r.createdAt!)}' : '—', style: AppTypography.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: offerRedemptionStatusLabel(r.status), tone: offerRedemptionStatusTone(r.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              _Figure(label: 'Bill', value: formatMoney(r.billAmount)),
              _Figure(label: 'Coins requested', value: '${r.coinsRequested}'),
              _Figure(label: pending ? 'Max discount' : 'Discount', value: formatMoney(r.discountAmount ?? r.maxDiscountAmount), emphasize: true),
            ],
          ),
          if (r.status == 'rejected' && r.rejectionReason != null && r.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Reason: ${r.rejectionReason}', style: textTheme.bodySmall),
          ],
          if (pending) ...[
            const SizedBox(height: AppSpacing.smd),
            Row(
              children: [
                Expanded(child: AppButton(label: 'Reject', variant: AppButtonVariant.secondary, size: AppButtonSize.sm, icon: Icons.block_rounded, onPressed: busy ? null : onReject)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AppButton(label: 'Approve', size: AppButtonSize.sm, icon: Icons.verified_rounded, isLoading: busy, onPressed: onApprove)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: AppTypography.numericFinancialSmall.copyWith(color: emphasize ? AppColors.success : null), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
