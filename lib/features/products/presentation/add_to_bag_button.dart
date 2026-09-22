import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../cart/application/cart_controller.dart';
import '../data/models/product.dart';

/// "+ Add" until the product is in the bag, then the stepper that changes
/// how many. One widget for the grid tile and the featured card, so both
/// behave the same -- including the one rule the bag has: it holds a
/// single shop's products, because checkout messages that one shop.
class AddToBagButton extends ConsumerWidget {
  const AddToBagButton({super.key, required this.product, this.large = false});

  final Product product;

  /// The featured card's roomier treatment.
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartQuantityProvider(product.id));

    // Without a shop there is nobody to send the order to, so the bag
    // would be a dead end.
    final orderable = product.merchantId != null;

    if (quantity == 0) {
      return _AddButton(
        large: large,
        onPressed: orderable ? () => _add(context, ref) : null,
        semanticsLabel: 'Add ${product.name} to bag',
      );
    }

    return _Stepper(
      quantity: quantity,
      large: large,
      onChanged: (value) {
        HapticFeedback.selectionClick();
        ref.read(cartControllerProvider.notifier).setQuantity(product, value);
      },
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    if (ref.read(cartControllerProvider.notifier).add(product)) return;

    final otherShop = ref.read(cartControllerProvider).merchantName;
    final startNew = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new bag?'),
        content: Text(
          'Your bag has items from $otherShop. An order goes to one shop at a time, '
          'so adding this starts a new bag.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep my bag')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Start new bag')),
        ],
      ),
    );

    if (startNew ?? false) ref.read(cartControllerProvider.notifier).startNewBagWith(product);
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.large, required this.semanticsLabel, this.onPressed});

  final bool large;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final height = large ? AppSize.controlMd : AppSize.controlSm;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Material(
          color: enabled ? AppColors.orangeTint : AppColors.silverLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: large ? AppSpacing.md : AppSpacing.smd),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: AppIconSize.sm,
                    color: enabled ? AppColors.orangeDeep : AppColors.textDisabled,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Add',
                    style: AppTypography.textTheme.labelMedium?.copyWith(
                      color: enabled ? AppColors.orangeDeep : AppColors.textDisabled,
                      fontWeight: FontWeight.w800,
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

class _Stepper extends StatelessWidget {
  const _Stepper({required this.quantity, required this.large, required this.onChanged});

  final int quantity;
  final bool large;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final button = large ? AppSize.controlSm : 28.0;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            tooltip: quantity == 1 ? 'Remove from bag' : 'One fewer',
            size: button,
            onPressed: () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: large ? AppSpacing.lg : AppSpacing.md + AppSpacing.xxs,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'One more',
            size: button,
            accent: true,
            onPressed: quantity < CartController.maxQuantityPerLine ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    this.accent = false,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final bool accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = accent ? (enabled ? AppColors.orangeDeep : AppColors.silverLight) : AppColors.surface;
    final foreground = accent
        ? (enabled ? AppColors.onCrimson : AppColors.textDisabled)
        : (enabled ? AppColors.textPrimary : AppColors.textDisabled);

    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, size: AppIconSize.sm, color: foreground),
          ),
        ),
      ),
    );
  }
}
