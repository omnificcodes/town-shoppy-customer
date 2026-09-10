import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A single pulsing placeholder block. Compose several of these into a
/// layout that mirrors the real content's structure — design-principles.md
/// is explicit that a skeleton must match the final layout, not be a
/// generic centered spinner, so the loading → loaded transition doesn't
/// jump.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, this.width, this.height = 16, this.borderRadius});

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween(begin: 0.5, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
  }
}

/// A padded column of [count] [LoadingSkeletonCard]s — what every list
/// screen shows while its first page loads, so they stop hand-rolling the
/// same ListView.
class LoadingSkeletonList extends StatelessWidget {
  const LoadingSkeletonList({super.key, this.count = 6, this.padding = const EdgeInsets.all(AppSpacing.page)});

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => const LoadingSkeletonCard(),
    );
  }
}

/// A skeleton shaped like [AppCard]'s common "icon + two lines" layout —
/// the most frequent card content shape in this app (wallet summary,
/// purchase/notification rows).
class LoadingSkeletonCard extends StatelessWidget {
  const LoadingSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const LoadingSkeleton(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSm))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                LoadingSkeleton(width: 140),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
