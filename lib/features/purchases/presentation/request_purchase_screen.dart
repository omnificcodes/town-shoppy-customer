import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/customer_purchase_request_controller.dart';
import '../data/models/merchant_purchase_qr_resolution.dart';

/// Method 1, step 2 — shown immediately after ScanMerchantQrScreen resolves
/// the scanned token. Same "one scrolling form, no paged wizard" shape as
/// RedemptionInitiationScreen's `_RedemptionForm` (there is no real backend
/// state machine for these client-side steps -- only "not yet submitted"
/// and "submitting" exist before a genuine `Purchase` row is created).
class RequestPurchaseScreen extends ConsumerStatefulWidget {
  const RequestPurchaseScreen({super.key});

  @override
  ConsumerState<RequestPurchaseScreen> createState() => _RequestPurchaseScreenState();
}

class _RequestPurchaseScreenState extends ConsumerState<RequestPurchaseScreen> {
  final _amountController = TextEditingController();
  bool _amountTouched = false;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Request purchase')),
      body: SafeArea(
        child: switch (state) {
          CustomerPurchaseRequestState(isResolving: true) =>
            const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LoadingSkeletonCard()),
          CustomerPurchaseRequestState(resolveError: final error?) => ErrorState(
              error: error,
              onRetry: () => context.pop(),
            ),
          CustomerPurchaseRequestState(resolution: final resolution?) => _RequestForm(
              resolution: resolution,
              state: state,
              controller: controller,
              amountController: _amountController,
              amountTouched: _amountTouched,
              onAmountTouched: () => setState(() => _amountTouched = true),
            ),
          _ => const SizedBox.shrink(),
        },
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

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Row(
            children: [
              Icon(Icons.storefront_rounded, color: AppColors.orange),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resolution.merchantName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [resolution.branchName, resolution.branchAddressLine].whereType<String>().join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Enter bill amount', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Bill amount',
          controller: amountController,
          prefixText: '₹ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_DecimalAmountFormatter()],
          style: Theme.of(context).textTheme.headlineSmall,
          errorText: amountError,
          onChanged: (value) {
            onAmountTouched();
            controller.setBillAmount(value);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "The merchant will review and approve this before you receive Town Coins and Lucky Draw coupons.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if (state.submitError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.submitError!.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Submit request',
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? () => controller.submit() : null,
        ),
        const SizedBox(height: AppSpacing.lg),
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
