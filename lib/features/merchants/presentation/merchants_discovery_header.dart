import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../home/application/home_location_controller.dart';

/// This screen's own top section — back button, "Discover Merchants" title
/// and tagline, plus a location pill. Deliberately reuses
/// [homeLocationControllerProvider] rather than a second location lookup:
/// it's the same device coordinate Home's header already resolved (and the
/// same provider "Nearby" itself never touches — see that controller's own
/// docblock), so sharing it here means this screen never re-prompts for a
/// permission Home may have already asked for.
class MerchantsDiscoveryHeader extends ConsumerWidget {
  const MerchantsDiscoveryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigator.canPop(), not go_router's own context.canPop() -- the
          // latter throws (via GoRouter.of()) when no GoRouter is present in
          // the widget tree, which every widget test for this screen builds
          // as a plain MaterialApp(home: ...) with no router.
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              tooltip: 'Back',
              onPressed: () => context.pop(),
            )
          else
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover Merchants',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Shop Local • Save More • Support Community',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const _LocationPill(),
        ],
      ),
    );
  }
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(homeLocationControllerProvider);

    final String label = switch (location) {
      AsyncData(:final value) when value is HomeLocationReady => value.label,
      AsyncData() => 'Set location',
      AsyncError() => 'Set location',
      _ => 'Locating…',
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => ref.read(homeLocationControllerProvider.notifier).retry(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.orange, size: 14),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
