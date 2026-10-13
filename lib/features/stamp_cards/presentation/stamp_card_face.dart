import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../merchants/presentation/merchant_logo.dart';
import 'stamp_card_style.dart';

/// The card as the customer sees it everywhere: the shop's logo and name,
/// the title, the reward, and the row of stamp slots with the collected
/// ones filled. Shared by the customer's list, the detail page, the
/// shop's form preview and the counter.
class StampCardFace extends StatelessWidget {
  const StampCardFace({
    super.key,
    required this.title,
    required this.rewardText,
    required this.stampsRequired,
    required this.stampsCount,
    required this.icon,
    this.merchantName,
    this.merchantLogoUrl,
    this.status = 'collecting',
    this.compact = false,
    this.animateLastStamp = false,
  });

  final String title;
  final String rewardText;
  final int stampsRequired;
  final int stampsCount;
  final String icon;
  final String? merchantName;
  final String? merchantLogoUrl;

  /// `collecting | full | rewarded`.
  final String status;

  /// A shorter card for Home's strip.
  final bool compact;

  /// Pops the most recent stamp in, for the moment one lands.
  final bool animateLastStamp;

  @override
  Widget build(BuildContext context) {
    final style = StampCardStyle.of(icon);
    final textTheme = Theme.of(context).textTheme;
    final ink = style.ink;
    final full = status == 'full';
    final rewarded = status == 'rewarded';

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.smd : AppSpacing.md),
      decoration: BoxDecoration(
        gradient: style.gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: style.accent.withValues(alpha: full ? 0.55 : 0.3),
            blurRadius: full ? 22 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (merchantName != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 2),
                      child: MerchantLogo(url: merchantLogoUrl, merchantName: merchantName!, size: compact ? AppSize.avatarSm : AppSize.avatarMd),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (merchantName != null)
                      Text(
                        merchantName!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(color: ink.withValues(alpha: 0.8), letterSpacing: 1.5, fontWeight: FontWeight.w800),
                      ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (compact ? textTheme.titleSmall : textTheme.titleMedium)?.copyWith(color: ink, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RewardChip(text: rewardText, ink: ink, compact: compact),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          _StampRow(
            required: stampsRequired,
            count: stampsCount,
            emoji: style.emoji,
            ink: ink,
            compact: compact,
            animateLast: animateLastStamp,
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  rewarded
                      ? 'Reward claimed'
                      : full
                      ? 'Card full — show it at the shop!'
                      : '$stampsCount of $stampsRequired stamps · ${stampsRequired - stampsCount} to go',
                  style: textTheme.labelMedium?.copyWith(color: ink, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (full) const Text('🎉', style: TextStyle(fontSize: 18)),
              if (rewarded) Icon(Icons.check_circle_rounded, size: AppIconSize.sm, color: ink),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.text, required this.ink, required this.compact});

  final String text;
  final Color ink;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 110 : 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 12)),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stamp slots, wrapped into rows of up to six. Filled slots show the
/// programme's emoji on a white disc; empty ones are a faint ring.
class _StampRow extends StatelessWidget {
  const _StampRow({
    required this.required,
    required this.count,
    required this.emoji,
    required this.ink,
    required this.compact,
    required this.animateLast,
  });

  final int required;
  final int count;
  final String emoji;
  final Color ink;
  final bool compact;
  final bool animateLast;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 26.0 : (required > 8 ? 32.0 : 40.0);
    return Wrap(
      spacing: compact ? AppSpacing.xs : AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < required; i++)
          _StampSlot(
            filled: i < count,
            emoji: emoji,
            size: size,
            ink: ink,
            pop: animateLast && i == count - 1,
          ),
      ],
    );
  }
}

class _StampSlot extends StatelessWidget {
  const _StampSlot({required this.filled, required this.emoji, required this.size, required this.ink, required this.pop});

  final bool filled;
  final String emoji;
  final double size;
  final Color ink;
  final bool pop;

  @override
  Widget build(BuildContext context) {
    final slot = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: filled ? 0.9 : 0.45), width: 1.5),
        boxShadow: filled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))] : null,
      ),
      child: filled ? Text(emoji, style: TextStyle(fontSize: size * 0.5)) : null,
    );

    if (!pop) return slot;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: 0.4 + 0.6 * t, child: child),
      child: slot,
    );
  }
}
