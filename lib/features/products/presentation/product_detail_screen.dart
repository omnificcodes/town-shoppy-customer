import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../merchants/presentation/merchant_logo.dart';
import '../application/products_list_controller.dart';
import '../data/models/product.dart';
import 'product_price.dart';

/// A single product, following the Google Stitch redesign: the gallery on
/// its own card with the discount tag, the shop and the product above the
/// price row, what is true about the order, and a docked quantity + order
/// bar.
///
/// Deliberately a TOP-LEVEL, standalone route (not inside the
/// authenticated shell): its whole purpose is to also work for a merchant
/// who taps the link from a WhatsApp order message on a device that may not
/// even be signed in (see `app_router.dart`'s `_redirect`, which carves
/// this one path out of the login gate). Never assumes an `Account` exists.
///
/// Every figure on it is real -- the product resource and nothing else.
/// Stitch's star rating and review count, "Est. 1984", the verified tick,
/// the pack-size selector, the baking-credential badges and the ingredient
/// and shelf-life accordions are absent on purpose: a product records none
/// of them. The heart is absent too -- favorites are per shop, not per
/// product, and this page has to work signed out.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));
    final data = product.value;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      bottomNavigationBar: data == null ? null : _OrderBar(product: data),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(product: data),
            Expanded(
              child: product.when(
                loading: () => const LoadingSkeletonList(count: 2),
                error: (error, _) => ErrorState(
                  error: error is AppException ? error : const UnknownAppException(),
                  onRetry: () => ref.invalidate(productDetailProvider(productId)),
                ),
                data: (data) => _ProductDetailBody(product: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back, the shop this product belongs to, and -- only once there is a
/// product and a web origin to point at -- a button that copies its link.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.product});

  final Product? product;

  @override
  Widget build(BuildContext context) {
    final merchantName = product?.merchantName ?? '';
    final canShare = product != null && Env.customerWebUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: Navigator.canPop(context) ? () => Navigator.of(context).maybePop() : null,
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                children: [
                  Text(
                    merchantName.isEmpty ? 'Product' : merchantName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionTitle.copyWith(letterSpacing: 0.6),
                  ),
                  Text('Product details', style: AppTypography.caption),
                ],
              ),
            ),
          ),
          SizedBox.square(
            dimension: AppSize.controlSm,
            child: canShare ? _CopyLinkButton(productId: product!.id) : null,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.tooltip, this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSize.controlSm,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          iconSize: AppIconSize.md,
          onPressed: onPressed,
          icon: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// There is no share integration in this app, so the share affordance does
/// the one thing it can do honestly: puts the product's public link on the
/// clipboard. Shown only when a web origin is configured -- an unset
/// `CUSTOMER_WEB_URL` would otherwise copy a dead link.
class _CopyLinkButton extends StatelessWidget {
  const _CopyLinkButton({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context) {
    return _CircleButton(
      icon: Icons.link_rounded,
      tooltip: 'Copy link to this product',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: '${Env.customerWebUrl}/products/$productId'));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Link copied')));
      },
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.lg),
      children: [
        _HeroGallery(product: product),
        const SizedBox(height: AppSpacing.smd),
        _OverviewCard(product: product),
        const SizedBox(height: AppSpacing.smd),
        _FactTiles(product: product),
      ],
    );
  }
}

/// The images on their own card, with the discount tag and what the
/// product accepts laid over them.
class _HeroGallery extends StatefulWidget {
  const _HeroGallery({required this.product});

  final Product product;

  @override
  State<_HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<_HeroGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.imageUrls;
    final percent = product.savingPercentage;

