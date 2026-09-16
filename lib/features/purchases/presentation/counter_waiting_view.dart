import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/info_box.dart';
import '../../redemptions/application/redemption_detail_provider.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/customer_purchase_request_controller.dart';
import '../application/purchase_detail_provider.dart';

/// Step 3 — the confirmation the customer sees once their bill is sent:
/// an animated tick, who it went to, the amount to hand over and what the
/// coins took off it, and what they earn.
///
/// The request is real the moment this shows (the Purchase row exists), so
/// the tick celebrates that -- but it never claims more than is true: the
/// purchase stays PENDING until the merchant approves it from their own
/// queue, and the live status sits top-right in [CounterStatusActions].
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
    final submitted = state.result;
    final purchaseId = submitted?.id;
    final textTheme = Theme.of(context).textTheme;

    // The refreshed purchase when the customer has checked its status,
    // otherwise the one the submit returned.
    final purchase = purchaseId == null ? null : ref.watch(purchaseDetailProvider(purchaseId)).value ?? submitted;
    final status = purchase?.status ?? 'pending';

    final bill = state.billAmount ?? 0;
    // Once the request exists, the server's own figures replace the
    // estimate this screen was showing a moment ago.
    final discount = redemption?.applied == true ? (redemption?.discountAmount ?? 0) : 0.0;
    final payable = redemption?.applied == true ? (redemption?.amountPayable ?? bill) : bill;

    final settled = _watchSettled();
    final outcome = switch (status) {
      'recorded' => _Outcome.confirmed,
      'rejected' || 'voided' => _Outcome.declined,
      _ => settled ? _Outcome.coinsApplied : _Outcome.sent,
    };

    final resolution = state.resolution;
    final merchantName = resolution?.merchantName ?? purchase?.merchant?.name ?? 'the merchant';
    final branchLine = [resolution?.branchName, resolution?.branchAddressLine].whereType<String>().join(' · ');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(child: _SuccessMark(declined: outcome == _Outcome.declined)),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            outcome.title,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          switch (outcome) {
            _Outcome.sent => 'Waiting for $merchantName to confirm. Nothing is deducted until they do.',
            _Outcome.coinsApplied => 'Your coins have been applied. Pay the amount below at the counter.',
            _Outcome.confirmed => 'Your Town Coins and any Lucky Draw coupons have been added.',
            _Outcome.declined => purchase?.rejectionReason ?? 'No coins or coupons were issued for this bill.',
          },
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.section),
        _AmountHero(
          label: outcome == _Outcome.declined ? 'Bill amount' : 'Amount to pay',
          amount: outcome == _Outcome.declined ? bill : payable,
          discounted: discount > 0 && outcome != _Outcome.declined,
          originalBill: bill,
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailsCard(
          rows: [
            _Detail(label: 'Business', value: merchantName, subValue: branchLine.isEmpty ? null : branchLine),
            _Detail(label: 'Bill amount', value: '₹${bill.toStringAsFixed(2)}', numeric: true),
            if (discount > 0)
              _Detail(
                label: 'Town Coin discount',
                value: '− ₹${discount.toStringAsFixed(2)}',
                subValue: redemption?.coinsRequested != null ? '${redemption!.coinsRequested} Town Coins' : null,
                valueColor: AppColors.success,
                numeric: true,
              ),
            _Detail(label: 'To pay', value: '₹${payable.toStringAsFixed(2)}', numeric: true, emphasised: true),
            _Detail(
              label: 'Coins earned',
              value: switch (outcome) {
                _Outcome.confirmed => '+${purchase?.coinsAwarded ?? 0} Town Coins',
                _Outcome.declined => 'None',
                _ => 'Added once approved',
              },
              valueColor: outcome == _Outcome.confirmed && (purchase?.coinsAwarded ?? 0) > 0 ? AppColors.success : null,
            ),
            if (outcome == _Outcome.confirmed && (purchase?.couponsIssued ?? 0) > 0)
              _Detail(
                label: 'Lucky Draw coupons',
                value: '${purchase!.couponsIssued} coupon${purchase.couponsIssued == 1 ? '' : 's'}',
              ),
            if (purchaseId != null)
              _Detail(
                label: 'Reference',
                value: '#$purchaseId',
                subValue: purchase?.createdAt != null ? formatDateTime(purchase!.createdAt!) : null,
              ),
          ],
        ),
        if (redemption != null && !redemption.applied && redemption.reason != null) ...[
          const SizedBox(height: AppSpacing.md),
          InfoBox(
            tone: AppTone.pending,
            icon: Icons.info_outline_rounded,
            message: 'No coins were used on this bill. ${redemption.reason!}',
          ),
        ],
        if (redemption?.pin != null && !settled && outcome == _Outcome.sent) ...[
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
            label: settled || outcome != _Outcome.sent ? 'Done' : 'View this purchase',
            variant: settled || outcome != _Outcome.sent ? AppButtonVariant.primary : AppButtonVariant.secondary,
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

enum _Outcome {
  sent('Bill sent successfully'),
  coinsApplied('Coins applied'),
  confirmed('Purchase confirmed'),
  declined('Bill declined');

  const _Outcome(this.title);

  final String title;
}

/// The top-right of the counter screen: the purchase's live status, and a
/// refresh that re-checks it (and the coin half, when there is one).
class CounterStatusActions extends ConsumerWidget {
  const CounterStatusActions({required this.state, super.key});

  final CustomerPurchaseRequestState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseId = state.result?.id;
    if (purchaseId == null) return const SizedBox.shrink();

    final detail = ref.watch(purchaseDetailProvider(purchaseId));
    final status = detail.value?.status ?? state.result!.status;
    final checking = detail.isLoading;

    final (label, background, foreground) = switch (status) {
      'recorded' => ('Confirmed', AppColors.successBg, AppColors.success),
      'rejected' => ('Rejected', AppColors.errorBg, AppColors.error),
      'voided' => ('Voided', AppColors.errorBg, AppColors.error),
      'disputed' => ('Disputed', AppColors.pendingBg, AppColors.pending),
      _ => ('Pending', AppColors.pendingBg, AppColors.pending),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Status: $label',
          liveRegion: true,
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.badgeLabel.copyWith(color: foreground, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh status',
          onPressed: checking
              ? null
              : () {
                  ref.invalidate(purchaseDetailProvider(purchaseId));
                  final redemptionId = state.redemption?.id;
                  if (redemptionId != null) ref.invalidate(redemptionDetailProvider(redemptionId));
                },
          icon: checking
              ? const SizedBox.square(dimension: AppIconSize.md, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

/// A big tick that pops in and draws itself, over a soft halo -- or a cross
/// for a declined bill. Shows its finished state straight away when the
/// platform asks for reduced motion.
class _SuccessMark extends StatefulWidget {
  const _SuccessMark({required this.declined});

  final bool declined;

  @override
  State<_SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<_SuccessMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  static const _size = 112.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.declined ? AppColors.error : AppColors.success;
    final background = widget.declined ? AppColors.errorBg : AppColors.successBg;

    final pop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: Curves.elasticOut),
    );
    final draw = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    final halo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.8, curve: Curves.easeOut),
    );

    return Semantics(
      label: widget.declined ? 'Declined' : 'Success',
      image: true,
      child: SizedBox.square(
        dimension: _size + AppSpacing.xl,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.7 + 0.3 * halo.value,
                child: Container(
                  width: _size + AppSpacing.xl,
                  height: _size + AppSpacing.xl,
                  decoration: BoxDecoration(
                    color: background.withValues(alpha: 0.6 * halo.value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.scale(
                scale: pop.value,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _MarkPainter(progress: draw.value, declined: widget.declined),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.progress, required this.declined});

  final double progress;
  final bool declined;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = AppColors.onCrimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final path = Path();
    if (declined) {
      path
        ..moveTo(w * 0.35, h * 0.35)
        ..lineTo(w * 0.65, h * 0.65)
        ..moveTo(w * 0.65, h * 0.35)
        ..lineTo(w * 0.35, h * 0.65);
    } else {
      path
        ..moveTo(w * 0.29, h * 0.52)
        ..lineTo(w * 0.44, h * 0.66)
        ..lineTo(w * 0.72, h * 0.37);
    }

    // Draw only the first `progress` of the stroke's total length.
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * math.min(progress, 1);
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final length = math.min(metric.length, remaining);
      canvas.drawPath(metric.extractPath(0, length), paint);
      remaining -= length;
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.declined != declined;
}

/// The figure the customer hands over, with the original bill struck
/// through when coins took something off it.
class _AmountHero extends StatelessWidget {
  const _AmountHero({required this.label, required this.amount, required this.discounted, required this.originalBill});

  final String label;
  final double amount;
  final bool discounted;
  final double originalBill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${amount.toStringAsFixed(2)}',
              style: AppTypography.numericFinancialLarge.copyWith(
                color: discounted ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ),
          if (discounted) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '₹${originalBill.toStringAsFixed(2)}',
              style: AppTypography.caption.copyWith(decoration: TextDecoration.lineThrough),
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail {
  const _Detail({
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor,
    this.numeric = false,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final String? subValue;
  final Color? valueColor;
  final bool numeric;
  final bool emphasised;
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows});

  final List<_Detail> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: row.emphasised
                        ? textTheme.titleSmall
                        : textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          row.value,
                          textAlign: TextAlign.end,
                          style:
                              (row.numeric
                                      ? (row.emphasised
                                            ? AppTypography.numericFinancialSmall
                                            : AppTypography.numericFinancialInline)
                                      : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
                                            const TextStyle())
                                  .copyWith(color: row.valueColor),
                        ),
                        if (row.subValue != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(row.subValue!, textAlign: TextAlign.end, style: AppTypography.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, letterSpacing: revealed ? 1.5 : null),
            ),
          ],
        ),
      ),
    );
  }
}
