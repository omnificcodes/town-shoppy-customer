import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../merchants/presentation/merchant_logo.dart';
import '../../application/business_branches_controller.dart';
import '../../application/business_context.dart';
import '../../data/models/merchant_branch.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// A branch's permanent Purchase QR -- shown big enough for a customer to
/// scan straight off the phone at the counter (the mobile-only win over
/// the web's download/print), with generate / regenerate / revoke. The
/// code encodes the raw token, nothing else, exactly what the customer
/// app's scanner expects. The merchant logo sits in the centre, which the
/// high error-correction level tolerates.
class BranchQrScreen extends ConsumerWidget {
  const BranchQrScreen({super.key, required this.branchId, this.branch});

  final int branchId;
  final MerchantBranch? branch;

  static const double _maxQrSize = 300;

  Future<void> _generate(BuildContext context, WidgetRef ref, {required bool regenerate}) async {
    if (regenerate) {
      final ok = await showBusinessConfirmDialog(
        context,
        title: 'Regenerate this Purchase QR?',
        message: 'The current code stops working immediately. Anyone who printed or saved it will need the new one.',
        confirmLabel: 'Regenerate',
      );
      if (!ok || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(branchQrProvider(branchId).notifier).generate();
      messenger.showSnackBar(SnackBar(content: Text(regenerate ? 'Purchase QR regenerated.' : 'Purchase QR generated.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final ok = await showBusinessConfirmDialog(
      context,
      title: 'Revoke this Purchase QR?',
      message: 'Anyone with the current code will no longer be able to submit a purchase with it. You can generate a new one at any time.',
      confirmLabel: 'Revoke',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(branchQrProvider(branchId).notifier).revoke();
      messenger.showSnackBar(const SnackBar(content: Text('Purchase QR revoked.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qr = ref.watch(branchQrProvider(branchId));
    final merchant = ref.watch(myMerchantProvider).value;
    final textTheme = Theme.of(context).textTheme;
    final name = branch?.name ?? 'this branch';
    final qrSize = math.min(MediaQuery.sizeOf(context).width - 2 * AppSpacing.page - 2 * AppSpacing.lg, _maxQrSize);

    return BusinessScaffold(
      title: 'Purchase QR',
      body: qr.when(
        loading: () => Center(child: LoadingSkeleton(width: qrSize, height: qrSize, borderRadius: BorderRadius.circular(AppSpacing.radiusLg))),
        error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: "Could not load this branch's Purchase QR.", onRetry: () => ref.invalidate(branchQrProvider(branchId))),
        data: (token) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                token == null ? 'Generate a code to start accepting scan-and-submit purchases at $name.' : 'Display this at $name so customers can scan it to submit a purchase for your approval.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.section),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: token == null
                      ? SizedBox(
                          width: qrSize,
                          height: qrSize,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border, width: 2),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_2_rounded, size: AppIconSize.hero, color: AppColors.textDisabled),
                                const SizedBox(height: AppSpacing.sm),
                                Text('No Purchase QR yet.', style: textTheme.bodySmall),
                              ],
                            ),
                          ),
                        )
                      : Semantics(
                          label: 'Purchase QR code for $name',
                          image: true,
                          excludeSemantics: true,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(data: token, size: qrSize, backgroundColor: AppColors.surface, errorCorrectionLevel: QrErrorCorrectLevel.H),
                              if (merchant != null)
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                                  child: ClipOval(child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarMd)),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
              if (branch != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(branch!.name, style: textTheme.titleLarge, textAlign: TextAlign.center),
                Text(branch!.formattedAddress, style: AppTypography.caption, textAlign: TextAlign.center),
              ],
              const SizedBox(height: AppSpacing.section),
              if (token == null)
                AppButton(label: 'Generate QR', icon: Icons.qr_code_2_rounded, onPressed: () => _generate(context, ref, regenerate: false))
              else ...[
                AppButton(label: 'Regenerate', icon: Icons.refresh_rounded, variant: AppButtonVariant.secondary, onPressed: () => _generate(context, ref, regenerate: true)),
                const SizedBox(height: AppSpacing.sm),
                AppButton(label: 'Revoke', icon: Icons.shield_outlined, variant: AppButtonVariant.text, onPressed: () => _revoke(context, ref)),
              ],
              const SizedBox(height: AppSpacing.md),
              InfoBox(
                icon: Icons.info_outline_rounded,
                message: token == null
                    ? 'Each branch has its own permanent code. Print it or show it on this screen at the counter.'
                    : 'Scanning this always resolves to this exact branch, no matter who prints or displays it. Regenerating or revoking stops the old code immediately.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
