import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/multi_image_picker_field.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../products/application/products_list_controller.dart';
import '../../../products/data/models/product.dart';
import '../../../products/presentation/product_price.dart';
import '../../application/business_context.dart';
import '../../application/business_products_controller.dart';
import '../../data/business_merchant_repository.dart';
import '../../data/business_products_repository.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// Loads the product named in the URL, then hands it to [ProductFormScreen].
///
/// The form needs a whole entity, and the route used to pass one through
/// GoRouter's `extra`. That is in-memory only: on the hosted web build it
/// does not survive a page reload, so a refreshed `/edit` URL rendered an
/// empty create form -- and saving it CREATED a second record instead of
/// editing the one the URL named. The id in the path is the durable half,
/// so it is what this loads from; `extra` is kept only as a hint that
/// paints the filled form instantly when arriving from the list.
class EditProductScreen extends ConsumerWidget {
  const EditProductScreen({super.key, required this.productId, this.initial});

  final int productId;
  final Product? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // GET /products/{id} serves the owner their own product whatever its
    // status (ProductController::show()), so an inactive one still edits.
    final async = ref.watch(productDetailProvider(productId));
    final product = async.value ?? initial;

    if (product != null) {
      return ProductFormScreen(key: ValueKey('product-form-$productId'), product: product);
    }

    return BusinessScaffold(
      title: 'Edit product',
      body: async.hasError
          ? ErrorState(
              error: async.error is AppException ? async.error! as AppException : const UnknownAppException(),
              title: 'Could not load this product',
              onRetry: () => ref.invalidate(productDetailProvider(productId)),
            )
          : const LoadingSkeletonList(count: 4),
    );
  }
}

/// The saving the two price fields add up to, updated as they are typed --
/// the merchant never enters a discount, they see the one their prices
/// already make.
class _DiscountPreview extends StatelessWidget {
  const _DiscountPreview({required this.price, required this.mrp});

  final double? price;
  final double? mrp;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = price;
    final m = mrp;
    final saving = p != null && m != null && m > p ? double.parse((m - p).toStringAsFixed(2)) : null;
    final percent = saving != null && m! > 0 ? double.parse((saving / m * 100).toStringAsFixed(1)) : null;
    final discounted = saving != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: discounted ? AppColors.successBg : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: discounted ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            discounted ? Icons.local_offer_rounded : Icons.sell_outlined,
            color: discounted ? AppColors.success : AppColors.textSecondary,
            size: AppIconSize.md,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discounted ? '${formatRupees(saving)} OFF · ${formatPercentOff(percent!)}' : 'No discount',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: discounted ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  p == null
                      ? 'Enter an offer price to see the discount.'
                      : discounted
                      ? 'Customers pay ${formatRupees(p)} instead of ${formatRupees(m!)}.'
                      : 'Customers pay ${formatRupees(p)}.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Create or edit a product -- images first (what customers see), then the
/// basics, then the Town Coin toggle revealing its percentage field. Same
/// plain-`StatefulWidget` + `TextEditingController` shape as
/// [OfferFormScreen], since this app has no Riverpod form-controller
/// convention to follow instead.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description = TextEditingController(text: widget.product?.description ?? '');
  late final _price = TextEditingController(text: widget.product?.price != null ? _trim(widget.product!.price) : '');
  late final _mrp = TextEditingController(text: widget.product?.mrp != null ? _trim(widget.product!.mrp!) : '');
  late final _percentage = TextEditingController(
    text: widget.product?.townCoinPercentage != null ? _trim(widget.product!.townCoinPercentage!) : '',
  );
  late List<String> _imageUrls = List.of(widget.product?.imageUrls ?? const []);
  late bool _acceptsTownCoin = widget.product?.acceptsTownCoin ?? false;
  late bool _active = widget.product?.isActive ?? true;

  bool _touched = false;
  bool _saving = false;
  AppException? _error;
  Map<String, List<String>> _fieldErrors = const {};