    return _Card(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: images.isEmpty
                        ? const _ProductHeroPlaceholder()
                        : PageView.builder(
                            itemCount: images.length,
                            onPageChanged: (page) => setState(() => _page = page),
                            itemBuilder: (context, index) => Image.network(
                              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _ProductHeroPlaceholder(),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.smd,
                left: AppSpacing.smd,
                right: AppSpacing.smd,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (product.acceptsTownCoin)
                            StatusBadge(
                              label: '${_trim(product.townCoinPercentage!)}% with Town Coin',
                              tone: AppTone.success,
                              icon: Icons.savings_rounded,
                            ),
                          if (!product.isActive) const StatusBadge(label: 'Unavailable', tone: AppTone.neutral),
                        ],
                      ),
                    ),
                    if (percent != null) ...[const SizedBox(width: AppSpacing.sm), _DiscountTag(percent: percent)],
                  ],
                ),
              ),
            ],
          ),
          if (images.length > 1) ...[
            const SizedBox(height: AppSpacing.smd),
            _PageDots(count: images.length, current: _page),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _DiscountTag extends StatelessWidget {
  const _DiscountTag({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.crimson, AppColors.orangeDeep]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        boxShadow: AppElevation.glow(AppColors.crimson),
      ),
      child: Text(
        formatPercentOff(percent),
        style: AppTypography.badgeLabel.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Image ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? AppSpacing.lg : AppSpacing.sm,
              height: AppSpacing.xs + 2,
              decoration: BoxDecoration(
                color: i == current ? AppColors.orangeDeep : AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
        ],
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
      child: Center(
        child: Icon(Icons.shopping_bag_rounded, color: AppColors.orange, size: AppIconSize.hero),
      ),
    );
  }
}

/// The shop, the product and what it costs.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = product.description?.trim() ?? '';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.merchantName.isNotEmpty) ...[
            Row(
              children: [
                MerchantLogo(url: product.merchantLogoUrl, merchantName: product.merchantName, size: AppSize.avatarSm),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    product.merchantName,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
              child: Divider(height: 1, color: AppColors.border),
            ),
          ],
          Text(product.name, style: textTheme.headlineSmall),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(description, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.md),
          ProductPrice(product: product, large: true),
        ],
      ),
    );
  }
}

/// What is actually true about ordering this product -- Town Coin, the
/// shop, and how the order reaches it. Nothing here is decorative: each
/// tile restates a fact the product resource carries.
class _FactTiles extends StatelessWidget {
  const _FactTiles({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (product.acceptsTownCoin)
        _FactTile(
          icon: Icons.savings_rounded,
          color: AppColors.success,
          background: AppColors.successBg,
          title: 'Town Coin',
          subtitle: 'Pay up to ${product.townCoinPercentage!.toInt()}% with coins',
        ),
      if (product.merchantName.isNotEmpty)
        _FactTile(
          icon: Icons.storefront_rounded,
          color: AppColors.orangeDeep,
          background: AppColors.orangeTint,
          title: 'Sold by',
          subtitle: product.merchantName,
        ),
      const _FactTile(
        icon: Icons.chat_rounded,
        color: AppColors.info,
        background: AppColors.infoBg,
        title: 'Order on WhatsApp',
        subtitle: 'Details are pre-filled',
      ),
    ];

    // Two to a row, and an odd last tile takes the full width rather than
    // sitting beside a gap.
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final isLastAlone = i == tiles.length - 1;
      rows.add(
        isLastAlone
            ? tiles[i]
            // IntrinsicHeight, because a bare `stretch` row has no height to
            // stretch to inside a list: the taller tile sets the height and
            // its neighbour matches it, so the two bottom edges line up.
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[i]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: tiles[i + 1]),
                  ],
                ),
              ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: AppSpacing.sm));
    }

    return Column(children: rows);
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(AppSpacing.smd),
      radius: AppSpacing.radiusMd,
      child: Row(
        children: [
          Container(
            width: AppSize.controlSm,
            height: AppSize.controlSm,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            child: Icon(icon, size: AppIconSize.md, color: color),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTypography.textTheme.titleSmall),
                Text(subtitle, style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The page's one card shape: white, hairline border, barely-there lift.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding, this.radius});

  final Widget child;
  final EdgeInsets? padding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius ?? AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: child,
    );
  }
}

