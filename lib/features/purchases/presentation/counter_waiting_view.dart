import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/info_box.dart';
import '../../redemptions/application/redemption_detail_provider.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/customer_purchase_request_controller.dart';

/// Step 3 — what the customer holds up at the counter: the amount to hand
/// over, what it was before the coins came off, and a quiet PIN.
///
/// The PIN is deliberately small. The merchant settles this from their own
/// screen, where the request has already appeared; the PIN exists for the
/// one case where they want proof the person in front of them really
/// raised it. Making it the hero of the screen would teach customers to
/// read a code aloud on every purchase, which is exactly the habit that
/// makes a code worth stealing.
class CounterWaitingView extends ConsumerStatefulWidget {
  const CounterWaitingView({required this.state, super.key});

  final CustomerPurchaseRequestState state;

  @override
  ConsumerState<CounterWaitingView> createState() => _CounterWaitingViewState();
}

class _CounterWaitingViewState extends ConsumerState<CounterWaitingView> {
  static const _pollInterval = Duration(seconds: 4);

  Timer? _pollTimer;
  bool _pinRevealed = false;

  int? get _redemptionId => widget.state.redemption?.id;

  @override
  void initState() {
    super.initState();
    if (_redemptionId != null) _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Same interval and mechanism as RedemptionVerificationScreen -- the
    // customer is standing at a counter waiting for someone to tap a
    // button, so this is a short-lived poll, stopped the moment it settles.
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      final id = _redemptionId;
      if (id != null) ref.invalidate(redemptionDetailProvider(id));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final redemption = state.redemption;
    final purchaseId = state.result?.id;

    final bill = state.billAmount ?? 0;
    // Once the request exists, the server's own figures replace the
    // estimate this screen was showing a moment ago.
    final discount = redemption?.applied == true ? (redemption?.discountAmount ?? 0) : 0.0;
    final payable = redemption?.applied == true ? (redemption?.amountPayable ?? bill) : bill;

    final settled = _watchSettled();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: AppSpacing.md),
        _StatusHeader(settled: settled),
        const SizedBox(height: AppSpacing.section),
        Center(child: Text('Show this to the counter', style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            '₹${payable.toStringAsFixed(2)}',
            style: AppTypography.numericFinancialLarge.copyWith(
              color: discount > 0 ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppCard(
          child: Column(
            children: [
              _Row(label: 'Bill amount', value: '₹${bill.toStringAsFixed(2)}'),
              if (discount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _Row(
                  label: 'Town Coin discount',
                  value: '− ₹${discount.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
                if (redemption?.coinsRequested != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${redemption!.coinsRequested} Town Coins',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1, color: AppColors.border),
              ),
              _Row(label: 'To pay', value: '₹${payable.toStringAsFixed(2)}', emphasised: true),
            ],
          ),
        ),
        if (redemption != null && !redemption.applied && redemption.reason != null) ...[
          const SizedBox(height: AppSpacing.md),
          InfoBox(
            tone: AppTone.pending,
            icon: Icons.info_outline_rounded,
            message: 'No coins were used on this bill. ${redemption.reason!}',
          ),
        ],
        if (redemption?.pin != null && !settled) ...[
          const SizedBox(height: AppSpacing.md),
          _PinRow(
            pin: redemption!.pin!,
            revealed: _pinRevealed,
            onToggle: () => setState(() => _pinRevealed = !_pinRevealed),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        if (purchaseId != null)
          AppButton(
            label: settled ? 'Done' : 'View this purchase',
            variant: settled ? AppButtonVariant.primary : AppButtonVariant.secondary,
            onPressed: () => context.pushReplacement('/purchases/$purchaseId'),
          ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }

  /// True once the merchant has settled the coin half. Without a
  /// redemption there is nothing to watch, and the purchase stays pending
  /// until the merchant approves it from their own queue.
  ///
  /// Reads only. Everything that REACTS to settling -- stopping the poll,
  /// refreshing the wallet -- happens in the listener below, because
  /// touching a provider from inside build() is exactly what Riverpod
  /// refuses to allow.
  bool _watchSettled() {
    final id = _redemptionId;
    if (id == null) return false;

    ref.listen(redemptionDetailProvider(id), (previous, next) {
      if (next.value?.status != 'settled') return;

      _stopPolling();
      // The coins have actually left the wallet now.
      ref.invalidate(walletControllerProvider);
    });

    return ref.watch(redemptionDetailProvider(id)).value?.status == 'settled';
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.settled});

  final bool settled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: AppSize.avatarLg,
          height: AppSize.avatarLg,
          decoration: BoxDecoration(
            color: settled ? AppColors.successBg : AppColors.pendingBg,
            shape: BoxShape.circle,
          ),
          child: settled
              ? const Icon(Icons.check_rounded, color: AppColors.success, size: AppIconSize.lg)
              : const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pending),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          settled ? 'Confirmed by the merchant' : 'Waiting for the merchant',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          settled
              ? 'Your coins have been applied. Pay the amount below.'
              : 'They can see this on their screen. Nothing is deducted until they confirm.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The PIN, kept small and hidden until asked for -- see this file's own
/// docblock for why it is not the hero of this screen.
class _PinRow extends StatelessWidget {
  const _PinRow({required this.pin, required this.revealed, required this.onToggle});

  final String pin;
  final bool revealed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onToggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: AppIconSize.sm,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              revealed ? 'PIN $pin' : 'Show PIN if the merchant asks',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: revealed ? 1.5 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor, this.emphasised = false});

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
        Text(label, style: emphasised ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium),
        Text(
          value,
          style: (emphasised ? AppTypography.numericFinancialSmall : AppTypography.numericFinancialInline)
              .copyWith(color: valueColor),
        ),
      ],
    );
  }
}
