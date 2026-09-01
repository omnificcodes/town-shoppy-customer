import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/pending_otp_codes_provider.dart';
import '../application/redemption_detail_provider.dart';
import '../application/redemptions_list_controller.dart';
import '../data/models/redemption.dart';

/// Shown immediately after `POST /redemptions` succeeds. Only the
/// real backend lifecycle drives this screen's content —
/// `initiated`/`settled`/`expired`/`cancelled` (from `RedemptionStatus`) —
/// polled via the existing `redemptionDetailProvider` rather than a
/// duplicate provider, since verification/settlement only ever happens on
/// the *merchant's* side (`RedemptionPolicy::verify()` allows only the
/// merchant owner/staff — a customer can never call that endpoint
/// themselves, confirmed by reading the real policy and its own Pest
/// coverage). This screen therefore only ever displays the OTP code for the
/// customer to relay and waits for the status to change.
class RedemptionVerificationScreen extends ConsumerStatefulWidget {
  const RedemptionVerificationScreen({super.key, required this.redemptionId});

  final int redemptionId;

  @override
  ConsumerState<RedemptionVerificationScreen> createState() => _RedemptionVerificationScreenState();
}

class _RedemptionVerificationScreenState extends ConsumerState<RedemptionVerificationScreen> {
  String? _otpCode;
  Timer? _pollTimer;
  bool _hasRefreshedHistory = false;

  static const _terminalStatuses = {'settled', 'expired', 'cancelled'};

  @override
  void initState() {
    super.initState();
    // Consuming mutates PendingOtpCodes' state, which Riverpod disallows
    // during any widget life-cycle method (including initState) — deferred
    // to right after the first frame instead. Read exactly once — never
    // persisted, never logged, never available again after this screen
    // consumes it (see PendingOtpCodes' docblock).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final code = ref.read(pendingOtpCodesProvider.notifier).consume(widget.redemptionId);
      if (code != null) setState(() => _otpCode = code);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      ref.invalidate(redemptionDetailProvider(widget.redemptionId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _stopPollingIfTerminal(String status) {
    if (!_terminalStatuses.contains(status)) return;

    _pollTimer?.cancel();
    _pollTimer = null;

    // The list screen only re-fetches on session-epoch change or manual
    // pull-to-refresh (it's invalidated on redemption *creation*, not on
    // later settlement) -- without this, History would keep showing the
    // stale 'initiated' status until the customer manually refreshes it.
    // Deferred to after this frame since invalidating a provider during
    // build() throws (same class of bug as the OTP-consume fix above).
    if (!_hasRefreshedHistory) {
      _hasRefreshedHistory = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(redemptionsListControllerProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(redemptionDetailProvider(widget.redemptionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Redemption'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: detail.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LoadingSkeletonCard()),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(redemptionDetailProvider(widget.redemptionId)),
          ),
          data: (redemption) {
            _stopPollingIfTerminal(redemption.status);

            // A short cross-fade, not a hard cut, for the moment this screen's
            // whole job is building toward -- the merchant verifying the code
            // and the view flipping from "waiting" to settled/expired/
            // cancelled. Matches the product brief's call for subtle motion
            // on approval-state changes; 200ms/fade only, nothing bouncy.
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (redemption.status) {
                'settled' => _ConfirmationView(key: const ValueKey('settled'), redemption: redemption),
                'expired' => _TerminalView(
                    key: const ValueKey('expired'),
                    icon: Icons.timer_off_rounded,
                    title: 'This redemption expired',
                    message: 'The verification window closed before it was completed. Start a new redemption to try again.',
                    redemption: redemption,
                  ),
                'cancelled' => _TerminalView(
                    key: const ValueKey('cancelled'),
                    icon: Icons.cancel_rounded,
                    title: 'Redemption cancelled',
                    message: 'This redemption was cancelled.',
                    redemption: redemption,
                  ),
                _ => _WaitingView(key: const ValueKey('waiting'), redemption: redemption, otpCode: _otpCode),
              },
            );
          },
        ),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({super.key, required this.redemption, required this.otpCode});

  final Redemption redemption;
  final String? otpCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(redemption.merchantName, style: Theme.of(context).textTheme.titleMedium),
              if (redemption.branch != null) ...[
                const SizedBox(height: 2),
                Text(redemption.branch!.name, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (otpCode != null) ...[
          Text('Show this code to complete your redemption', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Semantics(
                label: 'Verification code ${otpCode!.split('').join(' ')}',
                child: Text(
                  otpCode!,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Read this code aloud to the merchant to complete your redemption.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Waiting for the merchant to verify…',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({super.key, required this.redemption});

  final Redemption redemption;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Center(child: Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success)),
        const SizedBox(height: AppSpacing.md),
        Text('Redemption complete', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(redemption.merchantName, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            children: [
              if (redemption.discountAmount != null)
                _row(context, 'Discount applied', '₹${redemption.discountAmount!.toStringAsFixed(2)}'),
              if (redemption.coinsDebited != null) _row(context, 'Coins debited', '${redemption.coinsDebited}'),
              if (redemption.remainingBillAmount != null)
                _row(context, 'Remaining bill', '₹${redemption.remainingBillAmount!.toStringAsFixed(2)}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: 'View redemption details', onPressed: () => context.pushReplacement('/redemptions/${redemption.id}')),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Done', variant: AppButtonVariant.secondary, onPressed: () => context.go('/home')),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
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

class _TerminalView extends StatelessWidget {
  const _TerminalView({super.key, required this.icon, required this.title, required this.message, required this.redemption});

  final IconData icon;
  final String title;
  final String message;
  final Redemption redemption;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(child: Icon(icon, size: 56, color: AppColors.error)),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Back to merchant',
          onPressed: redemption.merchant != null ? () => context.pushReplacement('/merchants/${redemption.merchant!.id}') : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Go to home', variant: AppButtonVariant.secondary, onPressed: () => context.go('/home')),
      ],
    );
  }
}
