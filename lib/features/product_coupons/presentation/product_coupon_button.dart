import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../shared/widgets/app_button.dart';
import '../../products/application/products_list_controller.dart';
import '../../products/data/models/product.dart';
import '../data/product_coupons_repository.dart';

/// "Get coupons" on a product that carries Lucky Draw coupons (a plan
/// feature of its shop). Tapping asks the shop for them; the shop accepts
/// or declines, and accepted coupons join the customer's normal Lucky Draw
/// coupons. Shows what is true for the signed-in customer: nothing to ask
/// for, asked and waiting, or already received.
///
/// [compact] is the pill laid over a catalog tile's photo; otherwise a
/// full-width button for the featured card and the product page.
class ProductCouponButton extends ConsumerStatefulWidget {
  const ProductCouponButton({super.key, required this.product, this.compact = false});

  final Product product;
  final bool compact;

  @override
  ConsumerState<ProductCouponButton> createState() => _ProductCouponButtonState();
}

class _ProductCouponButtonState extends ConsumerState<ProductCouponButton> {
  /// The request state, kept here so a tap shows "Requested" at once --
  /// the list the product came from is not refetched for it.
  late String? _status = widget.product.myCouponRequest;
  bool _sending = false;

  @override
  void didUpdateWidget(covariant ProductCouponButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fresh = widget.product.myCouponRequest;
    if (fresh != null && fresh != _status) _status = fresh;
  }

  int get _coupons => widget.product.couponsPerClaim;

  String get _couponsLabel => _coupons == 1 ? '1 coupon' : '$_coupons coupons';

  Future<void> _ask() async {
    final shop = widget.product.merchantName.isEmpty ? 'the shop' : widget.product.merchantName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Get $_couponsLabel?'),
        content: Text(
          'Ask $shop for $_couponsLabel for "${widget.product.name}". '
          'Ask after you buy this product at the shop — they will accept or decline, '
          'and accepted coupons join your Lucky Draw coupons.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send request')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final request = await ref
          .read(productCouponsRepositoryProvider)
          .request(widget.product.id, idempotencyKey: generateIdempotencyKey());
      if (!mounted) return;
      setState(() => _status = request.status);
      ref.invalidate(productDetailProvider(widget.product.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to $shop.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.product.offersCoupons && _status != 'approved') return const SizedBox.shrink();

    return widget.compact ? _pill(context) : _button(context);
  }

  Widget _button(BuildContext context) {
    return switch (_status) {
      'approved' => _StateRow(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        background: AppColors.successBg,
        label: 'Coupons received for this product',
      ),
      'pending' => _StateRow(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.goldDark,
        background: AppColors.goldLight,
        label: 'Requested — waiting for the shop to accept',
      ),
      _ => AppButton(
        label: 'Get $_couponsLabel',
        icon: Icons.confirmation_number_rounded,
        variant: AppButtonVariant.secondary,
        isLoading: _sending,
        onPressed: _ask,
      ),
    };
  }

  Widget _pill(BuildContext context) {
    final (IconData icon, String label, Color fg, Color bg, VoidCallback? onTap) = switch (_status) {
      'approved' => (Icons.check_circle_rounded, 'Received', AppColors.onCrimson, AppColors.success, null),
      'pending' => (Icons.hourglass_top_rounded, 'Requested', AppColors.goldDark, AppColors.goldLight, null),
      _ => (Icons.confirmation_number_rounded, 'Get $_couponsLabel', AppColors.goldDark, const Color(0xFFF2C94C), _sending ? null : _ask),
    };

    return Semantics(
      button: onTap != null,
      label: onTap != null ? 'Get $_couponsLabel for ${widget.product.name}' : '$label, Lucky Draw coupons',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_sending)
                  SizedBox(
                    width: AppIconSize.xs,
                    height: AppIconSize.xs,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else
                  Icon(icon, size: AppIconSize.xs, color: fg),
                const SizedBox(width: AppSpacing.xs),
                Text(label, style: AppTypography.badgeLabel.copyWith(color: fg, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.icon, required this.color, required this.background, required this.label});

  final IconData icon;
  final Color color;
  final Color background;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.radiusControl)),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.sm, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
