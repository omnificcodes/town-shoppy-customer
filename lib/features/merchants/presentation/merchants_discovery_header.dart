import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/application/home_location_controller.dart';

/// This screen's own top section, following the Google Stitch redesign: a
/// back button, the centred "Discover Merchants" title over its "Town
/// Shoppy Network" eyebrow, a notifications shortcut, and a location pill.
/// Deliberately reuses [homeLocationControllerProvider] rather than a second
/// location lookup: it's the same device coordinate Home's header already
/// resolved, so this screen never re-prompts for a permission Home may have
/// already asked for.
///
/// The bell carries no unread dot: a dot needs the unread count from the
/// server, and showing one without it would be decoration pretending to be
/// information.
class MerchantsDiscoveryHeader extends ConsumerWidget {
  const MerchantsDiscoveryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigator.canPop(), not go_router's own context.canPop() -- the
    // latter throws (via GoRouter.of()) when no GoRouter is present in
    // the widget tree, which every widget test for this screen builds
    // as a plain MaterialApp(home: ...) with no router.
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.smd),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: AppSpacing.touchTarget,
                child: canPop
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Discover Merchants',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.greeting,
                      ),
                    ),
                    Text(
                      'TOWN SHOPPY NETWORK',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.overline.copyWith(color: AppColors.orangeDeep, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox.square(
                dimension: AppSpacing.touchTarget,
                child: Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
                  child: IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                    onPressed: () => context.push('/notifications'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          const _LocationPill(),
        ],
      ),
    );
  }
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  /// Caps the pill so a long resolved locality still reads as a pill, not
  /// a full-width bar.
  static const double _maxWidth = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(homeLocationControllerProvider);

    final String label = switch (location) {
      AsyncData(:final value) when value is HomeLocationReady => value.label,
      AsyncData() => 'Set location',
      AsyncError() => 'Set location',
      _ => 'Locating…',
    };

    final radius = BorderRadius.circular(AppSpacing.radiusPill);

    return Semantics(
      button: true,
      label: 'Location: $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: AppColors.orangeBorder)),
        child: InkWell(
          borderRadius: radius,
          onTap: () => ref.read(homeLocationControllerProvider.notifier).retry(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: _maxWidth, minHeight: AppSize.controlSm),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs + AppSpacing.xxs,
              AppSpacing.xs,
              AppSpacing.smd,
              AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppIconSize.lg,
                  height: AppIconSize.lg,
                  decoration: const BoxDecoration(color: AppColors.orangeTint, shape: BoxShape.circle),
                  child: const Icon(Icons.location_on_rounded, color: AppColors.orangeDeep, size: AppIconSize.sm),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: AppIconSize.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
