import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/image_picker_field.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../core/errors/app_exception.dart';
import '../../merchants/application/merchant_categories_provider.dart';
import '../application/business_context.dart';
import '../application/edit_business_profile_controller.dart';
import '../data/business_merchant_repository.dart';
import '../data/models/business_hours.dart';
import '../data/models/business_merchant.dart';
import 'widgets/business_page_header.dart';

/// Every field the merchant web app's edit sheet exposes, in the same
/// sections. Logo/cover upload immediately on pick (the URL is what gets
/// saved); empty text clears the column. Owner only -- the router never
/// lets staff in here, and the backend 403s anyway.
class EditBusinessProfileScreen extends ConsumerStatefulWidget {
  const EditBusinessProfileScreen({super.key});

  @override
  ConsumerState<EditBusinessProfileScreen> createState() => _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends ConsumerState<EditBusinessProfileScreen> {
  final _name = TextEditingController();
  final _ownerName = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _gst = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _discount = TextEditingController();
  final List<_SocialLinkRow> _social = [];
  final Map<String, DayHours> _hours = {};

  int? _categoryId;
  String? _logoUrl;
  String? _coverUrl;
  bool _acceptsTownCoin = false;
  bool _initialized = false;
  bool _touched = false;

  @override
  void dispose() {
    for (final c in [_name, _ownerName, _tagline, _description, _gst, _phone, _email, _website, _discount]) {
      c.dispose();
    }
    for (final r in _social) {
      r.dispose();
    }
    super.dispose();
  }

  void _initFrom(BusinessMerchant m) {
    if (_initialized) return;
    _initialized = true;
    _name.text = m.name;
    _ownerName.text = m.ownerName ?? '';
    _tagline.text = m.tagline ?? '';
    _description.text = m.description ?? '';
    _gst.text = m.gstNumber ?? '';
    _phone.text = m.contactMobileNumber ?? '';
    _email.text = m.contactEmail ?? '';
    _website.text = m.websiteUrl ?? '';
    _discount.text = m.discountRate == null ? '' : (m.discountRate == m.discountRate!.roundToDouble() ? m.discountRate!.toInt().toString() : m.discountRate.toString());
    _categoryId = m.category?.id;
    _logoUrl = m.logoUrl;
    _coverUrl = m.coverImageUrl;
    _acceptsTownCoin = m.acceptsTownCoin;
    for (final e in m.socialLinks?.entries ?? const <MapEntry<String, String>>[]) {
      _social.add(_SocialLinkRow(platform: e.key, url: e.value));
    }
    for (final day in merchantWeekdays) {
      _hours[day] = m.businessHours?.forDay(day) ?? DayHours.unset;
    }
  }

  String? get _nameError => _name.text.trim().isEmpty ? 'Name is required.' : null;
  String? get _ownerError => _ownerName.text.trim().isEmpty ? 'Owner name is required.' : null;
  String? get _emailError {
    final v = _email.text.trim();
    if (v.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Enter a valid email address.';
  }

  String? get _websiteError {
    final v = _website.text.trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty ? null : 'Enter a valid URL.';
  }

  String? get _discountError {
    final v = _discount.text.trim();
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    return n == null || n < 0 || n > 100 ? 'Enter a number between 0 and 100.' : null;
  }

  Future<void> _pickTime(String day, {required bool opening}) async {
    final current = _hours[day]!;
    final raw = opening ? current.open : current.close;
    final parts = raw.split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => _hours[day] = opening ? current.copyWith(open: text) : current.copyWith(close: text));
  }

  void _submit(int merchantId) {
    setState(() => _touched = true);
    if (_nameError != null || _ownerError != null || _emailError != null || _websiteError != null || _discountError != null) return;

    final social = <String, String>{
      for (final r in _social)
        if (r.platform.text.trim().isNotEmpty && r.url.text.trim().isNotEmpty) r.platform.text.trim(): r.url.text.trim(),
    };

    ref.read(editBusinessProfileControllerProvider.notifier).submit(
          merchantId,
          buildMerchantUpdateBody(
            name: _name.text,
            ownerName: _ownerName.text,
            tagline: _tagline.text,
            categoryId: _categoryId,
            contactMobileNumber: _phone.text,
            contactEmail: _email.text,
            description: _description.text,
            gstNumber: _gst.text,
            logoUrl: _logoUrl,
            coverImageUrl: _coverUrl,
            websiteUrl: _website.text,
            discountRate: _discount.text,
            acceptsTownCoin: _acceptsTownCoin,
            socialLinks: social,
            businessHours: BusinessHours(_hours),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final merchant = ref.watch(myMerchantProvider);
    final state = ref.watch(editBusinessProfileControllerProvider);
    final categories = ref.watch(merchantCategoriesProvider);

    ref.listen(editBusinessProfileControllerProvider, (prev, next) {
      if (next.success && prev?.success != true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_name.text.trim()} updated.')));
        context.pop();
      }
    });

    return BusinessScaffold(
      title: 'Edit business',
      padded: false,
      body: merchant.when(
        loading: () => const LoadingSkeletonList(count: 6),
        error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), onRetry: () => ref.invalidate(myMerchantProvider)),
        data: (m) {
          _initFrom(m);
          String? serverError(String field) => state.fieldErrors[field]?.firstOrNull;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const SectionHeader(title: 'Basic information', subtitle: 'Core details customers see.', icon: Icons.storefront_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(label: 'Business name', controller: _name, errorText: serverError('name') ?? (_touched ? _nameError : null), textInputAction: TextInputAction.next),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(label: 'Owner name', controller: _ownerName, errorText: serverError('owner_name') ?? (_touched ? _ownerError : null), textInputAction: TextInputAction.next),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(label: 'Tagline', controller: _tagline, hintText: 'A short line under your business name', maxLength: 255, errorText: serverError('tagline')),
              const SizedBox(height: AppSpacing.smd),
              categories.when(
                loading: () => const LoadingSkeleton(height: AppSize.field),
                error: (_, _) => AppTextField(label: 'Category', enabled: false, hintText: 'Could not load categories'),
                data: (list) => DropdownButtonFormField<int>(
                  value: list.any((c) => c.id == _categoryId) ? _categoryId : null,
                  decoration: InputDecoration(labelText: 'Category', errorText: serverError('category_id')),
                  items: [for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(label: 'Description', controller: _description, maxLines: 4, maxLength: 2000, hintText: 'What do you sell? What makes your business unique?', errorText: serverError('description')),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(label: 'GST number', controller: _gst, maxLength: 32, errorText: serverError('gst_number')),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Contact', subtitle: 'How customers reach your business directly.', icon: Icons.phone_outlined),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(
                label: 'Business phone',
                controller: _phone,
                hintText: '9876543210',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                errorText: serverError('contact_mobile_number'),
              ),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(
                label: 'Business email',
                controller: _email,
                hintText: 'hello@business.com',
                keyboardType: TextInputType.emailAddress,
                errorText: serverError('contact_email') ?? (_touched ? _emailError : null),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Web presence', subtitle: 'Website, logo, and social links.', icon: Icons.language_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(label: 'Website', controller: _website, hintText: 'https://…', keyboardType: TextInputType.url, errorText: serverError('website_url') ?? (_touched ? _websiteError : null)),
              const SizedBox(height: AppSpacing.smd),
              Text('Logo', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              ImagePickerField(
                label: 'logo',
                previewUrl: _logoUrl,
                isBusy: state.isUploading,
                onPicked: (file) async {
                  final url = await ref.read(editBusinessProfileControllerProvider.notifier).upload(file);
                  if (url != null && mounted) setState(() => _logoUrl = url);
                },
                onRemoved: () => setState(() => _logoUrl = null),
              ),
              const SizedBox(height: AppSpacing.smd),
              Text('Cover image', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text('The banner shown at the top of the storefront profile.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              ImagePickerField(
                label: 'cover image',
                previewUrl: _coverUrl,
                isBusy: state.isUploading,
                onPicked: (file) async {
                  final url = await ref.read(editBusinessProfileControllerProvider.notifier).upload(file);
                  if (url != null && mounted) setState(() => _coverUrl = url);
                },
                onRemoved: () => setState(() => _coverUrl = null),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Social links', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              for (var i = 0; i < _social.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 110, child: AppTextField(label: 'Platform', controller: _social[i].platform, hintText: 'instagram')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: AppTextField(label: 'Link', controller: _social[i].url, hintText: 'https://…', keyboardType: TextInputType.url)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
                        tooltip: 'Remove social link',
                        onPressed: () => setState(() => _social.removeAt(i).dispose()),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _social.add(_SocialLinkRow())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add social link'),
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Business hours', subtitle: 'When customers can find you open, per day.', icon: Icons.schedule_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, day) in merchantWeekdays.indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                      _DayHoursRow(
                        label: weekdayLabel(day),
                        hours: _hours[day]!,
                        onToggle: (open) => setState(() => _hours[day] = _hours[day]!.copyWith(closed: !open)),
                        onPickOpen: () => _pickTime(day, opening: true),
                        onPickClose: () => _pickTime(day, opening: false),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Rewards', subtitle: 'Discounts and Town Coin settings.', icon: Icons.percent_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppTextField(
                label: 'Discount rate (%)',
                controller: _discount,
                helperText: 'Leave blank if this business has no standard discount.',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                errorText: serverError('discount_rate') ?? (_touched ? _discountError : null),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accepts Town Coin'),
                subtitle: const Text('Customers can spend Town Coin at your counter'),
                value: _acceptsTownCoin,
                activeColor: AppColors.businessInk,
                onChanged: (v) => setState(() => _acceptsTownCoin = v),
              ),
              const SizedBox(height: AppSpacing.section),
              if (state.error != null) ...[
                InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: state.error!.message),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(label: 'Save changes', isLoading: state.isSubmitting, onPressed: state.isUploading ? null : () => _submit(m.id)),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _SocialLinkRow {
  _SocialLinkRow({String platform = '', String url = ''})
      : platform = TextEditingController(text: platform),
        url = TextEditingController(text: url);

  final TextEditingController platform;
  final TextEditingController url;

  void dispose() {
    platform.dispose();
    url.dispose();
  }
}

class _DayHoursRow extends StatelessWidget {
  const _DayHoursRow({required this.label, required this.hours, required this.onToggle, required this.onPickOpen, required this.onPickClose});

  final String label;
  final DayHours hours;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: textTheme.titleSmall)),
              Text(hours.closed ? 'Closed' : 'Open', style: textTheme.bodySmall),
              const SizedBox(width: AppSpacing.xs),
              Switch.adaptive(value: !hours.closed, activeColor: AppColors.businessInk, onChanged: onToggle),
            ],
          ),
          if (!hours.closed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(child: _TimeChip(label: hours.open, onTap: onPickOpen)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm), child: Text('to', style: textTheme.bodySmall)),
                  Expanded(child: _TimeChip(label: hours.close, onTap: onPickClose)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, AppSize.controlSm), padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd)),
      icon: const Icon(Icons.access_time_rounded, size: AppIconSize.sm),
      label: Text(label),
    );
  }
}
