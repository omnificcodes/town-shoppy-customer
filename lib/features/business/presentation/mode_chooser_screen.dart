import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import 'business_routes.dart';

/// Shown once after sign-in to an account that operates a merchant: pick
/// the shopper app or the business app. The choice is remembered
/// (`AppModeController`) and can be changed later from either mode's menu,
/// which also lands here.
class ModeChooserScreen extends ConsumerWidget {
  const ModeChooserScreen({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, AppMode mode) async {
    await ref.read(appModeControllerProvider.notifier).select(mode);
    if (!context.mounted) return;
    context.go(mode == AppMode.business ? BusinessRoutes.root : '/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final account = auth is AuthAuthenticated ? auth.account : null;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AuthPalette.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - AppSpacing.lg * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Center(child: AuthBrandBlock(logoHeight: 64)),
                  const SizedBox(height: AppSpacing.xl),
                  Text('How would you like to continue?', style: textTheme.headlineMedium?.copyWith(color: AuthPalette.brown)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    account == null
                        ? 'Your number is linked to a business as well as a shopper account.'
                        : '${account.mobileNumber} is linked to a business as well as a shopper account. You can switch any time from the menu.',
                    style: textTheme.bodyMedium?.copyWith(color: AuthPalette.mutedText),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _ModeCard(
                    key: const ValueKey('choose-customer'),
                    eyebrow: 'SHOP · SAVE · WIN',
                    title: 'Customer app',
                    description: 'Discover local shops, earn Town Coin on every bill and enter the Lucky Draw.',
                    icon: Icons.shopping_bag_rounded,
                    accent: AppColors.orange,
                    ground: AppColors.orangeTint,
                    onTap: () => _choose(context, ref, AppMode.customer),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ModeCard(
                    key: const ValueKey('choose-business'),
                    eyebrow: 'RUN YOUR SHOP',
                    title: 'Business app',
                    description: 'Record bills at the counter, verify redemptions, publish offers and manage your shop.',
                    icon: Icons.storefront_rounded,
                    accent: AppColors.yellow,
                    ground: AppColors.businessInk,
                    dark: true,
                    onTap: () => _choose(context, ref, AppMode.business),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                      icon: const Icon(Icons.logout_rounded, size: AppIconSize.sm),
                      label: const Text('Sign out'),
                      style: TextButton.styleFrom(foregroundColor: AuthPalette.mutedText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.ground,
    required this.onTap,
    this.dark = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color ground;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fg = dark ? AppColors.onBusinessInk : AppColors.textPrimary;
    final fgMuted = dark ? AppColors.onBusinessInkMuted : AppColors.textSecondary;

    return Semantics(
      button: true,
      label: '$title. $description',
      child: Material(
        color: ground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: dark ? AppColors.businessInkDeep : AppColors.orangeBorder),
              boxShadow: AppElevation.subtle,
            ),
            child: Row(
              children: [
                Container(
                  width: AppSize.avatarLg,
                  height: AppSize.avatarLg,
                  decoration: BoxDecoration(
                    color: dark ? accent.withValues(alpha: 0.18) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(icon, color: accent, size: AppIconSize.xl),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow, style: AppTypography.overline.copyWith(color: dark ? accent : AppColors.orange)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(title, style: textTheme.titleLarge?.copyWith(color: fg)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(description, style: textTheme.bodySmall?.copyWith(color: fgMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.arrow_forward_rounded, color: fg, size: AppIconSize.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
