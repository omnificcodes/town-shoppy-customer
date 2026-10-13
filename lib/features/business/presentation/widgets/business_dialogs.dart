import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

/// "Are you sure?" -- returns true when confirmed.
Future<bool> showBusinessConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        AppButton(
          label: confirmLabel,
          expand: false,
          variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Confirm with an optional free-text reason. Returns `null` when
/// cancelled, otherwise the (possibly empty) reason.
Future<String?> showBusinessReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String placeholder,
  bool destructive = true,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Reason (optional)', hintText: placeholder, controller: controller, maxLines: 3, maxLength: 500),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('Cancel')),
        AppButton(
          label: confirmLabel,
          expand: false,
          variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// The "a purchase just completed" moment -- the web's
/// `PurchaseCelebrationHost` as a Material dialog. Fired by Direct POS and
/// by approving a scan-and-submit request.
Future<void> showPurchaseCelebration(
  BuildContext context, {
  required String title,
  double? discountAmount,
  int? coinsRedeemed,
  int? coinsAwarded,
  String? scratchCardTitle,
  String? stampSummary,
}) {
  final saved = discountAmount != null && discountAmount > 0;
  final earned = coinsAwarded != null && coinsAwarded > 0;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final textTheme = Theme.of(dialogContext).textTheme;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.successBg, AppColors.surface]),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CelebrationBadge(),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                saved
                    ? 'You saved the customer ₹${discountAmount.toStringAsFixed(2)}${coinsRedeemed != null && coinsRedeemed > 0 ? ' ($coinsRedeemed coins redeemed)' : ''}'
                    : 'All done. The customer has been credited.',
                style: textTheme.bodyMedium?.copyWith(color: saved ? AppColors.success : AppColors.textSecondary, fontWeight: saved ? FontWeight.w600 : null),
                textAlign: TextAlign.center,
              ),
              if (earned) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.smd),
                  decoration: BoxDecoration(
                    color: AppColors.orangeTint,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.orangeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('+$coinsAwarded', style: textTheme.headlineLarge?.copyWith(color: AppColors.orange)),
                      const SizedBox(width: AppSpacing.sm),
                      Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xs), child: Text('Town Coins earned', style: textTheme.labelMedium)),
                    ],
                  ),
                ),
              ],
              if (scratchCardTitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Scratch card "$scratchCardTitle" sent to the customer',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
              if (stampSummary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.loyalty_rounded, size: AppIconSize.sm, color: AppColors.businessInk),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(stampSummary, style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Done', onPressed: () => Navigator.of(dialogContext).pop()),
            ],
          ),
        ),
      );
    },
  );
}

class _CelebrationBadge extends StatefulWidget {
  const _CelebrationBadge();

  @override
  State<_CelebrationBadge> createState() => _CelebrationBadgeState();
}

class _CelebrationBadgeState extends State<_CelebrationBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.celebration_rounded, color: AppColors.surface, size: AppIconSize.display),
          ),
          const Positioned(top: -4, right: -4, child: Icon(Icons.auto_awesome_rounded, color: AppColors.yellow, size: AppIconSize.lg)),
        ],
      ),
    );
  }
}
