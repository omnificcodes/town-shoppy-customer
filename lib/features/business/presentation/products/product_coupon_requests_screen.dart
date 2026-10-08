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
import '../../../product_coupons/data/models/product_coupon_request.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/product_coupon_requests_controller.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

AppTone productCouponStatusTone(String s) => switch (s) {
  'pending' => AppTone.pending,
  'approved' => AppTone.success,
  'rejected' => AppTone.error,
  _ => AppTone.neutral,
};

String productCouponStatusLabel(String s) => switch (s) {
  'pending' => 'Awaiting review',
  'approved' => 'Accepted',
  'rejected' => 'Declined',
  _ => s,
};

/// Customers asking for the Lucky Draw coupons on one of this shop's
/// products. Owner and Staff both decide. Accepting gives the customer the
/// coupons (counted against the plan's monthly and the shop's daily
/// coupons); declining gives nothing and the customer may ask again.
class ProductCouponRequestsScreen extends ConsumerStatefulWidget {
  const ProductCouponRequestsScreen({super.key});

  @override
  ConsumerState<ProductCouponRequestsScreen> createState() => _ProductCouponRequestsScreenState();
}

class _ProductCouponRequestsScreenState extends ConsumerState<ProductCouponRequestsScreen> {
  final _scroll = ScrollController();
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(productCouponRequestsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _approve(ProductCouponRequest r) async {
    final who = r.customerName ?? 'this customer';
    final ok = await showBusinessConfirmDialog(
      context,
      title: 'Give ${r.couponsRequested} coupons?',
      message:
          '$who gets ${r.couponsRequested} Lucky Draw coupons for "${r.productName}". They count towards your plan\'s coupons. This cannot be undone.',
      confirmLabel: 'Accept',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = r.id);
    try {
      await ref.read(productCouponRequestsControllerProvider.notifier).approve(r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted — the coupons are with the customer.')));
      }
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(ProductCouponRequest r) async {
    final reason = await showBusinessReasonDialog(
      context,
      title: 'Decline this request?',
      message: 'No coupons are given. The customer is notified and may ask again.',
      confirmLabel: 'Decline',
      placeholder: 'Why is this being declined?',
    );
    if (reason == null || !mounted) return;
    setState(() => _busyId = r.id);
    try {
      await ref.read(productCouponRequestsControllerProvider.notifier).reject(r.id, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(productCouponRequestFilterProvider);
    final state = ref.watch(productCouponRequestsControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Coupon requests',
            subtitle: 'Customers asking for your products\' Lucky Draw coupons',
            leading: BusinessHeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSize.controlSm,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final (value, label) in ProductCouponRequestFilterController.options)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: value == status,
                      selectedColor: AppColors.businessTintStrong,
                      labelStyle: textTheme.labelMedium?.copyWith(
                        color: value == status ? AppColors.businessInk : AppColors.textSecondary,
                      ),
                      side: BorderSide(color: value == status ? AppColors.businessInk : AppColors.border),
                      showCheckmark: false,
                      onSelected: (_) => ref.read(productCouponRequestFilterProvider.notifier).set(value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(),
              error: (e, _) => ErrorState(
                error: e is AppException ? e : const UnknownAppException(),
                title: 'Could not load coupon requests.',
                onRetry: () => ref.read(productCouponRequestsControllerProvider.notifier).refresh(),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  final pending = status == 'pending';
                  return EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: pending ? 'Nothing awaiting review' : 'No coupon requests yet',
                    message: pending
                        ? "You're all caught up. New requests will appear here as customers make them."
                        : 'Requests appear here once a customer asks for the coupons on one of your products.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(productCouponRequestsControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0) + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return const InfoBox(
                          icon: Icons.person_pin_circle_outlined,
                          message: 'Accept only when the customer has bought the product from your shop.',
                        );
                      }
                      final index = i - 1;
                      if (index >= data.items.length) return const LoadMoreIndicator();
                      final r = data.items[index];
                      return _RequestCard(
                        request: r,
                        busy: _busyId == r.id,
                        onApprove: () => _approve(r),
                        onReject: () => _reject(r),
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.busy, required this.onApprove, required this.onReject});

  final ProductCouponRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final textTheme = Theme.of(context).textTheme;
    final image = r.productImageUrl;
    final who = [r.customerName, r.customerMobileNumber].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final coupons = r.couponsIssued ?? r.couponsRequested;

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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.businessTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: image == null
                    ? const Icon(Icons.shopping_bag_rounded, color: AppColors.businessInk, size: AppIconSize.md)
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.shopping_bag_rounded, color: AppColors.businessInk, size: AppIconSize.md),
                      ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.productName, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (who.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(who, style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      r.createdAt != null ? '${relativeTime(r.createdAt!)} · ${formatDateTime(r.createdAt!)}' : '—',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: productCouponStatusLabel(r.status), tone: productCouponStatusTone(r.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              const Icon(Icons.confirmation_number_rounded, size: AppIconSize.sm, color: AppColors.businessInk),
              const SizedBox(width: AppSpacing.xs),
              Text(
                coupons == 1 ? '1 Lucky Draw coupon' : '$coupons Lucky Draw coupons',
                style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (r.status == 'rejected' && r.rejectionReason != null && r.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Reason: ${r.rejectionReason}', style: textTheme.bodySmall),
          ],
          if (r.isPending) ...[
            const SizedBox(height: AppSpacing.smd),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Decline',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    icon: Icons.block_rounded,
                    onPressed: busy ? null : onReject,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Accept',
                    size: AppButtonSize.sm,
                    icon: Icons.verified_rounded,
                    isLoading: busy,
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
