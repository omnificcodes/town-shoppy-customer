import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/state_panel.dart';
import '../application/customer_purchase_request_controller.dart';
import '../data/models/merchant_purchase_qr_resolution.dart';
import '../data/models/purchase_request_target.dart';
import 'counter_waiting_view.dart';

/// Method 1, step 2 — shown immediately after ScanMerchantQrScreen decodes
/// a token; resolves it here (in [initState], before this widget's first
/// [build] ever watches [customerPurchaseRequestControllerProvider]) so the
/// autoDispose controller always has an active listener from the moment it
/// starts resolving -- it is never left to be torn down mid-flight by a
/// navigation the way "resolve on the previous screen, read the result on
/// this one" would be.
///
/// Three client-side steps: type the bill and see what the coins take off
/// it, check the final figure, then wait at the counter while the merchant
/// settles. Only the last has anything behind it on the backend.
class RequestPurchaseScreen extends ConsumerStatefulWidget {
  const RequestPurchaseScreen({required this.target, super.key});

  /// A scanned counter QR, or a merchant chosen from its own profile
  /// ("Pay bill with coins"). The screen is the same from here on; only
  /// the first step differs (resolve the token vs. already known).
  final PurchaseRequestTarget target;

  @override
  ConsumerState<RequestPurchaseScreen> createState() => _RequestPurchaseScreenState();
}

class _RequestPurchaseScreenState extends ConsumerState<RequestPurchaseScreen> {
  final _amountController = TextEditingController();
  bool _amountTouched = false;

  @override
  void initState() {
    super.initState();
    // Deferred a tick: Riverpod forbids mutating a provider's state from
    // inside initState (it's still mid-build). By the time this microtask
    // runs, this widget's own build() has already run and watched the
    // controller below, so the mutation lands on a provider this widget is
    // already listening to.
    Future.microtask(
      () => ref.read(customerPurchaseRequestControllerProvider.notifier).start(widget.target),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerPurchaseRequestControllerProvider);
    final controller = ref.read(customerPurchaseRequestControllerProvider.notifier);

    return AppScaffold(
      title: switch (state.step) {
        CounterStep.waiting => 'At the counter',
        _ => 'Pay with Town Shoppy',
      },
      padded: false,
      actions: state.step == CounterStep.waiting ? [CounterStatusActions(state: state)] : null,
      body: switch (state) {
        // A scan that resolved to nothing usable is not something "Try
        // again" can fix from here -- the only recovery is scanning again,
        // so the single action is an honest "Go back".
        CustomerPurchaseRequestState(resolveError: final error?) => StatePanel(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: AppColors.error,
            title: "We couldn't use that QR code",
            message: error.message,
            action: AppButton(
              label: 'Go back',
              variant: AppButtonVariant.secondary,
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.pop(),
            ),
          ),
        CustomerPurchaseRequestState(resolution: final resolution?) => switch (state.step) {
            CounterStep.waiting => CounterWaitingView(state: state),
            CounterStep.review => _ReviewStep(resolution: resolution, state: state, controller: controller),
            CounterStep.amount => _AmountStep(
                resolution: resolution,
                state: state,
                controller: controller,
                amountController: _amountController,
                amountTouched: _amountTouched,
                onAmountTouched: () => setState(() => _amountTouched = true),
              ),
          },
        // Both "still resolving" and the one frame before initState's
        // microtask kicks off the resolve: the same skeleton, shaped like
        // the form that replaces it (merchant card, then the amount field).
        _ => const _FormSkeleton(),
      },
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.page),
      child: Column(
        children: [
          LoadingSkeletonCard(),
          SizedBox(height: AppSpacing.section),
          LoadingSkeleton(height: AppSize.field, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusControl))),
        ],
      ),
    );
  }
}

/// Who is being paid. Shared by the first two steps so the merchant never
/// disappears from under the numbers.
class _MerchantHeader extends StatelessWidget {
  const _MerchantHeader({required this.resolution});

  final MerchantPurchaseQrResolution resolution;

