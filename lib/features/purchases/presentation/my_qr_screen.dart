import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/my_qr_provider.dart';

/// Method 3 (3-way purchase architecture): the customer's own identity QR
/// -- shown to a merchant at checkout, who scans it to identify the
/// customer server-side without ever seeing a mobile number. No amount
/// entry happens here at all (that's on the merchant's side, after they
/// scan) -- this screen only displays the code.
class MyQrScreen extends ConsumerWidget {
  const MyQrScreen({super.key});

  /// The QR is never wider than this, however wide the screen.
  static const double _maxQrSize = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(myQrProvider);
    final isRegenerating = ref.watch(myQrRegeneratingProvider);

    // Page margin on both sides, plus the white quiet-zone padding inside
    // the QR card, is what the code itself can never exceed at 320px.
    final qrSize = math.min(
      MediaQuery.sizeOf(context).width - 2 * AppSpacing.page - 2 * AppSpacing.lg,
      _maxQrSize,
    );

    return AppScaffold(
      title: 'My QR code',
      body: tokenAsync.when(
        loading: () => Center(
          child: LoadingSkeleton(
            width: qrSize,
            height: qrSize,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(myQrProvider),
        ),
        data: (token) => SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Show this to a merchant so they can record your purchase.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.section),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Semantics(
                  label: 'Your Town Shoppy QR code',
                  image: true,
                  excludeSemantics: true,
                  child: QrImageView(data: token, size: qrSize, backgroundColor: AppColors.surface),
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              AppButton(
                label: 'Regenerate code',
                variant: AppButtonVariant.secondary,
                icon: Icons.refresh_rounded,
                isLoading: isRegenerating,
                onPressed: () => _confirmRegenerate(context, ref),
              ),
              const SizedBox(height: AppSpacing.md),
              const InfoBox(
                tone: AppTone.pending,
                icon: Icons.lock_outline_rounded,
                message: 'Regenerating invalidates this code immediately. Do this only if you think it was shared by mistake.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRegenerate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerate your code?'),
        content: const Text(
          'Your current code stops working immediately. Anyone who saved it will no longer be able to use it to record a purchase for you.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          AppButton(label: 'Regenerate', expand: false, onPressed: () => Navigator.of(dialogContext).pop(true)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(myQrProvider.notifier).regenerate();
      messenger.showSnackBar(const SnackBar(content: Text('Your QR code was regenerated.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(const UnknownAppException().message)));
    }
  }
}
