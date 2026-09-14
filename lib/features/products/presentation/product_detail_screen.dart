import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/products_list_controller.dart';
import '../data/models/product.dart';

/// A single product -- deliberately a TOP-LEVEL, standalone route (not
/// inside the authenticated shell): its whole purpose is to also work for
/// a merchant who taps the link from a WhatsApp order message on a device
/// that may not even be signed in (see `app_router.dart`'s `_redirect`,
/// which carves this one path out of the login gate). Never assumes an
/// `Account` exists.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: SafeArea(
        child: product.when(
          loading: () => const LoadingSkeletonList(count: 2),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(productDetailProvider(productId)),
          ),
          data: (data) => _ProductDetailBody(product: data),
        ),
      ),
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _ImageGallery(product: product),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.acceptsTownCoin) ...[
                StatusBadge(label: '${_trim(product.townCoinPercentage!)}% payable with Town Coin', tone: AppTone.success, icon: Icons.savings_rounded, large: true),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(product.name, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text('₹${_trim(product.price)}', style: textTheme.headlineMedium?.copyWith(color: AppColors.orange)),
              if (product.merchantName.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: AppIconSize.sm, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(child: Text(product.merchantName, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
              if (product.description != null && product.description!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                Text('Description', style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(product.description!, style: textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              _WhatsAppOrderButton(product: product),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Opens WhatsApp with your order details pre-filled, addressed to the seller.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (product.imageUrls.isEmpty) {
      return const AspectRatio(aspectRatio: 1, child: _ProductHeroPlaceholder());
    }

    return AspectRatio(
      aspectRatio: 1,
      child: PageView.builder(
        itemCount: product.imageUrls.length,
        itemBuilder: (context, index) => Image.network(
          product.imageUrls[index],
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _ProductHeroPlaceholder(),
        ),
      ),
    );
  }
}

class _ProductHeroPlaceholder extends StatelessWidget {
  const _ProductHeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.orangeTintStrong, AppColors.orangeTint])),
      child: Center(child: Icon(Icons.shopping_bag_rounded, color: AppColors.orange, size: AppIconSize.hero)),
    );
  }
}

/// Builds a `wa.me` deep link -- the merchant's own published contact
/// number (India-only app, hence the hardcoded "91" country code, same
/// assumption every phone field in this app already makes), pre-filled
/// with the product's details and its public web link so the message is
/// useful even to a merchant who never opens the app. The backend is never
/// involved in sending this -- it is a plain `https://wa.me/...` URL the
/// device's own WhatsApp app opens.
class _WhatsAppOrderButton extends StatelessWidget {
  const _WhatsAppOrderButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final hasNumber = product.merchantContactMobileNumber != null && product.merchantContactMobileNumber!.trim().isNotEmpty;

    return AppButton(
      label: 'Order via WhatsApp',
      icon: Icons.chat_rounded,
      size: AppButtonSize.lg,
      onPressed: hasNumber ? () => _order(context) : null,
    );
  }

  Future<void> _order(BuildContext context) async {
    final digits = product.merchantContactMobileNumber!.replaceAll(RegExp(r'\D'), '');
    final message = _buildMessage();
    final uri = Uri.parse('https://wa.me/91$digits?text=${Uri.encodeComponent(message)}');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp on this device.')));
    }
  }

  String _buildMessage() {
    final price = product.price == product.price.roundToDouble() ? product.price.toInt().toString() : product.price.toStringAsFixed(2);
    final lines = [
      "Hi! I'd like to order this product:",
      '',
      product.name,
      'Price: ₹$price',
      if (product.acceptsTownCoin) 'Accepts Town Coin: ${product.townCoinPercentage!.toInt()}%',
      if (product.description != null && product.description!.trim().isNotEmpty) product.description!.trim(),
      if (Env.customerWebUrl.isNotEmpty) ...['', 'View: ${Env.customerWebUrl}/products/${product.id}'],
    ];
    return lines.join('\n');
  }
}
