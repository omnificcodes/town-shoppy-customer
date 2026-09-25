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
/// There is no code for the customer to show. Scanning the counter QR is
/// what proved they are at this counter, and the merchant approves the bill
/// with one tap from their own queue (`counter_confirm`, in this app and in
/// the merchant web portal alike). The API still returns a PIN with a coin
/// redemption, and a merchant can still choose to type one, but nothing
/// needs it, so it is no longer shown: a code on this screen read as an OTP
/// the customer had to hand over.
class CounterWaitingView extends ConsumerStatefulWidget {
  const CounterWaitingView({required this.state, super.key});

  final CustomerPurchaseRequestState state;

  @override
  ConsumerState<CounterWaitingView> createState() => _CounterWaitingViewState();
}

class _CounterWaitingViewState extends ConsumerState<CounterWaitingView> {
  static const _pollInterval = Duration(seconds: 4);

  Timer? _pollTimer;

  int? get _purchaseId => widget.state.result?.id;

  @override
  void initState() {
    super.initState();
    if (_purchaseId != null) _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// The customer is standing at a counter waiting for someone to tap
  /// Approve, so the screen checks the bill itself every few seconds and
  /// updates the moment the business decides -- no refresh needed. Stopped
  /// as soon as the bill is approved or rejected.
  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      final id = _purchaseId;
      if (id != null) ref.invalidate(purchaseDetailProvider(id));
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

    if (purchaseId != null) {
      ref.listen(purchaseDetailProvider(purchaseId), (previous, next) {
        final status = next.value?.status;
        if (status == null || status == 'pending') return;
        _stopPolling();
        // Coins may have left the wallet, and the bill's reward arrived.
        if (status == 'recorded') ref.invalidate(walletControllerProvider);
      });
    }

    // The latest the server has said about this bill, or the submit's own
    // answer until the first check comes back.
    final purchase = purchaseId == null ? null : ref.watch(purchaseDetailProvider(purchaseId)).value ?? submitted;
    final status = purchase?.status ?? 'pending';

    final bill = state.billAmount ?? 0;
    // The server's own coin figures, never the estimate this flow showed
    // before sending. `coin_payment` on the bill is the source; the submit's
    // redemption block covers an API too old to send it.
    final coinPayment = purchase?.coinPayment;
    final coinsRequested = coinPayment?.coins ?? (redemption?.applied == true ? redemption?.coinsRequested : null);
    final coinsSettled = coinPayment?.settled ?? false;
    final requestedDiscount = coinPayment?.discountAmount ?? (redemption?.applied == true ? redemption?.discountAmount ?? 0 : 0.0);

    final outcome = switch (status) {
      'recorded' => _Outcome.confirmed,
      'rejected' || 'voided' => _Outcome.declined,
      _ => coinsSettled ? _Outcome.coinsApplied : _Outcome.sent,
    };

    // Only coins that were actually deducted count as saved. An approved
    // bill whose coins did not settle saved nothing, and says so.
    final coinsUsed = outcome == _Outcome.declined
        ? false
        : outcome == _Outcome.confirmed || outcome == _Outcome.coinsApplied
        ? coinsSettled
        : (coinsRequested ?? 0) > 0;
    final discount = coinsUsed ? requestedDiscount : 0.0;
    final payable = bill - discount;
    final coinsNotDeducted = outcome == _Outcome.confirmed && coinPayment != null && !coinsSettled;

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
            _Outcome.sent => 'Waiting for $merchantName to approve. Nothing is deducted until they do.',
            _Outcome.coinsApplied => 'Your coins have been applied. Pay the amount below at the counter.',
            _Outcome.confirmed => 'Your Town Coins and any Lucky Draw coupons have been added.',
            _Outcome.declined => [
              'Your Town Coins were not deducted.',
              if (purchase?.rejectionReason case final reason? when reason.trim().isNotEmpty) reason.trim(),
            ].join(' '),
          },
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.section),
        // Once the bill is approved or declined there is nothing left to
        // pay, so the hero states the bill itself; the saving has its own
        // tile below.
        _AmountHero(
          label: switch (outcome) {
            _Outcome.confirmed => 'Bill paid',
            _Outcome.declined => 'Bill amount',
            _ => 'Amount to pay',
          },
          amount: outcome.isFinal ? bill : payable,
          discounted: discount > 0 && !outcome.isFinal,
          originalBill: bill,
        ),
        const SizedBox(height: AppSpacing.md),
        _SavedAndEarned(
          saved: discount,
          savedLabel: outcome == _Outcome.sent ? 'You save' : 'You saved',
          savedCaption: switch (outcome) {
            _Outcome.declined => 'No coins deducted',
            _Outcome.sent when coinsUsed => '${coinsRequested ?? 0} Town Coins to be used',
            _ when coinsUsed => '${coinsRequested ?? 0} Town Coins used',
            _ => 'No coins used on this bill',
          },
          coins: switch (outcome) {
            _Outcome.confirmed => purchase?.coinsAwarded ?? 0,
            _Outcome.declined => 0,
            _ => purchase?.expectedCoins,
          },
          earnedLabel: outcome == _Outcome.confirmed || outcome == _Outcome.declined ? 'You earned' : "You'll earn",
          earnedCaption: switch (outcome) {
            _Outcome.confirmed => 'Added to your wallet',
            _Outcome.declined => 'Not issued',
            _ => 'Credited once approved',
          },
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
                subValue: coinsRequested != null ? '$coinsRequested Town Coins' : null,
                valueColor: AppColors.success,
                numeric: true,
              ),
            _Detail(
              label: outcome == _Outcome.confirmed ? 'Paid at the counter' : 'To pay',
              value: '₹${payable.toStringAsFixed(2)}',
              numeric: true,
              emphasised: true,
            ),
            if (outcome == _Outcome.confirmed && (purchase?.couponsIssued ?? 0) > 0)
              _Detail(
                label: 'Lucky Draw coupons',
                value: '${purchase!.couponsIssued} coupon${purchase.couponsIssued == 1 ? '' : 's'}',
              ),
            if (purchase != null)
              _Detail(
                label: 'Transaction ID',
                value: purchase.reference,
                subValue: purchase.createdAt != null ? formatDateTime(purchase.createdAt!) : null,
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
        // Approved, but the coins never left the wallet -- say so plainly
        // rather than let the bill read as a coin payment.
        if (coinsNotDeducted) ...[
          const SizedBox(height: AppSpacing.md),
          const InfoBox(
            tone: AppTone.pending,
            icon: Icons.info_outline_rounded,
            message: 'No Town Coins were deducted for this bill.',
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        if (outcome == _Outcome.confirmed)
          // Approved: the journey is over, so back to the app itself rather
          // than into this purchase's record.
          AppButton(label: 'Continue', onPressed: () => context.go('/home'))
        else if (purchaseId != null)
          AppButton(
            label: outcome != _Outcome.sent ? 'Done' : 'View this purchase',
            variant: outcome != _Outcome.sent ? AppButtonVariant.primary : AppButtonVariant.secondary,
            onPressed: () => context.pushReplacement('/purchases/$purchaseId'),
          ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }
}

enum _Outcome {
  // "Request sent", never "paid": the business has not approved it yet.
  sent('Payment Request Sent'),
  coinsApplied('Coins applied'),
  // Only ever shown once the shop has approved the bill -- the app never
  // sees the money change hands, so the shop's approval is what confirms
  // it.
  confirmed('Payment Successful'),
  declined('Payment Rejected');

  const _Outcome(this.title);

  final String title;

  /// Settled one way or the other: nothing is left to pay or wait for.
  bool get isFinal => this == confirmed || this == declined;
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
                  style: AppTypography.badgeLabel.copyWith(color: foreground, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh status',
          // The screen already checks every few seconds; this is for a
          // customer who would rather not wait for the next check. The bill
          // carries its coin payment, so it is the one thing to re-read.
          onPressed: checking ? null : () => ref.invalidate(purchaseDetailProvider(purchaseId)),
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
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: AppElevation.glow(color)),
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

/// The two numbers a customer cares about most, side by side: the rupees
/// their coins took off this bill, and the coins this bill earns them.
class _SavedAndEarned extends StatelessWidget {
  const _SavedAndEarned({
    required this.saved,
    required this.savedLabel,
    required this.savedCaption,
    required this.coins,
    required this.earnedLabel,
    required this.earnedCaption,
  });

  final double saved;
  final String savedLabel;
  final String savedCaption;

  /// Null when the server has not said (an older API) -- shown as a dash.
  final int? coins;
  final String earnedLabel;
  final String earnedCaption;

  @override
  Widget build(BuildContext context) {
    final shownCoins = coins;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _HighlightTile(
              icon: Icons.savings_rounded,
              tint: AppColors.success,
              background: AppColors.successBg,
              label: savedLabel,
              value: '₹${saved.toStringAsFixed(2)}',
              caption: savedCaption,
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: _HighlightTile(
              icon: Icons.toll_rounded,
              tint: AppColors.gold,
              background: AppColors.goldLight,
              label: earnedLabel,
              value: shownCoins == null ? '—' : '$shownCoins coins',
              caption: earnedCaption,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.tint,
    required this.background,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color tint;
  final Color background;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value. $caption',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: AppIconSize.md, color: tint),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tint, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppTypography.numericFinancialMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(caption, style: AppTypography.caption),
          ],
        ),
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
