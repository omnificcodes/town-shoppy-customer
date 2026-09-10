import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/celebration_card.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/purchase_detail_provider.dart';
import '../data/models/purchase.dart';
import 'purchase_status.dart';

/// On-device only, never synced -- just enough state to show the "Purchase
/// recorded!" celebration exactly once per purchase. Reuses
/// [SecureStorageService] (already a dependency for auth tokens) rather
/// than adding a plain local-storage package for one small, non-sensitive
/// list of ids.
const _celebratedPurchaseIdsKey = 'celebrated_purchase_ids';
const _celebratedPurchaseIdsCap = 100;

/// Method 1 (3-way purchase architecture) has no push-notification tap-
/// through wired yet (see NotificationType::PurchaseRecorded on the
/// backend), so a customer waiting on merchant approval has no other way
/// to find out live -- this screen polls while `pending`, same interval/
/// pattern RedemptionVerificationScreen already uses for the equivalent
/// "waiting on the merchant" wait. Once recorded (whether caught live here
/// or simply opened later, which is the only way Methods 2/3 are ever
/// seen -- the merchant records those on their own device), the celebration
/// shows once, tracked by [_celebratedPurchaseIdsKey].
class PurchaseDetailScreen extends ConsumerStatefulWidget {
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  final int purchaseId;

  @override
  ConsumerState<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  static const _pollInterval = Duration(seconds: 4);

  Timer? _pollTimer;
  bool _celebrationCheckStarted = false;
  bool? _shouldCelebrate;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _ensurePolling(bool isPending) {
    if (isPending) {
      _pollTimer ??= Timer.periodic(_pollInterval, (_) {
        ref.invalidate(purchaseDetailProvider(widget.purchaseId));
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _checkCelebration(Purchase purchase) async {
    if (purchase.status != 'recorded' || purchase.coinsAwarded <= 0) {
      if (mounted) setState(() => _shouldCelebrate = false);
      return;
    }

    final storage = ref.read(secureStorageServiceProvider);
    final raw = await storage.read(_celebratedPurchaseIdsKey);
    final celebrated = raw != null ? (jsonDecode(raw) as List).cast<int>() : <int>[];
    final alreadyCelebrated = celebrated.contains(purchase.id);

    if (!mounted) return;
    setState(() => _shouldCelebrate = !alreadyCelebrated);

    if (!alreadyCelebrated) {
      final updated = [...celebrated, purchase.id];
      final capped =
          updated.length > _celebratedPurchaseIdsCap ? updated.sublist(updated.length - _celebratedPurchaseIdsCap) : updated;
      await storage.write(_celebratedPurchaseIdsKey, jsonEncode(capped));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(purchaseDetailProvider(widget.purchaseId));

    return AppScaffold(
      title: 'Purchase details',
      padded: false,
      body: detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
        ),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(purchaseDetailProvider(widget.purchaseId)),
        ),
        data: (purchase) {
          _ensurePolling(purchase.isPending);

          if (!_celebrationCheckStarted) {
            _celebrationCheckStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _checkCelebration(purchase);
            });
          }

          final statusNote = _statusNote(purchase);
          final showCelebration = _shouldCelebrate == true;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(purchaseDetailProvider(widget.purchaseId).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                if (showCelebration) ...[
                  CelebrationCard(
                    title: 'Purchase recorded!',
                    subtitle: purchase.merchantName,
                    coinsEarned: purchase.coinsAwarded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(purchase.merchantName, style: Theme.of(context).textTheme.titleLarge),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: purchaseStatusLabel(purchase.status),
                            tone: purchaseStatusTone(purchase.status),
                            large: true,
                          ),
                        ],
                      ),
                      if (purchase.branch != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(purchase.branch!.name, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text('Bill amount', style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('₹${purchase.billAmount.toStringAsFixed(2)}', style: AppTypography.numericFinancialMedium),
                      // The ₹ sign already says INR; only surface the code
                      // when the backend reports something else.
                      if (purchase.currency != 'INR') ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(purchase.currency, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (statusNote != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  statusNote,
                ],
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DetailRow(
                        label: 'Coins awarded',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on_rounded, size: AppIconSize.sm, color: AppColors.goldDark),
                            const SizedBox(width: AppSpacing.xs),
                            Text('${purchase.coinsAwarded}', style: AppTypography.numericFinancialSmall),
                          ],
                        ),
                      ),
                      if (purchase.couponsIssued != null) DetailRow(label: 'Coupons issued', value: '${purchase.couponsIssued}'),
                      if (purchase.billReference != null && purchase.billReference!.isNotEmpty)
                        DetailRow(label: 'Bill reference', value: purchase.billReference!),
                      if (purchase.createdAt != null) DetailRow(label: 'Date', value: _formatDateTime(purchase.createdAt!)),
                      if (purchase.reviewedAt != null) DetailRow(label: 'Reviewed', value: _formatDateTime(purchase.reviewedAt!)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The "what does this status mean for me" note. Only the statuses that
  /// need explaining get one -- a recorded purchase speaks for itself (or,
  /// once coins > 0, has the celebration card above instead).
  Widget? _statusNote(Purchase purchase) {
    if (purchase.isPending) {
      return const InfoBox(
        tone: AppTone.pending,
        icon: Icons.hourglass_top_rounded,
        title: 'Waiting for the merchant',
        message: "The merchant will review and approve this request. This screen updates on its own once they do.",
      );
    }

    if (purchase.isRejected) {
      final reason = purchase.rejectionReason;
      return InfoBox(
        tone: AppTone.error,
        icon: Icons.info_outline_rounded,
        title: 'Rejected by the merchant',
        message: reason != null && reason.isNotEmpty ? 'Reason: $reason' : 'The merchant did not approve this request.',
      );
    }

    if (purchase.status == 'voided') {
      final reason = purchase.rejectionReason;
      return InfoBox(
        tone: AppTone.error,
        icon: Icons.info_outline_rounded,
        title: 'Voided',
        message: reason != null && reason.isNotEmpty ? 'Reason: $reason' : 'This purchase was voided and no longer counts.',
      );
    }

    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}
