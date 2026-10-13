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
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/business_context.dart';
import '../application/subscription_checkout_controller.dart';
import '../data/models/merchant_subscription.dart';
import '../data/models/subscription_plan.dart';
import '../data/subscriptions_repository.dart';
import 'business_routes.dart';
import 'business_status.dart';
import 'widgets/business_page_header.dart';

/// Current package + the plan catalogue. On Android, paying for a plan
/// happens right here via Razorpay's native checkout sheet. On iOS and the
/// web build, checkout stays a hand-off to the merchant web app in the
/// browser -- see `subscription_checkout_controller.dart` for why the two
/// platforms deliberately differ.
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
    final useNativeCheckout = ref.watch(nativeCheckoutAvailableProvider) && isOwner;

    // Registered on every build regardless of [useNativeCheckout] -- Riverpod
    // expects `ref.listen` calls to stay unconditional across rebuilds; the
    // side effect itself is a no-op unless native checkout is actually in
    // use, since nothing calls the controller's `start()` otherwise.
    ref.listen<SubscriptionCheckoutState>(subscriptionCheckoutControllerProvider, (previous, next) {
      if (!useNativeCheckout || !context.mounted) return;
      if (next.status == SubscriptionCheckoutStatus.success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Subscribed to ${next.completedPlanName}.')));
        ref.read(subscriptionCheckoutControllerProvider.notifier).acknowledge();
      } else if (next.status == SubscriptionCheckoutStatus.error && next.error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.error!.message)));
      }
    });

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
              data: (list) {
                final sub = subscription.value;
                final subPlanId = sub?.plan?.id;
                final subPlanPrice = sub?.plan?.price;
                final isEntitled = sub?.grantsFullService ?? false;
                final hasStalledSubscription = sub != null && !isEntitled;
                final checkoutState = useNativeCheckout ? ref.watch(subscriptionCheckoutControllerProvider) : null;
                final auth = ref.watch(authControllerProvider);
                final mobileNumber = auth is AuthAuthenticated ? auth.account.mobileNumber : '';

                return Column(
                  children: [
                    for (final plan in list) ...[
                      _PlanCard(
                        plan: plan,
                        isCurrent: isEntitled && subPlanId == plan.id,
                        isStalled: hasStalledSubscription && subPlanId == plan.id,
                        isCheaperThanCurrent: isEntitled && subPlanPrice != null && plan.price < subPlanPrice,
                        nativeCheckout: useNativeCheckout,
                        busy: checkoutState?.isBusyFor(plan.id) ?? false,
                        // BR-43: the one free trial per shop, from the plans page.
                        canStartTrial: isOwner && plan.hasTrial && !isEntitled && ref.watch(myMerchantProvider).value?.freeTrialUsedAt == null,
                        renewalOpen: isEntitled && subPlanId == plan.id && (sub?.renewalOpen ?? false) && !plan.isFree,
                        isTrial: sub?.isTrial ?? false,
                        onStartTrial: () => _startTrial(context, ref, plan),
                        onSubscribe: useNativeCheckout
                            ? () => ref.read(subscriptionCheckoutControllerProvider.notifier).start(plan, contactNumber: mobileNumber)
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.smd),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (useNativeCheckout)
              const InfoBox(
                icon: Icons.verified_user_outlined,
                tone: AppTone.neutral,
                message: 'Payments are processed securely by Razorpay. Your package applies the moment payment completes.',
              )
            else if (isOwner)
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

/// BR-43: starts a plan's free trial -- no payment, once per shop.
Future<void> _startTrial(BuildContext context, WidgetRef ref, SubscriptionPlan plan) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Start ${plan.name} free?'),
      content: Text(
        plan.isFree
            ? 'Your shop gets ${plan.name} free for ${plan.trialDays} days. Every shop gets one free trial.'
            : 'Your shop gets ${plan.name} free for ${plan.trialDays} days. After that it costs ₹${plan.price.toStringAsFixed(0)} / ${plan.billingCycle}, paid from this page. Every shop gets one free trial.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Start free')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(subscriptionsRepositoryProvider).startTrial(plan.id);
    ref
      ..invalidate(mySubscriptionProvider)
      ..invalidate(merchantEntitlementProvider)
      ..invalidate(myMerchantProvider);
    messenger.showSnackBar(SnackBar(content: Text('${plan.name} started. Free for ${plan.trialDays} days.')));
  } on ValidationAppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.fieldErrors['subscription_plan_id']?.first ?? e.message)));
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
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
          if (s.isTrial && s.trialEndsAt != null)
            DetailRow(label: 'Free trial ends', value: _date(s.trialEndsAt!))
          else if (s.currentPeriodEnd != null)
            DetailRow(label: 'Renews / ends', value: _date(s.currentPeriodEnd!)),
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
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    this.isStalled = false,
    this.isCheaperThanCurrent = false,
    this.nativeCheckout = false,
    this.busy = false,
    this.onSubscribe,
    this.canStartTrial = false,
    this.renewalOpen = false,
    this.isTrial = false,
    this.onStartTrial,
  });

  final SubscriptionPlan plan;
  final bool isCurrent;

  /// BR-43: the plan has a trial and this shop has not used its one trial.
  final bool canStartTrial;

  /// The current plan may be paid for again now (trial, or renewal window).
  final bool renewalOpen;
  final bool isTrial;
  final VoidCallback? onStartTrial;

  /// A subscription exists that points at this plan but never activated
  /// (its last payment failed or was abandoned) -- shown as "Payment
  /// pending" rather than a false "Current", with a Retry action instead
  /// of a dead "Subscribe" button.
  final bool isStalled;

  /// True entitlement downgrades aren't wired into the app yet (they need
  /// no payment at all -- a separate, simpler feature); shown as a hint
  /// pointing at the web rather than a broken in-app action.
  final bool isCheaperThanCurrent;
  final bool nativeCheckout;
  final bool busy;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      borderColor: isCurrent ? AppColors.businessInk : (isStalled ? AppColors.pending : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: textTheme.titleLarge)),
              if (plan.badgeLabel != null && plan.badgeLabel!.isNotEmpty) ...[
                StatusBadge(label: plan.badgeLabel!, tone: AppTone.pending, icon: Icons.auto_awesome_rounded),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (isCurrent)
                const StatusBadge(label: 'Current', tone: AppTone.info)
              else if (isStalled)
                const StatusBadge(label: 'Payment pending', tone: AppTone.pending, icon: Icons.error_outline_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (plan.hasTrial) ...[
            Text('Free for ${plan.trialDays} days', style: textTheme.titleMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
            if (!plan.isFree) Text('then ₹${plan.price.toStringAsFixed(0)} / ${plan.billingCycle}', style: textTheme.bodySmall),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${plan.price.toStringAsFixed(0)}', style: AppTypography.numericFinancialMedium),
                const SizedBox(width: AppSpacing.xs),
                Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xxs), child: Text('/ ${plan.billingCycle}', style: textTheme.bodySmall)),
              ],
            ),
          if (plan.description != null && plan.description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(plan.description!.trim(), style: textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (plan.items.isEmpty)
            Text(plan.couponQuotaMonthly == null ? 'Unlimited coupons' : '${plan.couponQuotaMonthly} coupons / month', style: textTheme.bodyMedium)
          else
            _PlanItems(plan: plan),
          if (canStartTrial) ...[
            const SizedBox(height: AppSpacing.smd),
            AppButton(
              label: 'Start free · ${plan.trialDays} days',
              icon: Icons.card_giftcard_rounded,
              isLoading: busy,
              onPressed: busy ? null : onStartTrial,
            ),
          ] else if (nativeCheckout) ...[
            const SizedBox(height: AppSpacing.smd),
            if (isCurrent && renewalOpen)
              AppButton(
                label: isTrial ? 'Pay & continue' : 'Renew now',
                icon: Icons.workspace_premium_rounded,
                isLoading: busy,
                onPressed: busy ? null : onSubscribe,
              )
            else if (isCurrent)
              const SizedBox.shrink()
            else if (isCheaperThanCurrent)
              Text('Downgrade from the Subscriptions page on the web.', style: AppTypography.caption)
            else if (plan.isFree)
              Text('Your free trial has already been used.', style: AppTypography.caption)
            else
              AppButton(
                label: isStalled ? 'Retry payment' : 'Subscribe',
                icon: isStalled ? Icons.refresh_rounded : Icons.workspace_premium_rounded,
                variant: isStalled ? AppButtonVariant.secondary : AppButtonVariant.primary,
                isLoading: busy,
                onPressed: busy ? null : onSubscribe,
              ),
          ],
        ],
      ),
    );
  }
}

/// What the plan includes, grouped the way the catalogue groups it (BR-43).
class _PlanItems extends StatelessWidget {
  const _PlanItems({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final groups = plan.includedByGroup;
    if (groups.isEmpty) return Text('Nothing included yet.', style: textTheme.bodySmall);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Text(entry.key.toUpperCase(), style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.xxs),
          for (final item in entry.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, size: AppIconSize.sm, color: AppColors.success),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(item.label, style: textTheme.bodyMedium)),
                  if (item.showsValue) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(item.display, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
