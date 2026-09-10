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
/// The location pill sits on its own line under the title rather than
/// beside it: on a 360dp phone the title row can't hold a 19sp heading and
/// a resolved-locality pill without ellipsising one of them. The old
/// promotional tagline is gone — [DiscoverBanner] directly below already
/// carries that message, and saying it twice in the first 120dp is noise.
class MerchantsDiscoveryHeader extends ConsumerWidget {
  const MerchantsDiscoveryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigator.canPop(), not go_router's own context.canPop() -- the
    // latter throws (via GoRouter.of()) when no GoRouter is present in
    // the widget tree, which every widget test for this screen builds
    // as a plain MaterialApp(home: ...) with no router.
    final canPop = Navigator.canPop(context);

    // The title starts at the page margin; with a back button it sits
    // after the button's 48dp slot plus one gap, and the pill indents by
    // the same amount so both lines share a left edge.
    const backSlot = AppSpacing.touchTarget + AppSpacing.sm;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop) ...[
                SizedBox(
                  width: AppSpacing.touchTarget,
                  height: AppSpacing.touchTarget,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  'Discover Merchants',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: canPop ? backSlot : 0, top: AppSpacing.xs),
            child: const Align(alignment: Alignment.centerLeft, child: _LocationPill()),
          ),
        ],
      ),
    );
  }
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  /// Caps the pill so a long resolved locality still reads as a pill, not
  /// a full-width bar.
  static const double _maxWidth = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(homeLocationControllerProvider);

    final String label = switch (location) {
      AsyncData(:final value) when value is HomeLocationReady => value.label,
      AsyncData() => 'Set location',
      AsyncError() => 'Set location',
      _ => 'Locating…',
    };

    return Semantics(
      button: true,
      label: 'Location: $label',
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          onTap: () => ref.read(homeLocationControllerProvider.notifier).retry(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: _maxWidth, minHeight: AppSize.controlSm),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.orange, size: AppIconSize.sm),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: AppIconSize.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
