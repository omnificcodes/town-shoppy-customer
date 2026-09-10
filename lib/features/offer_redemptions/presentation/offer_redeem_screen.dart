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
import '../../offers/application/offer_detail_provider.dart';
import '../../offers/data/models/offer.dart';
import '../../wallet/application/wallet_controller.dart';
import '../../wallet/data/models/silver_wallet_balance.dart';
import '../application/offer_redemption_request_controller.dart';

/// Offer → Bill amount → Review → Submit, one scrolling form -- same
/// "no separate wizard state, the only real backend states are what the
/// `OfferRedemption` lifecycle already tracks" reasoning as
/// `RedemptionInitiationScreen`. No branch picker (the backend accepts an
/// optional `branch_id`, but the design brief calls for the merchant to
/// approve at whichever counter the customer is at, not for the customer
/// to pre-declare one) and no OTP -- the merchant's approve/reject
/// decision is the entire verification step.
class OfferRedeemScreen extends ConsumerStatefulWidget {
  const OfferRedeemScreen({super.key, required this.offerId});

  final int offerId;

  @override
  ConsumerState<OfferRedeemScreen> createState() => _OfferRedeemScreenState();
}

class _OfferRedeemScreenState extends ConsumerState<OfferRedeemScreen> {
  final _amountController = TextEditingController();
  bool _amountTouched = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = offerRedemptionRequestControllerProvider(widget.offerId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      final createdId = next.result?.id;
      if (createdId != null && previous?.result == null) {
        context.pushReplacement('/offer-redemptions/$createdId');
      }
    });

    final offerAsync = ref.watch(offerDetailProvider(widget.offerId));

    return AppScaffold(
      title: 'Redeem with Town Coin',
      padded: false,
      body: offerAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.page), child: LoadingSkeletonCard()),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(offerDetailProvider(widget.offerId)),
        ),
        data: (offer) {
          if (!offer.isCoinRedeemable) {
            return const EmptyState(
              icon: Icons.block_rounded,
              title: 'Not redeemable with Town Coin',
              message: 'This offer does not have a Town Coin discount set up.',
            );
          }

          return _OfferRedeemForm(
            offer: offer,
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

class _OfferRedeemForm extends ConsumerWidget {
  const _OfferRedeemForm({
    required this.offer,
    required this.state,
    required this.controller,
    required this.amountController,
    required this.amountTouched,
    required this.onAmountTouched,
  });

  final Offer offer;
  final OfferRedemptionRequestState state;
  final OfferRedemptionRequestController controller;
  final TextEditingController amountController;
  final bool amountTouched;
  final VoidCallback onAmountTouched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final amountError = amountTouched && amountController.text.isNotEmpty && state.billAmount == null
        ? 'Enter an amount between ₹0.01 and ₹10,00,000'
        : null;
    final rateLabel = _formatRate(offer.coinDiscountRate!);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(offer.merchantName, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                offer.applicableItem != null
                    ? 'Up to $rateLabel% off with Town Coin, on ${offer.applicableItem}'
                    : 'Up to $rateLabel% off with Town Coin',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
          errorText: amountError,
          onChanged: (value) {
            onAmountTouched();
            controller.setBillAmount(value);
          },
          onSubmitted: (_) {
            if (state.canSubmit) controller.submit();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _WalletBalanceHint(wallet: wallet, onRetry: () => ref.invalidate(walletControllerProvider)),
        if (state.billAmount != null) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Review', subtitle: 'What you are about to request'),
          const SizedBox(height: AppSpacing.sm),
          _ReviewCard(offer: offer, billAmount: state.billAmount!),
        ],
        const SizedBox(height: AppSpacing.section),
        const InfoBox(
          tone: AppTone.info,
          icon: Icons.info_outline_rounded,
          message: 'No coins are deducted now. The merchant reviews and approves this request at the counter.',
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          InfoBox(tone: AppTone.error, icon: Icons.error_outline_rounded, message: state.error!.message),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Request redemption',
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? () => controller.submit() : null,
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }
}

/// Same up-front figure `OfferRedemptionService::request()` computes
/// server-side (`min(billAmount * rate / 100, billAmount)`) -- shown here
/// so the customer sees it before submitting, not only after.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.offer, required this.billAmount});

  final Offer offer;
  final double billAmount;

  @override
  Widget build(BuildContext context) {
    final rate = offer.coinDiscountRate!;
    final discount = _roundMoney((billAmount * rate / 100).clamp(0, billAmount));
    final rateLabel = _formatRate(rate);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(label: 'Offer', value: offer.title),
          DetailRow(label: 'Bill amount', value: '₹${billAmount.toStringAsFixed(2)}'),
          DetailRow(
            label: 'Discount requested',
            child: Text('₹${discount.toStringAsFixed(2)}', style: AppTypography.numericFinancialSmall, textAlign: TextAlign.end),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Up to $rateLabel% of your bill, capped by your coin balance at approval time. The merchant confirms the exact amount.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  double _roundMoney(num value) => (value * 100).round() / 100;
}

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

/// Digits, at most one decimal point, at most two decimal places -- matches
/// `RequestOfferRedemptionRequest`'s `decimal:0,2` rule.
class _DecimalAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) return oldValue;
    return newValue;
  }
}
