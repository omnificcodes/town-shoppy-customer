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

/// Method 1, step 2 — shown immediately after ScanMerchantQrScreen decodes a
/// token; resolves it here (in [initState], before this widget's first
/// [build] ever watches [customerPurchaseRequestControllerProvider]) so the
/// autoDispose controller always has an active listener from the moment it
/// starts resolving -- it is never left to be torn down mid-flight by a
/// navigation the way "resolve on the previous screen, read the result on
/// this one" would be. Same "one scrolling form, no paged wizard" shape as
/// RedemptionInitiationScreen's `_RedemptionForm` (there is no real backend
/// state machine for these client-side steps -- only "not yet submitted"
/// and "submitting" exist before a genuine `Purchase` row is created).
class RequestPurchaseScreen extends ConsumerStatefulWidget {
  const RequestPurchaseScreen({required this.scannedToken, super.key});

  final String scannedToken;

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
      () => ref.read(customerPurchaseRequestControllerProvider.notifier).resolveScannedToken(widget.scannedToken),
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

    ref.listen(customerPurchaseRequestControllerProvider, (previous, next) {
      final createdId = next.result?.id;
      if (createdId != null && previous?.result == null) {
        context.pushReplacement('/purchases/$createdId');
      }
    });

    return AppScaffold(
      title: 'Request purchase',
      padded: false,
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
        CustomerPurchaseRequestState(resolution: final resolution?) => _RequestForm(
            resolution: resolution,
            state: state,
            controller: controller,
            amountController: _amountController,
            amountTouched: _amountTouched,
            onAmountTouched: () => setState(() => _amountTouched = true),
          ),
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

class _RequestForm extends StatelessWidget {
  const _RequestForm({
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
    final branchLine = [resolution.branchName, resolution.branchAddressLine].whereType<String>().join(' · ');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront_rounded, color: AppColors.orange, size: AppIconSize.lg),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resolution.merchantName, style: Theme.of(context).textTheme.titleMedium),
                    if (branchLine.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(branchLine, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppTextField(
          label: 'Bill amount',
          controller: amountController,
          autofocus: true,
          prefixText: '₹ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [_DecimalAmountFormatter()],
          style: AppTypography.numericFinancialMedium,
          helperText: 'The total on your bill, before any discount',
          errorText: amountError,
          onChanged: (value) {
            onAmountTouched();
            controller.setBillAmount(value);
          },
          onSubmitted: (_) {
            if (state.canSubmit) controller.submit();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        const InfoBox(
          icon: Icons.info_outline_rounded,
          message: 'The merchant will review and approve this before you receive Town Coins and Lucky Draw coupons.',
        ),
        const SizedBox(height: AppSpacing.section),
        if (state.submitError != null) ...[
          InfoBox(tone: AppTone.error, icon: Icons.error_outline_rounded, message: state.submitError!.message),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          label: 'Submit request',
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? () => controller.submit() : null,
        ),
        const SizedBox(height: AppSpacing.section),
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
