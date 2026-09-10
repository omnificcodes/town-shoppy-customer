import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/celebration_card.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
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
///
/// The back button is suppressed so a stray swipe can't lose the
/// one-time code; the explicit Close action (with a confirm) is the exit.
/// The backend does expose `POST /redemptions/{id}/cancel` to the customer,
/// but this app's `RedemptionsRepository` has no `cancel()` yet -- closing
/// leaves the redemption to expire on its own, and says so.
class RedemptionVerificationScreen extends ConsumerStatefulWidget {
  const RedemptionVerificationScreen({super.key, required this.redemptionId, this.clock = DateTime.now});

  final int redemptionId;

  /// Wall-clock source for the expiry countdown. Injectable so a widget
  /// test can advance time deterministically (the test binding fakes
  /// [Timer]s but not [DateTime.now]).
  @visibleForTesting
  final DateTime Function() clock;

  @override
  ConsumerState<RedemptionVerificationScreen> createState() => _RedemptionVerificationScreenState();
}

class _RedemptionVerificationScreenState extends ConsumerState<RedemptionVerificationScreen> {
  String? _otpCode;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _hasRefreshedHistory = false;

  /// Set when the local countdown reaches zero. The backend only flips the
  /// row to `expired` on the merchant's next verify attempt, so without
  /// this the screen would keep showing a dead code as "waiting".
  bool _expiredLocally = false;

  static const _pollInterval = Duration(seconds: 4);

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
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      ref.invalidate(redemptionDetailProvider(widget.redemptionId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _onTerminal() {
    _stopPolling();

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

  /// Starts the once-a-second tick the moment we know when the code dies.
  /// Idempotent: called from build, but only ever creates one timer.
  void _ensureCountdown(DateTime expiresAt) {
    if (_countdownTimer != null || _expiredLocally) return;
    if (!expiresAt.isAfter(widget.clock())) {
      _expiredLocally = true;
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!expiresAt.isAfter(widget.clock())) {
        setState(() => _expiredLocally = true);
        _onTerminal();
        return;
      }
      setState(() {});
    });
  }

  Future<void> _confirmClose() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this screen?'),
        content: const Text(
          'Your redemption stays open until the merchant verifies it or the code expires. '
          'Your code will not be shown again on this device, but you can find the redemption in your history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Stay')),
          AppButton(label: 'Leave', expand: false, onPressed: () => Navigator.of(dialogContext).pop(true)),
        ],
      ),
    );
    if (leave == true && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(redemptionDetailProvider(widget.redemptionId));
    final isWaiting = switch (detail) {
      AsyncData(:final value) => !value.isTerminal && !_expiredLocally,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redemption'),
        automaticallyImplyLeading: false,
        actions: [
          if (isWaiting)
            IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: _confirmClose),
        ],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.page), child: LoadingSkeletonCard()),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(redemptionDetailProvider(widget.redemptionId)),
          ),
          data: (redemption) {
            if (redemption.isTerminal) {
              _onTerminal();
            } else if (redemption.qrExpiresAt != null) {
              _ensureCountdown(redemption.qrExpiresAt!);
            }

            final status = _expiredLocally && !redemption.isTerminal ? 'expired' : redemption.status;

            // A short cross-fade, not a hard cut, for the moment this screen's
            // whole job is building toward -- the merchant verifying the code
            // and the view flipping from "waiting" to settled/expired/
            // cancelled. Matches the product brief's call for subtle motion
            // on approval-state changes; 200ms/fade only, nothing bouncy.
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (status) {
                'settled' => _ConfirmationView(key: const ValueKey('settled'), redemption: redemption),
                'expired' => _TerminalView(
                    key: const ValueKey('expired'),
                    icon: Icons.timer_off_rounded,
                    title: 'This redemption expired',
                    message: 'The verification window closed before it was completed. No coins were deducted. '
                        'Start a new redemption to try again.',
                    redemption: redemption,
                  ),
                'cancelled' => _TerminalView(
                    key: const ValueKey('cancelled'),
                    icon: Icons.cancel_rounded,
                    title: 'Redemption cancelled',
                    message: 'This redemption was cancelled. No coins were deducted.',
                    redemption: redemption,
                  ),
                _ => _WaitingView(
                    key: const ValueKey('waiting'),
                    redemption: redemption,
                    otpCode: _otpCode,
                    remaining: redemption.qrExpiresAt?.difference(widget.clock()),
                  ),
              },
            );
          },
        ),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({super.key, required this.redemption, required this.otpCode, required this.remaining});

  final Redemption redemption;
  final String? otpCode;

  /// Time left before the code dies; null when the backend gave no expiry.
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countdown = remaining == null ? null : _formatRemaining(remaining!);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(redemption.merchantName, style: textTheme.titleMedium),
              if (redemption.branch != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(redemption.branch!.name, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        if (otpCode != null) ...[
          Text('Show this code to complete your redemption', style: textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Semantics(
              label: 'Verification code ${otpCode!.split('').join(' ')}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(otpCode!, style: AppTypography.numericFinancialLarge.copyWith(letterSpacing: 2)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Read this code aloud to the merchant to complete your redemption.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ] else
          const InfoBox(
            tone: AppTone.pending,
            icon: Icons.sms_failed_outlined,
            title: 'Code not available',
            message: "Your code isn't available on this device any more. "
                'Ask the merchant to look up your redemption by your mobile number.',
          ),
        const SizedBox(height: AppSpacing.xl),
        // Live region: a screen reader hears the countdown/waiting text
        // change without the customer having to hunt for it.
        Semantics(
          liveRegion: true,
          child: Column(
            children: [
              const Center(child: CircularProgressIndicator(semanticsLabel: 'Waiting for the merchant to verify')),
              const SizedBox(height: AppSpacing.md),
              Text('Waiting for the merchant to verify…', style: textTheme.bodyMedium, textAlign: TextAlign.center),
              if (countdown != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Expires in $countdown',
                  style: AppTypography.numericFinancialInline.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatRemaining(Duration remaining) {
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final minutes = clamped.inMinutes.toString().padLeft(2, '0');
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({super.key, required this.redemption});

  final Redemption redemption;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: AppSpacing.sm),
        CelebrationCard(
          title: 'Redemption complete!',
          subtitle: redemption.merchantName,
          savedAmount: redemption.discountAmount,
        ),
        const SizedBox(height: AppSpacing.section),
        AppCard(
          child: Column(
            children: [
              if (redemption.discountAmount != null)
                DetailRow(label: 'Discount applied', value: '₹${redemption.discountAmount!.toStringAsFixed(2)}', emphasize: true),
              if (redemption.coinsDebited != null) DetailRow(label: 'Coins debited', value: '${redemption.coinsDebited}'),
              if (redemption.remainingBillAmount != null)
                DetailRow(label: 'Remaining bill', value: '₹${redemption.remainingBillAmount!.toStringAsFixed(2)}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppButton(label: 'Done', onPressed: () => context.go('/home')),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'View details',
          variant: AppButtonVariant.secondary,
          onPressed: () => context.pushReplacement('/redemptions/${redemption.id}'),
        ),
      ],
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
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(child: Icon(icon, size: AppIconSize.hero, color: AppColors.error)),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(message, style: textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.section),
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
