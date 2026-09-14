import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/multi_image_picker_field.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../products/data/models/product.dart';
import '../../application/business_context.dart';
import '../../application/business_products_controller.dart';
import '../../data/business_merchant_repository.dart';
import '../../data/business_products_repository.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

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
  late final _percentage = TextEditingController(text: widget.product?.townCoinPercentage != null ? _trim(widget.product!.townCoinPercentage!) : '');
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
    for (final c in [_name, _description, _price, _percentage]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError => _name.text.trim().isEmpty ? 'Product name is required.' : null;
  String? get _priceError {
    final p = double.tryParse(_price.text.trim());
    return p == null || p < 0 ? 'Enter a valid price.' : null;
  }

  String? get _percentageError {
    if (!_acceptsTownCoin) return null;
    final r = double.tryParse(_percentage.text.trim());
    return r == null || r <= 0 || r > 100 ? 'Enter a percentage between 0.01 and 100.' : null;
  }

  Future<String> _upload(XFile image) => ref.read(businessMerchantRepositoryProvider).uploadImage(image);

  Future<void> _save() async {
    setState(() => _touched = true);
    if (_nameError != null || _priceError != null || _percentageError != null) return;

    final input = ProductInput(
      name: _name.text,
      price: double.parse(_price.text.trim()),
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
      final saved = _isEdit ? await repo.update(widget.product!.id, input) : await repo.create(merchantId: merchantId!, input: input);
      await ref.read(businessProductsControllerProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Product updated.' : 'Product added.')));
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
          const SectionHeader(title: 'Photos', subtitle: 'What customers see first.', icon: Icons.photo_camera_outlined),
          const SizedBox(height: AppSpacing.smd),
          MultiImagePickerField(urls: _imageUrls, onChanged: (urls) => setState(() => _imageUrls = urls), onUpload: _upload),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Product details', icon: Icons.shopping_bag_outlined),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Name', controller: _name, hintText: 'e.g. Handmade Table Lamp', errorText: server('name') ?? show(_nameError), textInputAction: TextInputAction.next),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Description', controller: _description, maxLines: 4, maxLength: 5000, hintText: 'Tell customers about this product', errorText: server('description')),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Price (₹)',
            controller: _price,
            hintText: 'e.g. 799',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            errorText: server('price') ?? show(_priceError),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Town Coin', subtitle: 'Let customers pay a share of this product with Town Coin.', icon: Icons.monetization_on_outlined),
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
            InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: _fieldErrors.isEmpty ? _error!.message : 'Please fix the highlighted fields.'),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
