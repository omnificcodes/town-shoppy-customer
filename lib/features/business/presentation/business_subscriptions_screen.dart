import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/nav_link_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/business_context.dart';
import '../data/models/merchant_subscription.dart';
import '../data/models/subscription_plan.dart';
import 'business_routes.dart';
import 'business_status.dart';
import 'widgets/business_page_header.dart';

/// Current package + the plan catalogue. Checkout is a hand-off to the
/// merchant web app in the browser (product decision -- no payment SDK in
/// the app), so the only button here opens that page.
class BusinessSubscriptionsScreen extends ConsumerWidget {
  const BusinessSubscriptionsScreen({super.key});

  static String? get _subscribeUrl => Env.merchantWebUrl.isEmpty ? null : '${Env.merchantWebUrl}/merchant/subscriptions/subscribe';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final entitlement = ref.watch(merchantEntitlementProvider);
    final subscription = ref.watch(mySubscriptionProvider);
    final plans = ref.watch(subscriptionPlansProvider);
    final textTheme = Theme.of(context).textTheme;
    final hasActive = subscription.value?.grantsFullService ?? entitlement.value?.hasPackage ?? false;

    return BusinessScaffold(
      title: 'Subscriptions',
      padded: false,
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(merchantEntitlementProvider)
            ..invalidate(mySubscriptionProvider)
            ..invalidate(subscriptionPlansProvider);
          try {
            await ref.read(subscriptionPlansProvider.future);
          } on AppException {
            // The plans section renders its own ErrorState.
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const SectionHeader(title: 'Your package', icon: Icons.workspace_premium_rounded),
            const SizedBox(height: AppSpacing.smd),
            if (isOwner)
              subscription.when(
                loading: () => const LoadingSkeletonCard(),
                error: (e, _) => AppCard(child: ErrorState(compact: true, error: e is AppException ? e : const UnknownAppException(), onRetry: () => ref.invalidate(mySubscriptionProvider))),
                data: (sub) => sub == null ? _NoPlanCard(entitlement: entitlement.value?.hasPackage ?? false) : _CurrentPlanCard(subscription: sub),
              )
            else
              entitlement.when(
                loading: () => const LoadingSkeletonCard(),
                error: (_, _) => const SizedBox.shrink(),
                data: (e) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(e.planName ?? 'No package', style: textTheme.titleLarge)),
                          if (e.status != null) StatusBadge(label: subscriptionStatusLabel(e.status!), tone: subscriptionStatusTone(e.status!)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Only the shop owner can change the package.', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            if (isOwner) ...[
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Billing', icon: Icons.receipt_long_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    NavLinkRow(
                      icon: Icons.credit_card_rounded,
                      iconColor: AppColors.businessInk,
                      title: 'Payments',
                      subtitle: 'Every payment you have made for your package',
                      onTap: () => context.push(BusinessRoutes.payments),
                    ),
                    const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                    NavLinkRow(
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.businessInk,
                      title: 'Invoices',
                      subtitle: 'GST tax invoices, one per successful payment',
                      onTap: () => context.push(BusinessRoutes.invoices),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            SectionHeader(
              title: hasActive ? 'Upgrade your plan' : 'Choose a package',
              subtitle: hasActive
                  ? null
                  : 'Purchases, coupons, offers, branches, your customer directory and redemptions all need an active package. Your dashboard and your shop profile stay free.',
              icon: Icons.storefront_rounded,
            ),
            const SizedBox(height: AppSpacing.smd),
            plans.when(
              loading: () => const Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
              error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), onRetry: () => ref.invalidate(subscriptionPlansProvider)),
              data: (list) => Column(
                children: [
                  for (final plan in list) ...[
                    _PlanCard(plan: plan, isCurrent: subscription.value?.plan?.id == plan.id),
                    const SizedBox(height: AppSpacing.smd),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isOwner)
              _subscribeUrl == null
                  ? const InfoBox(
                      icon: Icons.language_rounded,
                      title: 'Subscribe on the web',
                      message: 'Packages are purchased from the Town Shoppy merchant web app. Sign in there with this same mobile number to choose a plan — it applies to this app immediately.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          label: hasActive ? 'Change plan on the web' : 'Subscribe on the web',
                          icon: Icons.open_in_new_rounded,
                          onPressed: () => launchUrl(Uri.parse(_subscribeUrl!), mode: LaunchMode.externalApplication),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Checkout opens in your browser. Sign in with this same mobile number; your package applies here as soon as payment completes.',
                          style: AppTypography.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
            else
              const InfoBox(icon: Icons.lock_outline_rounded, tone: AppTone.neutral, message: 'Ask the shop owner to choose or change the package.'),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.entitlement});

  final bool entitlement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      tinted: true,
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.orange, size: AppIconSize.lg),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No active plan', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text('Choose a package below to unlock your counter, offers and more.', style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.subscription});

  final MerchantSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = subscription;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.plan?.name ?? 'Plan', style: textTheme.titleLarge)),
              StatusBadge(label: subscriptionStatusLabel(s.status), tone: subscriptionStatusTone(s.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (s.plan != null) DetailRow(label: 'Price', value: '₹${s.plan!.price.toStringAsFixed(0)} / ${s.plan!.billingCycle}'),
          if (s.currentPeriodEnd != null) DetailRow(label: 'Renews / ends', value: _date(s.currentPeriodEnd!)),
          DetailRow(
            label: 'Coupons this month',
            value: s.couponQuotaRemaining == null ? '${s.couponQuotaUsed} used · unlimited' : '${s.couponQuotaUsed} used · ${s.couponQuotaRemaining} left',
          ),
          if (s.pendingPlan != null)
            DetailRow(label: 'Changing to', value: '${s.pendingPlan!.name}${s.pendingPlanChangeAt != null ? ' on ${_date(s.pendingPlanChangeAt!)}' : ''}'),
        ],
      ),
    );
  }

  static String _date(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.isCurrent});

  final SubscriptionPlan plan;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      borderColor: isCurrent ? AppColors.businessInk : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: textTheme.titleLarge)),
              if (isCurrent) const StatusBadge(label: 'Current', tone: AppTone.info),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${plan.price.toStringAsFixed(0)}', style: AppTypography.numericFinancialMedium),
              const SizedBox(width: AppSpacing.xs),
              Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xxs), child: Text('/ ${plan.billingCycle}', style: textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(plan.couponQuotaMonthly == null ? 'Unlimited coupons' : '${plan.couponQuotaMonthly} coupons / month', style: textTheme.bodyMedium),
          if (plan.enabledFeatureLabels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final f in plan.enabledFeatureLabels) StatusBadge(label: f, tone: AppTone.neutral, icon: Icons.check_rounded)],
            ),
          ],
        ],
      ),
    );
  }
}
