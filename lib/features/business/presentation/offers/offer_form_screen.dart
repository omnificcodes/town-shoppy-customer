import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/image_picker_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../application/business_branches_controller.dart';
import '../../application/business_context.dart';
import '../../application/business_offers_controller.dart';
import '../../data/business_merchant_repository.dart';
import '../../data/business_offers_repository.dart';
import '../../data/models/business_offer.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// Loads the offer named in the URL, then hands it to [OfferFormScreen].
///
/// The form needs a whole [BusinessOffer], and the route used to pass one
/// through GoRouter's `extra`. That is in-memory only: on the hosted web
/// build it does not survive a page reload, so a refreshed `/edit` URL
/// rendered an empty "New offer" form -- and saving it CREATED a second
/// offer instead of editing the one the URL named. The id in the path is
/// the durable half, so it is what this loads from; `extra` is kept only
/// as a hint that paints the filled form instantly when arriving from the
/// list, with no flash of skeleton.
class EditOfferScreen extends ConsumerWidget {
  const EditOfferScreen({super.key, required this.offerId, this.initial});

  final int offerId;
  final BusinessOffer? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessOfferProvider(offerId));
    final offer = async.value ?? initial;

    if (offer != null) {
      return OfferFormScreen(key: ValueKey('offer-form-$offerId'), offer: offer);
    }

    return BusinessScaffold(
      title: 'Edit offer',
      body: async.hasError
          ? ErrorState(
              error: async.error is AppException ? async.error! as AppException : const UnknownAppException(),
              title: 'Could not load this offer',
              onRetry: () => ref.invalidate(businessOfferProvider(offerId)),
            )
          : const LoadingSkeletonList(count: 4),
    );
  }
}

/// Create or edit an offer -- the web form's exact field set, laid out
/// for a phone: image first (it is what customers see), native date and
/// time pickers, the coin-discount toggle revealing its two fields.
class OfferFormScreen extends ConsumerStatefulWidget {
  const OfferFormScreen({super.key, this.offer});

  final BusinessOffer? offer;

  @override
  ConsumerState<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends ConsumerState<OfferFormScreen> {
  late final _title = TextEditingController(text: widget.offer?.title ?? '');
  late final _description = TextEditingController(text: widget.offer?.description ?? '');
  late final _terms = TextEditingController(text: widget.offer?.terms ?? '');
  late final _rate = TextEditingController(text: widget.offer?.coinDiscountRate != null ? _trim(widget.offer!.coinDiscountRate!) : '');
  late final _item = TextEditingController(text: widget.offer?.applicableItem ?? '');
  late String? _imageUrl = widget.offer?.imageUrl;
  late bool _coinRedeemable = widget.offer?.coinDiscountRate != null;
  late bool _flashSale = widget.offer?.isFlashSale ?? false;
  late int? _branchId = widget.offer?.branchId;
  late DateTime? _startsAt = widget.offer?.startsAt?.toLocal();
  late DateTime? _endsAt = widget.offer?.endsAt?.toLocal();

  bool _touched = false;
  bool _uploading = false;
  bool _saving = false;
  AppException? _error;
  Map<String, List<String>> _fieldErrors = const {};

  bool get _isEdit => widget.offer != null;

  /// A live offer has already started, so its start date is a fact rather
  /// than a setting -- the backend refuses to move it, because both public
  /// discovery and redemption gate on `starts_at <= now` and pushing it
  /// forward would hide the offer while it still read as live.
  bool get _isLive => widget.offer?.isActive ?? false;

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_title, _description, _terms, _rate, _item]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _titleError => _title.text.trim().isEmpty ? 'Title is required.' : null;
  String? get _startError => _startsAt == null ? 'Start date is required.' : null;
  String? get _endError => _endsAt == null
      ? 'End date is required.'
      : (_startsAt != null && !_endsAt!.isAfter(_startsAt!))
          ? 'End date must be after the start date.'
          : null;
  String? get _rateError {
    if (!_coinRedeemable) return null;
    final r = double.tryParse(_rate.text.trim());
    return r == null || r <= 0 || r > 100 ? 'Enter a coin discount rate between 0.01 and 100.' : null;
  }

