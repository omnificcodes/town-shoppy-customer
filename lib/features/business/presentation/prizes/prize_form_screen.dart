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
import '../../../../shared/widgets/image_picker_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../application/business_context.dart';
import '../../application/business_prizes_controller.dart';
import '../../data/business_merchant_repository.dart';
import '../../data/models/business_prize.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// "Sponsor a prize" -- the web form's fields; the approving association
/// is the merchant's own and never picked by hand.
class PrizeFormScreen extends ConsumerStatefulWidget {
  const PrizeFormScreen({super.key});

  @override
  ConsumerState<PrizeFormScreen> createState() => _PrizeFormScreenState();
}

class _PrizeFormScreenState extends ConsumerState<PrizeFormScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  String? _imageUrl;
  bool _touched = false;
  bool _uploading = false;
  bool _saving = false;
  AppException? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [_name, _description, _value, _quantity]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError => _name.text.trim().isEmpty ? 'Prize name is required.' : null;
  String? get _valueError {
    final v = _value.text.trim();
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    return n == null || n < 0 || n > 99999999.99 ? 'Enter a valid amount.' : null;
  }

  String? get _quantityError {
    final n = int.tryParse(_quantity.text.trim());
    return n == null || n < 1 || n > 100000 ? 'Enter a whole number between 1 and 100,000.' : null;
  }

  Future<void> _upload(XFile file) async {
    setState(() => _uploading = true);
    try {
      final url = await ref.read(businessMerchantRepositoryProvider).uploadImage(file);
      if (mounted) setState(() => _imageUrl = url);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (_nameError != null || _valueError != null || _quantityError != null) return;
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final created = await ref.read(businessPrizesControllerProvider.notifier).propose(PrizeInput(
            name: _name.text,
            description: _description.text,
            imageUrl: _imageUrl,
            value: _value.text.trim().isEmpty ? null : double.parse(_value.text.trim()),
            quantityTotal: int.parse(_quantity.text.trim()),
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_name.text.trim()} sent for approval.')));
      context.pushReplacement('${BusinessRoutes.prizes}/${created.id}');
    } on StateError {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = const UnknownAppException('Could not determine your association. Try again in a moment.');
        });
      }
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
    final merchant = ref.watch(myMerchantProvider).value;
    String? server(String f) => _fieldErrors[f]?.firstOrNull;
    String? show(String? local) => _touched ? local : null;

    return BusinessScaffold(
      title: 'Sponsor a prize',
      padded: false,
      bottomBar: AppButton(label: _saving ? 'Sending…' : 'Send for approval', icon: Icons.send_rounded, isLoading: _saving, onPressed: _uploading ? null : _submit),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          InfoBox(
            icon: Icons.verified_user_outlined,
            message: merchant?.association != null
                ? '${merchant!.association!.name} reviews every prize before it can be used in a draw.'
                : 'Your association reviews every prize before it can be used in a draw.',
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Prize details', subtitle: "What you're sponsoring for the Lucky Draw.", icon: Icons.emoji_events_rounded),
          const SizedBox(height: AppSpacing.smd),
          ImagePickerField(label: 'prize image', previewUrl: _imageUrl, isBusy: _uploading, onPicked: _upload, onRemoved: () => setState(() => _imageUrl = null)),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Prize name', controller: _name, hintText: 'Smart Watch', errorText: server('name') ?? show(_nameError), textInputAction: TextInputAction.next),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Description', controller: _description, maxLines: 3, maxLength: 2000, errorText: server('description')),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Approximate value (₹)',
            controller: _value,
            hintText: 'Optional',
            helperText: 'Shown to customers and your association admin — purely informational.',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            errorText: server('value') ?? show(_valueError),
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Quantity',
            controller: _quantity,
            helperText: "How many units you're sponsoring — each unit can go to a different winner.",
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: server('quantity_total') ?? show(_quantityError),
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