/// The docked bar: how many, then the order itself.
class _OrderBar extends StatefulWidget {
  const _OrderBar({required this.product});

  final Product product;

  @override
  State<_OrderBar> createState() => _OrderBarState();
}

class _OrderBarState extends State<_OrderBar> {
  static const _maxQuantity = 99;

  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasNumber =
        product.merchantContactMobileNumber != null && product.merchantContactMobileNumber!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppElevation.floating,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.smd, AppSpacing.page, AppSpacing.smd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _QuantityStepper(
                    quantity: _quantity,
                    max: _maxQuantity,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(child: _WhatsAppOrderButton(onPressed: hasNumber ? () => _order(context) : null)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hasNumber
                    ? 'Opens WhatsApp with your order details, addressed to the seller.'
                    : 'This shop has not published a contact number yet.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _order(BuildContext context) async {
    final product = widget.product;
    final digits = product.merchantContactMobileNumber!.replaceAll(RegExp(r'\D'), '');
    final message = buildProductOrderMessage(product, quantity: _quantity);
    final uri = Uri.parse('https://wa.me/91$digits?text=${Uri.encodeComponent(message)}');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp on this device.')));
    }
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.max, required this.onChanged});

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: 'Fewer',
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: AppSpacing.xl,
            child: Semantics(
              label: 'Quantity $quantity',
              excludeSemantics: true,
              child: Text('$quantity', textAlign: TextAlign.center, style: AppTypography.textTheme.titleMedium),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'More',
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSize.controlSm,
      child: Material(
        color: onPressed == null ? AppColors.silverLight : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          iconSize: AppIconSize.md,
          onPressed: onPressed,
          icon: Icon(icon, color: onPressed == null ? AppColors.textDisabled : AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// The page's primary action. Opens a `wa.me` deep link -- the merchant's
/// own published contact number (India-only app, hence the hardcoded "91"
/// country code, same assumption every phone field in this app already
/// makes), pre-filled with the product's details and its public web link so
/// the message is useful even to a merchant who never opens the app. The
/// backend is never involved in sending this -- it is a plain
/// `https://wa.me/...` URL the device's own WhatsApp app opens.
class _WhatsAppOrderButton extends StatelessWidget {
  const _WhatsAppOrderButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? AppColors.onCrimson : AppColors.textDisabled;

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: AppSize.controlLg,
        decoration: BoxDecoration(
          gradient: enabled ? const LinearGradient(colors: [AppColors.orange, AppColors.orangeDeep]) : null,
          color: enabled ? null : AppColors.silverLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: enabled ? AppElevation.glow(AppColors.orange) : null,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_rounded, size: AppIconSize.md, color: foreground),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Order via WhatsApp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The order message itself. Quantity and the total only appear once more
/// than one is being ordered -- a "Quantity: 1" line tells the seller
/// nothing.
String buildProductOrderMessage(Product product, {int quantity = 1}) {
  final saving = product.saving;
  final lines = [
    "Hi! I'd like to order this product:",
    '',
    product.name,
    saving == null
        ? 'Price: ${formatRupees(product.price)}'
        : 'Price: ${formatRupees(product.price)} (MRP ${formatRupees(product.mrp!)}, saving ${formatRupees(saving)})',
    if (quantity > 1) ...['Quantity: $quantity', 'Total: ${formatRupees(product.price * quantity)}'],
    if (product.acceptsTownCoin) 'Accepts Town Coin: ${product.townCoinPercentage!.toInt()}%',
    if (product.description != null && product.description!.trim().isNotEmpty) product.description!.trim(),
    if (Env.customerWebUrl.isNotEmpty) ...['', 'View: ${Env.customerWebUrl}/products/${product.id}'],
  ];
  return lines.join('\n');
}
