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
///
/// The tagline sits on its own full-width line under the title row rather
/// than beside the location pill, so it isn't squeezed into an ellipsis on
/// narrow phones.
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                )
              else
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Discover Merchants',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const _LocationPill(),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: canPop ? AppSpacing.xxl : AppSpacing.sm, top: 2),
            child: Text(
              'Shop Local  •  Save More  •  Support Community',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
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

    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ref.read(homeLocationControllerProvider.notifier).retry(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.orange, size: 15),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}
