import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/my_vouchers_controller.dart';
import '../data/models/voucher.dart';
import 'draw_status_display.dart';

/// The winning voucher's claim code -- a fourth, independent QR system
/// (Purchase QR / Customer QR / Redemption QR / this one), shown to the
/// sponsor merchant's staff at claim time. Only rendered while the voucher
/// is ACTIVE (still claimable); a claimed/expired/void voucher shows its
/// terminal status instead of a QR that can no longer be used.
class VoucherDetailScreen extends ConsumerWidget {
  const VoucherDetailScreen({super.key, required this.voucherId});

  final int voucherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voucher = ref.watch(voucherDetailProvider(voucherId));

    return AppScaffold(
      title: 'Your prize',
      padded: false,
      body: voucher.when(
        loading: () => const LoadingSkeletonList(count: 1),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(voucherDetailProvider(voucherId)),
        ),
        data: (data) => _VoucherDetailBody(voucher: data),
      ),
    );
  }
}

class _VoucherDetailBody extends StatelessWidget {
  const _VoucherDetailBody({required this.voucher});

  final Voucher voucher;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sponsor = voucher.sponsorMerchantName;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge under the name, not beside it: a headline-size prize
              // name and a large badge can't share one row at 320px / 2x.
              StatusBadge(
                label: voucherStatusLabel(voucher.status),
                tone: voucherStatusTone(voucher.status),
                icon: voucher.isClaimed ? Icons.check_rounded : null,
                large: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(voucher.prize?.name ?? 'Prize', style: textTheme.titleLarge),
              if (sponsor != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text('Sponsored by $sponsor', style: textTheme.bodySmall),
              ],
            ],
          ),
        ),

        // The deadline is the one thing an active winner must not miss, so
        // it sits directly under the prize rather than as a footnote.
        if (voucher.isActive && voucher.expiresAt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InfoBox(
            tone: AppTone.pending,
            icon: Icons.schedule_rounded,
            title: 'Claim by ${_formatDate(voucher.expiresAt!)}',
            message: 'Show your claim code to ${sponsor ?? 'the sponsoring merchant'} before this date.',
          ),
        ],

        const SizedBox(height: AppSpacing.section),
        if (voucher.isActive) _ClaimQrCard(voucherId: voucher.id, code: voucher.code),
        if (voucher.isClaimed)
          InfoBox(
            tone: AppTone.success,
            icon: Icons.check_circle_rounded,
            message: voucher.claimedAt != null ? 'Claimed on ${_formatDate(voucher.claimedAt!)}.' : 'This prize has been claimed.',
          ),
        if (!voucher.isActive && !voucher.isClaimed)
          InfoBox(
            tone: AppTone.neutral,
            icon: Icons.info_outline_rounded,
            message: 'This voucher is ${voucherStatusLabel(voucher.status).toLowerCase()} and can no longer be claimed.',
          ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _ClaimQrCard extends ConsumerWidget {
  const _ClaimQrCard({required this.voucherId, required this.code});

  final int voucherId;
  final String code;

  /// The QR's edge length — large enough for a merchant's scanner at arm's
  /// length, small enough to fit a 320px card with its padding.
  static const double _qrSize = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secret = ref.watch(voucherQrSecretProvider(voucherId));

    return AppCard(
      child: Column(
        children: [
          Text(
            'Show this to the sponsoring merchant to claim your prize.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          secret.when(
            loading: () => const SizedBox(width: _qrSize, height: _qrSize, child: Center(child: CircularProgressIndicator())),
            error: (error, _) => SizedBox(
              width: _qrSize,
              child: ErrorState(
                compact: true,
                error: error is AppException ? error : const UnknownAppException(),
                title: 'Could not load your claim code',
                onRetry: () => ref.invalidate(voucherQrSecretProvider(voucherId)),
              ),
            ),
            data: (qrSecret) => Semantics(
              image: true,
              label: 'Claim QR code for voucher $code',
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
                child: QrImageView(data: qrSecret, size: _qrSize, backgroundColor: AppColors.surface),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: 'Voucher code $code',
            child: Text(code, style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }
}
