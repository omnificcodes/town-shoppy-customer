import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A colorful, briefly-animated "something good just happened" card -- the
/// moment a purchase is recorded (coins earned) or a redemption settles (a
/// discount saved). One scale+fade entrance (~380ms, a mild
/// [Curves.easeOutBack] overshoot for a touch of life) rather than a
/// longer or looping effect -- design-principles.md's "premium means
/// restrained" rule applies to a celebratory moment too, not just static
/// chrome.
class CelebrationCard extends StatefulWidget {
  const CelebrationCard({
    super.key,
    required this.title,
    this.subtitle,
    this.savedAmount,
    this.coinsEarned,
  });

  final String title;
  final String? subtitle;

  /// ₹ the customer saved via a coin discount, shown as "You saved ₹X".
  final double? savedAmount;

  /// Town Coins earned from this purchase's own bill amount.
  final int? coinsEarned;

  @override
  State<CelebrationCard> createState() => _CelebrationCardState();
}

class _CelebrationCardState extends State<CelebrationCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasSaved = widget.savedAmount != null && widget.savedAmount! > 0;
    final hasCoins = widget.coinsEarned != null && widget.coinsEarned! > 0;

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Semantics(
          liveRegion: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.successBg, AppColors.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: AppSize.avatarLg,
                  height: AppSize.avatarLg,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: AppColors.surface, size: AppIconSize.lg),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(widget.title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(widget.subtitle!, style: textTheme.bodyMedium, textAlign: TextAlign.center),
                ],
                if (hasSaved) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
                    child: Text(
                      'You saved ₹${widget.savedAmount!.toStringAsFixed(2)}',
                      style: textTheme.titleMedium?.copyWith(color: AppColors.surface, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                if (hasCoins) ...[
                  SizedBox(height: hasSaved ? AppSpacing.sm : AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: AppColors.goldDark, size: AppIconSize.sm),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '+${widget.coinsEarned} Town Coins earned',
                        style: textTheme.titleSmall?.copyWith(color: AppColors.goldDark, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