  Future<void> _pickDateTime({required DateTime? initial, required ValueChanged<DateTime> onPicked}) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: initial ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 3));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (time == null) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
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

  Future<void> _save() async {
    setState(() => _touched = true);
    if (_titleError != null || _startError != null || _endError != null || _rateError != null) return;

    final input = OfferInput(
      title: _title.text,
      description: _description.text,
      imageUrl: _imageUrl,
      terms: _terms.text,
      coinDiscountRate: _coinRedeemable ? double.parse(_rate.text.trim()) : null,
      applicableItem: _coinRedeemable ? _item.text : null,
      branchId: _branchId,
      startsAt: _startsAt!,
      endsAt: _endsAt!,
      isFlashSale: _flashSale,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final repo = ref.read(businessOffersRepositoryProvider);
      final saved = _isEdit ? await repo.update(widget.offer!.id, input) : await repo.create(merchantId: ref.read(myMerchantIdProvider)!, input: input);
      ref.invalidate(businessOffersControllerProvider);
      ref.invalidate(businessOfferProvider(saved.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Offer updated.' : 'Offer created as a draft.')));
      context.pushReplacement('${BusinessRoutes.offers}/${saved.id}');
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
    final branches = ref.watch(activeBranchesProvider);
    final textTheme = Theme.of(context).textTheme;
    String? server(String f) => _fieldErrors[f]?.firstOrNull;
    String? show(String? local) => _touched ? local : null;

    return BusinessScaffold(
      title: _isEdit ? 'Edit offer' : 'New offer',
      padded: false,
      bottomBar: AppButton(label: _isEdit ? 'Save changes' : 'Save as draft', isLoading: _saving, onPressed: _uploading ? null : _save),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          InfoBox(
            icon: Icons.info_outline_rounded,
            message: _isEdit
                ? (_isLive
                    ? 'This offer is live — changes reach customers as soon as you save. Its start date is now fixed.'
                    : 'Changes are saved to the draft. Publish it when you are ready.')
                : "Offers start as a draft — publish when you're ready.",
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Offer details', subtitle: 'What customers will see.', icon: Icons.campaign_rounded),
          const SizedBox(height: AppSpacing.smd),
          ImagePickerField(label: 'offer image', previewUrl: _imageUrl, isBusy: _uploading, onPicked: _upload, onRemoved: () => setState(() => _imageUrl = null)),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Title', controller: _title, hintText: 'e.g. Weekend 20% off on all bakery items', errorText: server('title') ?? show(_titleError), textInputAction: TextInputAction.next),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Description', controller: _description, maxLines: 4, maxLength: 5000, hintText: 'Tell customers what the deal is', errorText: server('description')),
          if (branches.length > 1) ...[
            const SizedBox(height: AppSpacing.smd),
            DropdownButtonFormField<int?>(
              value: _branchId,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Branch (optional)', prefixIcon: const Icon(Icons.location_on_outlined), errorText: server('branch_id')),
              items: [const DropdownMenuItem<int?>(value: null, child: Text('All branches')), for (final b in branches) DropdownMenuItem<int?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _branchId = v),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Town Coin discount', subtitle: 'Let customers request a coin discount on this offer, which you approve or reject.', icon: Icons.monetization_on_outlined),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Customers can redeem Town Coin on this offer'),
            value: _coinRedeemable,
            activeColor: AppColors.businessInk,
            onChanged: (v) => setState(() => _coinRedeemable = v),
          ),
          if (_coinRedeemable) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Coin discount rate (%)',
              controller: _rate,
              hintText: 'e.g. 10',
              helperText: 'Up to this share of the bill can be paid with Town Coin.',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              errorText: server('coin_discount_rate') ?? show(_rateError),
            ),
            const SizedBox(height: AppSpacing.smd),
            AppTextField(label: 'Applicable item (optional)', controller: _item, hintText: 'e.g. Any pizza', maxLength: 255, errorText: server('applicable_item')),
          ],
          if (ref.watch(merchantEntitlementProvider).value?.has('flash_sale') ?? false) ...[
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Flash sale', subtitle: 'Shown with a live countdown in the Flash sales strip on the customer Home.', icon: Icons.bolt_rounded),
            const SizedBox(height: AppSpacing.xs),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Run this as a flash sale'),
              subtitle: const Text('Keep it short: a few hours to a day works best.'),
              value: _flashSale,
              activeColor: AppColors.businessInk,
              onChanged: (v) => setState(() => _flashSale = v),
            ),
            if (server('is_flash_sale') != null) Text(server('is_flash_sale')!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Schedule', subtitle: 'When this offer runs.', icon: Icons.schedule_rounded),
          const SizedBox(height: AppSpacing.smd),
          _DateTimeField(label: 'Starts', enabled: !_isLive, helperText: _isLive ? 'Fixed — this offer has already started.' : null, value: _startsAt, errorText: server('starts_at') ?? show(_startError), onTap: () => _pickDateTime(initial: _startsAt, onPicked: (d) => setState(() => _startsAt = d))),
          const SizedBox(height: AppSpacing.smd),
          _DateTimeField(label: 'Ends', value: _endsAt, errorText: server('ends_at') ?? show(_endError), onTap: () => _pickDateTime(initial: _endsAt ?? _startsAt, onPicked: (d) => setState(() => _endsAt = d))),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Terms (optional)', controller: _terms, maxLines: 3, maxLength: 5000, hintText: 'Conditions customers should know', errorText: server('terms')),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: _fieldErrors.isEmpty ? _error!.message : 'Please fix the highlighted fields.'),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text('Customers see the title, image, description and dates. The coin discount shows as a badge they can tap to redeem.', style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.label, required this.value, required this.onTap, this.errorText, this.enabled = true, this.helperText});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;

  /// A disabled field still SHOWS its value -- the merchant needs to read
  /// when their live offer started, just not change it.
  final bool enabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, errorText: errorText, helperText: helperText, enabled: enabled, prefixIcon: const Icon(Icons.event_rounded, size: AppIconSize.md), suffixIcon: const Icon(Icons.arrow_drop_down_rounded)),
        child: Text(
          value == null ? 'Pick a date and time' : formatDateTime(value!),
          style: value == null ? Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).hintColor) : Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
