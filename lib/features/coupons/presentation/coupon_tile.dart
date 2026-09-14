import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/models/coupon.dart';
import 'coupon_status.dart';

/// One Lucky Draw coupon as a ticket, following the Google Stitch redesign:
/// a stub (TICKET, WINNER or EXPIRED), a perforation, then the code with a
/// copy action, its status, when it was issued, and one chip per draw.
///
/// Each chip reads the coupon's own eligibility for that cadence, so a
/// coupon that won the monthly draw shows Monthly highlighted while Weekly
/// (closed) is muted and Mega (still active) stays gold.
class CouponTile extends StatelessWidget {
  const CouponTile({super.key, required this.coupon, this.onTap});

  final Coupon coupon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final issuedAt = coupon.issuedAt;
    final merchant = coupon.merchant;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    final won = coupon.isWon;

    final wonCadences = [
      for (final e in coupon.eligibilities)
        if (e.status == 'won') cadenceLabel(e.cadence),
    ];
    final activeCadences = [
      for (final e in coupon.eligibilities)
        if (e.isActive) cadenceLabel(e.cadence),
    ];

    final semanticsParts = [
      'Lucky Draw coupon ${coupon.code}',
      couponStatusLabel(coupon.status),
      if (wonCadences.isNotEmpty) 'Won the ${wonCadences.join(', ')}',
      if (activeCadences.isNotEmpty) 'Entered in ${activeCadences.join(', ')}',
      if (issuedAt != null) 'Issued ${_formatDate(issuedAt)}',
    ];

    return Semantics(
      button: onTap != null,
      label: semanticsParts.join(', '),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: won
                ? const BorderSide(color: AppColors.gold, width: 1.5)
                : const BorderSide(color: AppColors.orangeBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Stub(coupon: coupon),
                  _Perforation(color: won ? AppColors.gold : AppColors.orangeBorder),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.smd, AppSpacing.smd, AppSpacing.sm, AppSpacing.smd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: ExcludeSemantics(
                                        child: Text(
                                          coupon.code,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.textTheme.titleMedium?.copyWith(
                                            fontFamily: 'monospace',
                                            fontFamilyFallback: const ['Menlo', 'Courier New', 'Courier'],
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _CopyButton(code: coupon.code),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _StatusPill(status: coupon.status),
                            ],
                          ),
                          if (issuedAt != null)
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: AppIconSize.xs, color: AppColors.textSecondary),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    merchant == null
                                        ? 'Issued ${_formatDate(issuedAt)}'
                                        : 'Issued ${_formatDate(issuedAt)} · ${merchant.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption,
                                  ),
                                ),
                              ],
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Divider(height: 1, color: won ? AppColors.goldLight : AppColors.border),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    for (final cadence in const ['weekly', 'monthly', 'mega'])
                                      _CadenceChip(cadence: cadence, status: coupon.eligibilityFor(cadence)?.status),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: AppIconSize.md,
                                color: won ? AppColors.orangeDeep : AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ],
                      ),
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

/// The ticket's left stub. A winner's stub is the brand orange; its label
/// sits on the solid deep-orange lower half, where white text passes AA.
class _Stub extends StatelessWidget {
  const _Stub({required this.coupon});

  final Coupon coupon;

  static const _width = 84.0;

  @override
  Widget build(BuildContext context) {
    final (Decoration decoration, IconData icon, Color iconColor, Color circle, Color circleBorder, String label, Color labelColor) =
        switch (coupon.status) {
      'won' => (
          const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.orange, AppColors.orangeDeep],
              stops: [0, 0.55],
            ),
          ),
          Icons.emoji_events_rounded,
          AppColors.onCrimson,
          AppColors.onScrim.withValues(alpha: 0.22),
          AppColors.onScrim.withValues(alpha: 0.5),
          'WINNER',
          AppColors.onCrimson,
        ),
      'expired' => (
          const BoxDecoration(color: AppColors.silverLight),
          Icons.confirmation_number_outlined,
          AppColors.silverDark,
          AppColors.surface,
          AppColors.border,
          'EXPIRED',
          AppColors.silverDark,
        ),
      _ => (
          const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.goldLight, AppColors.orangeTint],
            ),
          ),
          Icons.confirmation_number_rounded,
          AppColors.goldDark,
          AppColors.surface,
          AppColors.gold.withValues(alpha: 0.5),
          'TICKET',
          AppColors.goldDark,
        ),
    };

    return ExcludeSemantics(
      child: Container(
        width: _width,
        decoration: decoration,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.smd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppSize.avatarSm,
              height: AppSize.avatarSm,
              decoration: BoxDecoration(
                color: circle,
                shape: BoxShape.circle,
                border: Border.all(color: circleBorder),
              ),
              child: Icon(icon, size: AppIconSize.md, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: AppTypography.overline.copyWith(color: labelColor, letterSpacing: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dashed tear line between stub and body.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: CustomPaint(size: const Size(1.5, double.infinity), painter: _DashPainter(color)),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  static const _dash = 4.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width;
    for (var y = 0.0; y < size.height; y += _dash + _gap) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, (y + _dash).clamp(0, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy coupon number',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: AppSize.controlSm, height: AppSize.controlSm),
      iconSize: AppIconSize.sm,
      color: AppColors.textSecondary,
      icon: const Icon(Icons.copy_rounded),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Coupon number copied')));
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, Color border, Widget leading, String label) = switch (status) {
      'won' => (
          AppColors.goldLight,
          AppColors.goldDark,
          AppColors.gold.withValues(alpha: 0.5),
          const Icon(Icons.emoji_events_rounded, size: AppIconSize.xs, color: AppColors.gold),
          'Winner',
        ),
      'active' => (
          AppColors.successBg,
          AppColors.success,
          AppColors.success.withValues(alpha: 0.3),
          const _Dot(color: AppColors.success),
          'Active',
        ),
      _ => (
          AppColors.silverLight,
          AppColors.silverDark,
          AppColors.border,
          const _Dot(color: AppColors.silver),
          couponStatusLabel(status),
        ),
    };

    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: AppTypography.badgeLabel.copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

/// One draw cadence: highlighted when this coupon won it, gold while it is
/// still entered, muted once that draw has closed for it.
class _CadenceChip extends StatelessWidget {
  const _CadenceChip({required this.cadence, required this.status});

  final String cadence;
  final String? status;

  static const _shortLabel = {'weekly': 'Weekly', 'monthly': 'Monthly', 'mega': 'Mega'};

  @override
  Widget build(BuildContext context) {
    final label = _shortLabel[cadence] ?? cadence;
    final (Color background, Color foreground, Color? border) = switch (status) {
      'won' => (AppColors.orangeDeep, AppColors.onCrimson, null),
      'active' => (AppColors.goldLight, AppColors.goldDark, AppColors.gold.withValues(alpha: 0.45)),
      _ => (AppColors.silverLight, AppColors.textSecondary, null),
    };

    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.badgeLabel.copyWith(
                  color: foreground,
                  fontWeight: status == 'won' ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (status == 'won') ...[
                const SizedBox(width: AppSpacing.xxs),
                const Icon(Icons.auto_awesome_rounded, size: AppIconSize.xs, color: AppColors.onCrimson),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';
