import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../merchants/presentation/merchant_logo.dart';
import '../../data/models/review_link.dart';

/// A row of [count] gold stars out of five.
class ReviewStars extends StatelessWidget {
  const ReviewStars({super.key, required this.count, this.size = AppIconSize.sm, this.emptyColor});

  final int count;
  final double size;
  final Color? emptyColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                Icons.star_rounded,
                size: size,
                color: i <= count ? const Color(0xFFFFB400) : (emptyColor ?? AppColors.border),
              ),
          ],
        ),
      ),
    );
  }
}

/// The poster a shop shows at the counter: logo, name, the ask, and the
/// QR code that opens the rating page. Built to read well in a screenshot.
class ReviewPoster extends StatelessWidget {
  const ReviewPoster({super.key, required this.link, required this.merchantName, this.logoUrl});

  final ReviewLink link;
  final String merchantName;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxWidth - 2 * AppSpacing.xl - 2 * AppSpacing.md).clamp(150.0, 230.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.businessInk, AppColors.businessInkDeep],
              ),
            ),
            child: Stack(
              children: [
                // Soft brand glows behind the content.
                Positioned(top: -60, right: -40, child: _Glow(color: AppColors.orange.withValues(alpha: 0.35), size: 200)),
                Positioned(bottom: -70, left: -50, child: _Glow(color: const Color(0xFFFFB400).withValues(alpha: 0.18), size: 220)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        child: MerchantLogo(url: logoUrl, merchantName: merchantName, size: 52),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        merchantName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(color: AppColors.onBusinessInk, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('Loved your visit? Rate us!', style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted)),
                      const SizedBox(height: AppSpacing.sm),
                      const ReviewStars(count: 5, size: 26),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12))],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: link.publicUrl,
                              size: qrSize,
                              backgroundColor: AppColors.surface,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.businessInk),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.businessInk),
                            ),
                            if (!link.isActive)
                              Container(
                                width: qrSize,
                                height: qrSize,
                                color: AppColors.surface.withValues(alpha: 0.86),
                                alignment: Alignment.center,
                                child: const StatusBadge(label: 'Paused', tone: AppTone.neutral),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.smd),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: AppIconSize.sm, color: AppColors.onBusinessInkMuted),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              'Scan with your phone camera',
                              textAlign: TextAlign.center,
                              style: textTheme.labelMedium?.copyWith(color: AppColors.onBusinessInkMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      SelectableText(
                        link.shortUrl,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall?.copyWith(color: AppColors.onBusinessInkMuted, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
    );
  }
}

/// The three steps, shown before setup and as a reminder after.
class ReviewHowItWorks extends StatelessWidget {
  const ReviewHowItWorks({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.qr_code_2_rounded, 'Customer scans', 'Your QR at the counter'),
      (Icons.star_rounded, 'Rates the visit', 'One tap, 1 to 5 stars'),
      (Icons.rate_review_rounded, '4★+ go to Google', 'Lower ratings come to you'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: AppColors.textDisabled),
            ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: i == 2 ? AppColors.successBg : AppColors.businessTint,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                  child: Icon(step.$1, color: i == 1 ? const Color(0xFFFFB400) : (i == 2 ? AppColors.success : AppColors.businessInk)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(step.$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (!compact) Text(step.$3, textAlign: TextAlign.center, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One rating through the link: stars, when, the note and who left it.
class ReviewResponseCard extends StatelessWidget {
  const ReviewResponseCard({super.key, required this.response});

  final ReviewResponse response;

  bool get _isPhone => RegExp(r'^\+?[0-9 ]{8,15}$').hasMatch(response.contact?.trim() ?? '');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final who = [response.customerName, response.contact].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReviewStars(count: response.rating),
              const SizedBox(width: AppSpacing.sm),
              if (response.sentToGoogle) const StatusBadge(label: 'Sent to Google', tone: AppTone.success),
              const Spacer(),
              Text(relativeTime(response.createdAt), style: AppTypography.caption),
            ],
          ),
          if (response.feedback != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(response.feedback!, style: textTheme.bodyMedium),
          ] else if (!response.sentToGoogle) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('No note left', style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (who.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: AppIconSize.sm, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(who, style: textTheme.labelMedium?.copyWith(color: AppColors.textSecondary))),
                if (_isPhone)
                  IconButton(
                    tooltip: 'Call ${response.customerName ?? 'customer'}',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.call_rounded, size: AppIconSize.md, color: AppColors.businessInk),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: response.contact!.replaceAll(' ', ''))),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