  bool get _isEdit => widget.product != null;

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _mrp, _percentage]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError => _name.text.trim().isEmpty ? 'Product name is required.' : null;

  double? get _priceValue => double.tryParse(_price.text.trim());

  /// Empty means "no MRP" -- the product simply has one price.
  double? get _mrpValue => _mrp.text.trim().isEmpty ? null : double.tryParse(_mrp.text.trim());

  String? get _priceError {
    final p = _priceValue;
    return p == null || p < 0 ? 'Enter a valid offer price.' : null;
  }

  String? get _mrpError {
    if (_mrp.text.trim().isEmpty) return null;
    final m = _mrpValue;
    if (m == null || m < 0) return 'Enter a valid actual price.';
    final p = _priceValue;
    if (p != null && m < p) return 'The actual price cannot be less than the offer price.';
    return null;
  }

  String? get _percentageError {
    if (!_acceptsTownCoin) return null;
    final r = double.tryParse(_percentage.text.trim());
    return r == null || r <= 0 || r > 100 ? 'Enter a percentage between 0.01 and 100.' : null;
  }

  Future<String> _upload(XFile image) => ref.read(businessMerchantRepositoryProvider).uploadImage(image);

  Future<void> _save() async {
    setState(() => _touched = true);
    if (_nameError != null || _priceError != null || _mrpError != null || _percentageError != null) return;

    final input = ProductInput(
      name: _name.text,
      price: double.parse(_price.text.trim()),
      mrp: _mrpValue,
      description: _description.text,
      imageUrls: _imageUrls,
      townCoinPercentage: _acceptsTownCoin ? double.parse(_percentage.text.trim()) : null,
      status: _active ? 'active' : 'inactive',
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final repo = ref.read(businessProductsRepositoryProvider);
      final merchantId = ref.read(myMerchantIdProvider);
      if (!_isEdit && merchantId == null) return;
      final saved = _isEdit
          ? await repo.update(widget.product!.id, input)
          : await repo.create(merchantId: merchantId!, input: input);
      await ref.read(businessProductsControllerProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEdit ? 'Product updated.' : 'Product added.')));
      context.pushReplacement('${BusinessRoutes.products}/${saved.id}/edit', extra: saved);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
          _fieldErrors = e is ValidationAppException ? e.fieldErrors : const {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? server(String f) => _fieldErrors[f]?.firstOrNull;
    String? show(String? local) => _touched ? local : null;

    return BusinessScaffold(
      title: _isEdit ? 'Edit product' : 'New product',
      padded: false,
      bottomBar: AppButton(label: _isEdit ? 'Save changes' : 'Add product', isLoading: _saving, onPressed: _save),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          const SectionHeader(
            title: 'Photos',
            subtitle: 'What customers see first.',
            icon: Icons.photo_camera_outlined,
          ),
          const SizedBox(height: AppSpacing.smd),
          MultiImagePickerField(
            urls: _imageUrls,
            onChanged: (urls) => setState(() => _imageUrls = urls),
            onUpload: _upload,
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Product details', icon: Icons.shopping_bag_outlined),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Name',
            controller: _name,
            hintText: 'e.g. Handmade Table Lamp',
            errorText: server('name') ?? show(_nameError),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Description',
            controller: _description,
            maxLines: 4,
            maxLength: 5000,
            hintText: 'Tell customers about this product',
            errorText: server('description'),
          ),
          const SizedBox(height: AppSpacing.smd),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(
            title: 'Pricing',
            subtitle: 'The discount is worked out for you.',
            icon: Icons.sell_outlined,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Actual price / MRP (₹)',
            controller: _mrp,
            hintText: 'e.g. 1000',
            helperText: 'Optional. Leave blank if this product has no discount.',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            errorText: server('mrp') ?? show(_mrpError),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Offer price (₹)',
            controller: _price,
            hintText: 'e.g. 799',
            helperText: 'What the customer pays.',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            errorText: server('price') ?? show(_priceError),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.smd),
          _DiscountPreview(price: _priceValue, mrp: _mrpValue),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(
            title: 'Town Coin',
            subtitle: 'Let customers pay a share of this product with Town Coin.',
            icon: Icons.monetization_on_outlined,
          ),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('This product accepts Town Coin'),
            value: _acceptsTownCoin,
            activeColor: AppColors.businessInk,
            onChanged: (v) => setState(() => _acceptsTownCoin = v),
          ),
          if (_acceptsTownCoin) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Town Coin percentage (%)',
              controller: _percentage,
              hintText: 'e.g. 100',
              helperText: 'This share of the price can be paid with Town Coin.',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              errorText: server('town_coin_percentage') ?? show(_percentageError),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Visibility', icon: Icons.visibility_outlined),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible to customers'),
            subtitle: const Text('Turn off to hide this product without deleting it.'),
            value: _active,
            activeColor: AppColors.businessInk,
            onChanged: (v) => setState(() => _active = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBox(
              icon: Icons.error_outline_rounded,
              tone: AppTone.error,
              message: _fieldErrors.isEmpty ? _error!.message : 'Please fix the highlighted fields.',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
