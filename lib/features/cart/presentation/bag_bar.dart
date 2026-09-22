import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/indian_mobile.dart';
import '../../products/presentation/add_to_bag_button.dart';
import '../../products/presentation/product_price.dart';
import '../application/cart_controller.dart';

/// The docked bag: what is in it, what it comes to, and the order itself.
/// Renders nothing while the bag is empty, so the catalog keeps its full
/// height until something is added.
class BagBar extends ConsumerWidget {
  const BagBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    if (cart.isEmpty) return const SizedBox.shrink();

    final orderable = cart.contactMobileNumber != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            // 2:3, so the action keeps its full label and the summary --
            // whose every line already ellipsizes -- gives way instead.
            Expanded(
              flex: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                onTap: () => showBagSheet(context),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} in bag',
                        style: AppTypography.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Text(
                            formatRupees(cart.total),
                            style: AppTypography.numericFinancialSmall.copyWith(color: AppColors.textPrimary),
                          ),
                          if (cart.saved > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                'Saved ${formatRupees(cart.saved)}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 3, child: _OrderButton(onPressed: orderable ? () => _order(context, ref) : null)),
          ],
        ),
      ),
    );
  }

  Future<void> _order(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartControllerProvider);
    // Already the bare ten digits -- `whatsappUri` is what writes the 91.
    final uri = whatsappUri(cart.contactMobileNumber!, text: buildCartOrderMessage(cart));

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp on this device.')));
    }
  }
}

class _OrderButton extends StatelessWidget {
  const _OrderButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? AppColors.onCrimson : AppColors.textDisabled;

    return Tooltip(
      message: enabled ? 'Order via WhatsApp' : 'This shop has not published a WhatsApp number yet',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: AppSize.controlMd,
          decoration: BoxDecoration(
            gradient: enabled ? const LinearGradient(colors: [AppColors.orange, AppColors.orangeDeep]) : null,
            color: enabled ? null : AppColors.silverLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            boxShadow: enabled ? AppElevation.glow(AppColors.orange) : null,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_rounded, size: AppIconSize.sm, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Order via WhatsApp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
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

/// The bag's own list, for changing it away from the catalog tiles.
Future<void> showBagSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _BagSheet(),
  );
}

class _BagSheet extends ConsumerWidget {
  const _BagSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cart.isEmpty ? 'Your bag' : 'Your bag from ${cart.merchantName}',
                    style: AppTypography.sectionTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!cart.isEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(cartControllerProvider.notifier).clear();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Empty bag'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (cart.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('Nothing in your bag yet.', style: AppTypography.caption),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: AppSpacing.lg, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.product.name,
                                style: AppTypography.textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                '${line.quantity} × ${formatRupees(line.product.price)} = ${formatRupees(line.total)}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AddToBagButton(product: line.product),
                      ],
                    );
                  },
                ),
              ),
            if (!cart.isEmpty) ...[
              const Divider(height: AppSpacing.lg, color: AppColors.border),
              Row(
                children: [
                  Expanded(child: Text('Total', style: AppTypography.textTheme.titleMedium)),
                  Text(
                    formatRupees(cart.total),
                    style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
              if (cart.saved > 0)
                Text(
                  'You save ${formatRupees(cart.saved)}',
                  style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The app bar's bag, with how many items are in it.
class BagButton extends ConsumerWidget {
  const BagButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartControllerProvider.select((cart) => cart.itemCount));

    return IconButton(
      tooltip: count == 0 ? 'Your bag is empty' : 'Your bag, $count ${count == 1 ? 'item' : 'items'}',
      onPressed: () => showBagSheet(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_bag_outlined),
          if (count > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.orangeDeep,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: AppTypography.badgeLabel.copyWith(color: AppColors.onCrimson, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
