import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../merchants/presentation/merchant_logo.dart';
import '../../application/business_context.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// The shop's online store link (BR-43): a public web page with its
/// details, offers, products, contact buttons and review QR, printed here
/// as a poster with a QR and a shareable link. The page itself is served
/// by the API and only lives while the plan carries the item.
class BusinessOnlineStoreScreen extends ConsumerWidget {
  const BusinessOnlineStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(myMerchantProvider);
    final entitlement = ref.watch(merchantEntitlementProvider).value;
    final inPlan = entitlement == null || entitlement.has('online_store_page');

    return BusinessScaffold(
      title: 'Online store',
      padded: false,
      body: merchant.when(
        loading: () => const LoadingSkeletonList(),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load your shop.',
          onRetry: () => ref.invalidate(myMerchantProvider),
        ),
        data: (m) {
          final url = m.storeUrl;
          if (url == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.page),
              child: InfoBox(icon: Icons.info_outline_rounded, message: 'Your store link is being prepared. Pull to refresh in a moment.'),
            );
          }
          final shortUrl = url.replaceFirst(RegExp(r'^https?://'), '');

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
            children: [
              if (!inPlan) ...[
                const InfoBox(
                  icon: Icons.workspace_premium_outlined,
                  message: 'The online store page is not included in your current plan. Your link is reserved, and goes live the moment you move to a plan that includes it.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _StorePoster(name: m.name, logoUrl: m.logoUrl, tagline: m.tagline, url: url, shortUrl: shortUrl, live: inPlan),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.copy_rounded,
                      label: 'Copy link',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store link copied.')));
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.chat_rounded,
                      label: 'Share',
                      onTap: () => launchUrl(
                        Uri.parse('https://wa.me/?text=${Uri.encodeComponent('${m.name} on Town Shoppy: $url')}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.open_in_new_rounded,
                      label: 'Open',
                      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('WHAT CUSTOMERS SEE', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: AppSpacing.sm),
              const _IncludedList(),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Edit shop profile',
                icon: Icons.storefront_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(BusinessRoutes.profile),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StorePoster extends StatelessWidget {
  const _StorePoster({required this.name, required this.url, required this.shortUrl, required this.live, this.logoUrl, this.tagline});

  final String name;
  final String? logoUrl;
  final String? tagline;
  final String url;
  final String shortUrl;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxWidth - 2 * AppSpacing.xl - 2 * AppSpacing.md).clamp(150.0, 230.0);
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.businessInk, AppColors.businessInkDeep],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                child: MerchantLogo(url: logoUrl, merchantName: name, size: 52),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(color: AppColors.onBusinessInk, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                (tagline ?? '').trim().isEmpty ? 'Scan to see our products, offers and more' : tagline!.trim(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted),
              ),
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
                      data: url,
                      size: qrSize,
                      backgroundColor: AppColors.surface,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.businessInk),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.businessInk),
                    ),
                    if (!live)
                      Container(
                        width: qrSize,
                        height: qrSize,
                        color: AppColors.surface.withValues(alpha: 0.86),
                        alignment: Alignment.center,
                        child: Text('Not in plan', style: textTheme.titleSmall),
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
                    child: Text('Scan to open our online store', textAlign: TextAlign.center, style: textTheme.labelMedium?.copyWith(color: AppColors.onBusinessInkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              SelectableText(shortUrl, textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(color: AppColors.onBusinessInkMuted, letterSpacing: 0.3)),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: AppColors.border)),
          child: Column(
            children: [
              Icon(icon, color: AppColors.businessInk),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncludedList extends StatelessWidget {
  const _IncludedList();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (Icons.storefront_rounded, 'Your name, logo, cover and category'),
      (Icons.phone_rounded, 'Call, WhatsApp and directions buttons'),
      (Icons.local_offer_rounded, 'Live offers and flash sales'),
      (Icons.shopping_bag_rounded, 'Products with "Order on WhatsApp"'),
      (Icons.monetization_on_rounded, 'Your Town Coin discount'),
      (Icons.star_rate_rounded, 'Your review QR, when set up'),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(row.$1, size: AppIconSize.md, color: AppColors.businessInk),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(row.$2, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
