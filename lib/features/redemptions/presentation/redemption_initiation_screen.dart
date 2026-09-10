import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../merchants/application/merchant_branches_provider.dart';
import '../../merchants/application/merchant_detail_provider.dart';
import '../../merchants/data/models/merchant.dart';
import '../../merchants/data/models/merchant_branch_ref.dart';
import '../../merchants/presentation/branch_selector.dart';
import '../../wallet/application/wallet_controller.dart';
import '../../wallet/data/models/silver_wallet_balance.dart';
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

    return AppScaffold(
      title: 'Redeem Town Coin',
      padded: false,
      body: merchantAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.page), child: LoadingSkeletonCard()),
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
    );
  }
}

class _RedemptionForm extends ConsumerStatefulWidget {
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
  ConsumerState<_RedemptionForm> createState() => _RedemptionFormState();
}

class _RedemptionFormState extends ConsumerState<_RedemptionForm> {
  bool _autoSelectScheduled = false;

  /// Auto-selects when a merchant has exactly one branch (section 6: "avoid
  /// unnecessary friction"). Scheduled exactly once, after the frame in
  /// which the branches first arrive -- never as a bare side effect on
  /// every build, and never a state mutation during build.
  void _scheduleAutoSelect(List<MerchantBranchRef> branches) {
    if (_autoSelectScheduled || branches.length != 1 || widget.state.selectedBranchId != null) return;
    _autoSelectScheduled = true;
    final branchId = branches.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.selectBranch(branchId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final merchant = widget.merchant;
    final state = widget.state;
    final controller = widget.controller;
    final branchesAsync = ref.watch(merchantBranchesProvider(merchant.id));
    final wallet = ref.watch(walletControllerProvider);

    return branchesAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.page), child: LoadingSkeletonCard()),
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

        _scheduleAutoSelect(branches);

        final amountError = widget.amountTouched && widget.amountController.text.isNotEmpty && state.billAmount == null
            ? 'Enter an amount between ₹0.01 and ₹10,00,000'
            : null;
        final balance = switch (wallet) {
          AsyncData(:final value) => value,
          _ => null,
        };
        // The backend rejects an initiation that would redeem zero coins
        // (RedemptionService::initiate) -- surface that before the tap.
        final hasNoCoins = balance != null && balance.balance <= 0;
        final canSubmit = state.canSubmit && !hasNoCoins;
        final rateLabel = _formatRate(merchant.discountRate!);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(merchant.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Up to $rateLabel% off with Town Coin', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SectionHeader(title: branches.length > 1 ? 'Select a branch' : 'Branch'),
            const SizedBox(height: AppSpacing.sm),
            BranchSelector(
              branches: branches,
              selectedId: state.selectedBranchId,
              onSelected: branches.length > 1 ? controller.selectBranch : null,
            ),
            const SizedBox(height: AppSpacing.section),
            AppTextField(
              label: 'Bill amount',
              controller: widget.amountController,
              autofocus: true,
              prefixText: '₹ ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [_DecimalAmountFormatter()],
              style: AppTypography.numericFinancialMedium,
              errorText: amountError,
              onChanged: (value) {
                widget.onAmountTouched();
                controller.setBillAmount(value);
              },
              onSubmitted: (_) {
                if (canSubmit) controller.submit();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _WalletBalanceHint(wallet: wallet, onRetry: () => ref.invalidate(walletControllerProvider)),
            if (state.selectedBranchId != null && state.billAmount != null) ...[
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Review', subtitle: 'What you are about to redeem'),
              const SizedBox(height: AppSpacing.sm),
              _ReviewCard(
                merchantName: merchant.name,
                branchName: branches.firstWhere((b) => b.id == state.selectedBranchId).name ?? 'Branch',
                billAmount: state.billAmount!,
                discountRate: merchant.discountRate!,
                balance: balance,
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            if (hasNoCoins) ...[
              const InfoBox(
                tone: AppTone.error,
                icon: Icons.error_outline_rounded,
                title: 'No coins to redeem',
                message: 'You have no Town Coins right now, so there is nothing to redeem on this bill. Earn coins on your next purchase and try again.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.error != null) ...[
              InfoBox(tone: AppTone.error, icon: Icons.error_outline_rounded, message: state.error!.message),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: 'Redeem coins',
              isLoading: state.isSubmitting,
              onPressed: canSubmit ? () => controller.submit() : null,
            ),
            const SizedBox(height: AppSpacing.section),
          ],
        );
      },
    );
  }
}

/// The figures the customer is actually deciding on. The discount is
/// derivable here (bill × merchant rate, capped at the bill and at the
/// wallet's rupee value -- the same two caps `RedemptionCalculator` applies
/// server-side); the coin count is not, because the coin-to-rupee rate is
/// backend configuration this client never receives. So it says so instead
/// of guessing.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.merchantName,
    required this.branchName,
    required this.billAmount,
    required this.discountRate,
    required this.balance,
  });

  final String merchantName;
  final String branchName;
  final double billAmount;
  final double discountRate;
  final SilverWalletBalance? balance;

  @override
  Widget build(BuildContext context) {
    final merchantCap = _roundMoney(math.min(billAmount * discountRate / 100, billAmount));
    final walletCap = balance?.balanceInrEquivalent;
    final limitedByBalance = walletCap != null && walletCap < merchantCap;
    final discount = limitedByBalance ? _roundMoney(walletCap) : merchantCap;
    final rateLabel = _formatRate(discountRate);

    final explanation = limitedByBalance
        ? 'Up to $rateLabel% of your bill, limited by your coin balance (≈ ₹${walletCap.toStringAsFixed(2)}). '
            'Exact coins are confirmed by the merchant at verification.'
        : 'Up to $rateLabel% of your bill. Exact coins are confirmed by the merchant at verification.';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(label: 'Merchant', value: merchantName),
          DetailRow(label: 'Branch', value: branchName),
          DetailRow(label: 'Bill amount', value: '₹${billAmount.toStringAsFixed(2)}'),
          DetailRow(
            label: 'Discount',
            child: Text('₹${discount.toStringAsFixed(2)}', style: AppTypography.numericFinancialSmall, textAlign: TextAlign.end),
          ),
          const DetailRow(label: 'Coins to be used', value: 'Confirmed at verification'),
          const SizedBox(height: AppSpacing.xs),
          Text(explanation, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  double _roundMoney(double value) => (value * 100).round() / 100;
}

/// One line under the amount field: how many coins the customer has to
/// spend. Loading shows a skeleton (not nothing), an error gets an inline
/// retry -- the figure matters for the decision, so it must not silently
/// vanish.
class _WalletBalanceHint extends StatelessWidget {
  const _WalletBalanceHint({required this.wallet, required this.onRetry});

  final AsyncValue<SilverWalletBalance> wallet;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (wallet) {
      AsyncData(:final value) => Text(
          'You have ${value.balance} Town Coins (≈ ₹${value.balanceInrEquivalent.toStringAsFixed(2)}) available.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      AsyncError() => InfoBox(
          tone: AppTone.error,
          icon: Icons.cloud_off_rounded,
          message: "We couldn't load your coin balance.",
          action: AppButton(
            label: 'Retry',
            variant: AppButtonVariant.text,
            size: AppButtonSize.sm,
            expand: false,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ),
      _ => const LoadingSkeleton(width: 220, height: AppIconSize.sm),
    };
  }
}

String _formatRate(double rate) => rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1);

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
