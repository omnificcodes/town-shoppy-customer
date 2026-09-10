import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// The single entry point for both purchase QR flows (Method 1 and Method 3
/// of the "3-way purchase architecture" -- see `scan_merchant_qr_screen.dart`
/// / `my_qr_screen.dart`). Previously these lived as two unrelated buttons
/// buried on `PurchasesListScreen`; this sheet is what the bottom nav's
/// center Scan & Pay action opens instead, so the choice is reachable from
/// Home/anywhere, not just after already navigating into Purchases.
Future<void> showScanAndPaySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _ScanAndPaySheet(),
  );
}

class _ScanAndPaySheet extends StatelessWidget {
  const _ScanAndPaySheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.sm),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            ExcludeSemantics(
              child: Container(
                width: AppSize.controlSm,
                height: AppSpacing.xs,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppSpacing.xxs)),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Scan & Pay', style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Show your code, or scan a merchant’s.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ScanAndPayOption(
              icon: Icons.qr_code_rounded,
              iconBackground: AppColors.orangeTint,
              iconColor: AppColors.orange,
              title: 'My QR code',
              subtitle: 'Show this to a merchant to pay',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/purchases/my-qr');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _ScanAndPayOption(
              icon: Icons.qr_code_scanner_rounded,
              iconBackground: AppColors.crimson,
              iconColor: AppColors.onCrimson,
              title: 'Scan business QR',
              subtitle: 'Scan a merchant’s permanent QR to pay',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/purchases/scan');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanAndPayOption extends StatelessWidget {
  const _ScanAndPayOption({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;

  /// Must contrast with [iconBackground]: `onCrimson` on crimson, or the
  /// brand orange on its own tint -- never white on orange.
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: AppSize.controlMd,
                  height: AppSize.controlMd,
                  decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  child: Icon(icon, color: iconColor, size: AppIconSize.lg),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: AppIconSize.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
