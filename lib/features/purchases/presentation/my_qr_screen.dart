import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/my_qr_provider.dart';

/// Method 3 (3-way purchase architecture): the customer's own identity QR
/// -- shown to a merchant at checkout, who scans it to identify the
/// customer server-side without ever seeing a mobile number. No amount
/// entry happens here at all (that's on the merchant's side, after they
/// scan) -- this screen only displays the code.
class MyQrScreen extends ConsumerWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(myQrProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My QR code')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: tokenAsync.when(
            loading: () => const LoadingSkeletonCard(),
            error: (error, _) => ErrorState(
              error: error is AppException ? error : const UnknownAppException(),
              onRetry: () => ref.invalidate(myQrProvider),
            ),
            data: (token) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Show this to a merchant so they can record your purchase.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(data: token, size: 220, backgroundColor: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Regenerate code',
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    await ref.read(myQrProvider.notifier).regenerate();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Regenerating invalidates this code immediately -- do this only if you think it was shared by mistake.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textDisabled),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
