import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../merchants/application/merchant_branches_provider.dart';
import '../../merchants/application/merchant_detail_provider.dart';
import '../../merchants/data/models/merchant.dart';
import '../../merchants/presentation/branch_selector.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/redemption_initiation_controller.dart';

/// Merchant → Branch → Bill amount → Review → Submit, all on one scrolling
/// form rather than a paged wizard — the only real backend states here are
/// "not yet submitted" and "submitting" (everything past that is the actual
/// `Redemption` lifecycle, handed off to `RedemptionVerificationScreen`), so
/// there is no separate state machine to build for these purely client-side
/// steps.
class RedemptionInitiationScreen extends ConsumerStatefulWidget {
  const RedemptionInitiationScreen({super.key, required this.merchantId});

  final int merchantId;

  @override
  ConsumerState<RedemptionInitiationScreen> createState() => _RedemptionInitiationScreenState();
}

class _RedemptionInitiationScreenState extends ConsumerState<RedemptionInitiationScreen> {
  final _amountController = TextEditingController();
  bool _amountTouched = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = redemptionInitiationControllerProvider(widget.merchantId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      final createdId = next.result?.redemption.id;
      if (createdId != null && previous?.result == null) {
        context.pushReplacement('/redemptions/$createdId/verify');
      }
    });

    final merchantAsync = ref.watch(merchantDetailProvider(widget.merchantId));

    return Scaffold(
      appBar: AppBar(title: const Text('Redeem Town Coin')),
      body: SafeArea(
        child: merchantAsync.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LoadingSkeletonCard()),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(merchantDetailProvider(widget.merchantId)),
          ),
          data: (merchant) {
            if (!(merchant.acceptsTownCoin && (merchant.discountRate ?? 0) > 0)) {
              return const EmptyState(
                icon: Icons.block_rounded,
                title: 'Redemption not available',
                message: 'This merchant is not currently accepting Town Coin redemptions.',
              );
            }

            return _RedemptionForm(
              merchant: merchant,
              state: state,
              controller: controller,
              amountController: _amountController,
              amountTouched: _amountTouched,
              onAmountTouched: () => setState(() => _amountTouched = true),
            );
          },
        ),
      ),
    );
  }
}

class _RedemptionForm extends ConsumerWidget {
  const _RedemptionForm({
    required this.merchant,
    required this.state,
    required this.controller,
    required this.amountController,
    required this.amountTouched,
    required this.onAmountTouched,
  });

  final Merchant merchant;
  final RedemptionInitiationState state;
  final RedemptionInitiationController controller;
  final TextEditingController amountController;
  final bool amountTouched;
  final VoidCallback onAmountTouched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(merchantBranchesProvider(merchant.id));

    return branchesAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LoadingSkeletonCard()),
      error: (error, _) => ErrorState(
        error: error is AppException ? error : const UnknownAppException(),
        onRetry: () => ref.invalidate(merchantBranchesProvider(merchant.id)),
      ),
      data: (branches) {
        if (branches.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No branch information available',
            message: 'This merchant has not published a branch location yet.',
          );
        }

        if (branches.length == 1 && state.selectedBranchId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) controller.selectBranch(branches.first.id);
          });
        }

        final amountError = amountTouched && amountController.text.isNotEmpty && state.billAmount == null
            ? 'Enter an amount between ₹0.01 and ₹10,00,000'
            : null;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(merchant.name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Up to ${merchant.discountRate!.toStringAsFixed(merchant.discountRate! % 1 == 0 ? 0 : 1)}% off with Town Coin',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(branches.length > 1 ? 'Select a branch' : 'Branch', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            BranchSelector(
              branches: branches,
              selectedId: state.selectedBranchId,
              onSelected: branches.length > 1 ? controller.selectBranch : null,
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
            const SizedBox(height: AppSpacing.xs),
            _WalletBalanceHint(),
            if (state.selectedBranchId != null && state.billAmount != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Review', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    _ReviewRow('Merchant', merchant.name),
                    _ReviewRow(
                      'Branch',
                      branches.firstWhere((b) => b.id == state.selectedBranchId).name ?? 'Branch',
                    ),
                    _ReviewRow('Bill amount', '₹${state.billAmount!.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(state.error!.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
            ],
            if (state.isSubmitting) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Creating your redemption…',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Submit',
              isLoading: state.isSubmitting,
              onPressed: state.canSubmit ? () => controller.submit() : null,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _WalletBalanceHint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);

    return wallet.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (balance) => Text(
        'You have ${balance.balance} Silver Town Coins available.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Digits, at most one decimal point, at most two decimal places — matches
/// `InitiateRedemptionRequest`'s `decimal:0,2` rule. The backend remains the
/// authoritative validator; this only prevents obviously-invalid keystrokes.
class _DecimalAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) return oldValue;
    return newValue;
  }
}
