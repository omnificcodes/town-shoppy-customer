import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/my_vouchers_controller.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Your prize')),
      body: SafeArea(
        child: voucher.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LoadingSkeletonCard(),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(voucherDetailProvider(voucherId)),
          ),
          data: (data) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(data.prize?.name ?? 'Prize', style: Theme.of(context).textTheme.titleLarge),
                          ),
                          StatusBadge(label: voucherStatusLabel(data.status), tone: voucherStatusTone(data.status)),
                        ],
                      ),
                      if (data.sponsorMerchantName != null) ...[
                        const SizedBox(height: 2),
                        Text('Sponsored by ${data.sponsorMerchantName}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (data.isActive) _ClaimQrCard(voucherId: voucherId, code: data.code),
                if (data.isClaimed)
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            data.claimedAt != null ? 'Claimed on ${_formatDate(data.claimedAt!)}.' : 'This prize has been claimed.',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!data.isActive && !data.isClaimed)
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text('This voucher is ${voucherStatusLabel(data.status).toLowerCase()} and can no longer be claimed.')),
                      ],
                    ),
                  ),
                if (data.expiresAt != null && data.isActive) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Claim by ${_formatDate(data.expiresAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
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
            loading: () => const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox(
              width: 200,
              height: 200,
              child: Center(child: Text('Could not load your claim code.')),
            ),
            data: (qrSecret) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
              child: QrImageView(data: qrSecret, size: 200, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(code, style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.5)),
        ],
      ),
    );
  }
}