  @override
  Widget build(BuildContext context) {
    final branchLine = [resolution.branchName, resolution.branchAddressLine].whereType<String>().join(' · ');

    final logoUrl = resolution.logoUrl;

    return Column(
      children: [
        // The shop's own logo when it has one -- the same face the profile
        // shows, so a customer who came from it sees the same shop here.
        Container(
          width: AppSize.avatarLg,
          height: AppSize.avatarLg,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
          child: logoUrl == null
              ? const Icon(Icons.storefront_rounded, color: AppColors.orange, size: AppIconSize.lg)
              : Image.network(
                  logoUrl,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.storefront_rounded, color: AppColors.orange, size: AppIconSize.lg),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('To', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          resolution.merchantName,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (branchLine.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(branchLine, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

/// Step 1 — the bill amount, with the saving appearing under it the moment
/// there is an amount to apply it to.
class _AmountStep extends StatelessWidget {
  const _AmountStep({
    required this.resolution,
    required this.state,
    required this.controller,
    required this.amountController,
    required this.amountTouched,
    required this.onAmountTouched,
  });

  final MerchantPurchaseQrResolution resolution;
  final CustomerPurchaseRequestState state;
  final CustomerPurchaseRequestController controller;
  final TextEditingController amountController;
  final bool amountTouched;
  final VoidCallback onAmountTouched;

  @override
  Widget build(BuildContext context) {
    final amountError = amountTouched && amountController.text.isNotEmpty && state.billAmount == null
        ? 'Enter an amount between ₹0.01 and ₹10,00,000'
        : null;

    final discount = state.estimatedDiscount;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: AppSpacing.md),
        _MerchantHeader(resolution: resolution),
        const SizedBox(height: AppSpacing.section),
        AppTextField(
          label: 'Bill amount',
          controller: amountController,
          autofocus: true,
          prefixText: '₹ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [_DecimalAmountFormatter()],
          style: AppTypography.numericFinancialLarge,
          helperText: 'The total on your bill, before any discount',
          errorText: amountError,
          onChanged: (value) {
            onAmountTouched();
            controller.setBillAmount(value);
          },
          onSubmitted: (_) {
            if (state.canContinue) controller.review();
          },
        ),
        if (discount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Center(child: _SavingsChip(amount: discount, coins: state.estimatedCoins)),
        ],
        if (resolution.canDiscount) ...[
          const SizedBox(height: AppSpacing.md),
          _RedeemToggle(state: state, controller: controller, discountRate: resolution.discountRate!),
        ],
        const SizedBox(height: AppSpacing.section),
        AppButton(
          label: 'Continue',
          icon: Icons.arrow_forward_rounded,
          onPressed: state.canContinue ? controller.review : null,
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }
}

/// The "You save ₹350" pill from the reference flow. Green, quiet, and
/// only ever shown when there is a real figure behind it.
class _SavingsChip extends StatelessWidget {
  const _SavingsChip({required this.amount, this.coins = 0});

  final double amount;

  /// The coins that saving uses; left off the chip when unknown.
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.savings_outlined, size: AppIconSize.sm, color: AppColors.success),
          const SizedBox(width: AppSpacing.xs),
          Text(
            coins > 0 ? 'You save ₹${amount.toStringAsFixed(2)} · $coins coins' : 'You save ₹${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Pay with Town Coins, on or off -- with the balance to pay from and the
/// rule that decides how much of this bill coins can cover.
class _RedeemToggle extends StatelessWidget {
  const _RedeemToggle({required this.state, required this.controller, required this.discountRate});

  final CustomerPurchaseRequestState state;
  final CustomerPurchaseRequestController controller;
  final double discountRate;

  @override
  Widget build(BuildContext context) {
    final available = state.availableCoins;
    final rate = discountRate == discountRate.roundToDouble()
        ? discountRate.toInt().toString()
        : discountRate.toStringAsFixed(1);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pay with Town Coins', style: Theme.of(context).textTheme.titleSmall),
                    if (available != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'You have $available Town Coins',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Switch(value: state.redeem, onChanged: controller.setRedeem),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Coins can cover up to $rate% of this bill, limited by your balance. '
            'Nothing is deducted until the business approves.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

/// Step 2 — the figure the customer hands over, and the arithmetic behind
/// it. Nothing has been created on the backend yet at this point.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.resolution, required this.state, required this.controller});

  final MerchantPurchaseQrResolution resolution;
  final CustomerPurchaseRequestState state;
  final CustomerPurchaseRequestController controller;

  @override
  Widget build(BuildContext context) {
    final bill = state.billAmount ?? 0;
    final discount = state.estimatedDiscount;
    final payable = state.estimatedPayable;
    final hasDiscount = discount > 0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: AppSpacing.md),
        _MerchantHeader(resolution: resolution),
        const SizedBox(height: AppSpacing.section),
        if (hasDiscount) ...[
          Center(
            child: Text(
              '₹${bill.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Center(
          child: Text(
            '₹${payable.toStringAsFixed(2)}',
            style: AppTypography.numericFinancialLarge.copyWith(
              color: hasDiscount ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
        if (hasDiscount) ...[
          const SizedBox(height: AppSpacing.md),
          Center(child: _SavingsChip(amount: discount)),
        ],
        const SizedBox(height: AppSpacing.section),
        AppCard(
          child: Column(
            children: [
              _AmountRow(label: 'Bill amount', value: '₹${bill.toStringAsFixed(2)}'),
              if (hasDiscount) ...[
                const SizedBox(height: AppSpacing.sm),
                _AmountRow(
                  label: 'Town Coin discount',
                  value: '− ₹${discount.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
                if (state.estimatedCoins > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _AmountRow(label: 'Town Coins to use', value: '${state.estimatedCoins}'),
                ],
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1, color: AppColors.border),
              ),
              _AmountRow(label: 'Pay Cash Only', value: '₹${payable.toStringAsFixed(2)}', emphasised: true),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton.icon(
            onPressed: controller.backToAmount,
            icon: const Icon(Icons.edit_outlined, size: AppIconSize.sm),
            label: const Text('Edit amount'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // The discount is an estimate until the server recalculates it from
        // the merchant's own rate and the wallet, so the screen says so
        // rather than presenting it as already agreed.
        InfoBox(
          icon: Icons.info_outline_rounded,
          message: hasDiscount
              ? 'The merchant confirms this at the counter. Your coins are only spent once they do.'
              : 'The merchant reviews this before you receive Town Coins and Lucky Draw coupons.',
        ),
        const SizedBox(height: AppSpacing.section),
        if (state.submitError != null) ...[
          InfoBox(tone: AppTone.error, icon: Icons.error_outline_rounded, message: state.submitError!.message),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          // Sends a request the business approves -- nothing is paid or
          // deducted by this tap alone.
          label: hasDiscount ? 'Pay with Town Coins' : 'Send payment request',
          icon: Icons.lock_outline_rounded,
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? controller.submit : null,
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: emphasised ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: (emphasised ? AppTypography.numericFinancialSmall : AppTypography.numericFinancialInline)
              .copyWith(color: valueColor),
        ),
      ],
    );
  }
}

/// Same formatter as RedemptionInitiationScreen's private
/// `_DecimalAmountFormatter` -- duplicated rather than shared across
/// features for a four-line utility, matching RequestPurchaseRequest's
/// identical `decimal:0,2` rule. The backend remains the authoritative
/// validator.
class _DecimalAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) return oldValue;
    return newValue;
  }
}
