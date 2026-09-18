import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/image_picker_field.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/location_picker.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../merchants/application/merchant_categories_provider.dart';
import '../application/merchant_registration_controller.dart';
import '../data/models/merchant_registration_input.dart';
import '../data/reference_data_repository.dart';
import 'business_routes.dart';

/// "Register as a merchant" -- the merchant web app's two-step wizard on
/// a phone. Step 1 collects the business; step 2 (only when nobody is
/// signed in) creates the account, because `POST /merchants` needs a
/// bearer token. A signed-in customer submits straight from step 1.
/// On success the applicant is already the merchant's Owner (status
/// `pending` until a Super Admin approves) and lands in Business mode.
class MerchantRegisterScreen extends ConsumerStatefulWidget {
  const MerchantRegisterScreen({super.key});

  @override
  ConsumerState<MerchantRegisterScreen> createState() => _MerchantRegisterScreenState();
}

enum _Step { business, identity }

class _MerchantRegisterScreenState extends ConsumerState<MerchantRegisterScreen> {
  // Step 1
  final _name = TextEditingController();
  final _ownerName = TextEditingController();
  final _description = TextEditingController();
  final _contactMobile = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  int? _categoryId;
  int? _townId;
  int? _associationId;
  LatLng? _pin;
  XFile? _logo;
  XFile? _cover;

  // Step 2
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  _Step _step = _Step.business;
  bool _touchedBusiness = false;
  bool _touchedIdentity = false;
  bool _prefilledOwner = false;

  @override
  void dispose() {
    for (final c in [_name, _ownerName, _description, _contactMobile, _address, _city, _state, _postalCode, _mobile, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- validation (UX-only; the backend's FormRequest is authoritative) ----
  String? get _nameError => _name.text.trim().isEmpty ? 'Business name is required.' : null;
  String? get _ownerError => _ownerName.text.trim().isEmpty ? 'Owner name is required.' : null;
  String? get _categoryError => _categoryId == null ? 'Category is required.' : null;
  String? get _townError => _townId == null ? 'Select a town first.' : null;
  String? get _associationError => _associationId == null ? 'Association is required.' : null;
  String? get _addressError => _address.text.trim().isEmpty ? 'Address is required.' : null;
  String? get _pinError => _pin == null ? "Pin your business's location on the map." : null;
  bool get _businessValid =>
      [_nameError, _ownerError, _categoryError, _townError, _associationError, _addressError, _pinError].every((e) => e == null);

  String? get _mobileError => _mobile.text.replaceAll(RegExp(r'[^0-9]'), '').length < 10 ? 'Enter a valid mobile number.' : null;
  String? get _passwordError => _password.text.length < 8 ? 'Use at least 8 characters.' : null;
  String? get _confirmError => _confirm.text != _password.text ? "Passwords don't match." : null;
  bool get _identityValid => [_mobileError, _passwordError, _confirmError].every((e) => e == null);

  MerchantRegistrationInput _buildInput({String? logoUrl, String? coverImageUrl}) => MerchantRegistrationInput(
        name: _name.text,
        ownerName: _ownerName.text,
        associationId: _associationId!,
        categoryId: _categoryId!,
        addressLine: _address.text,
        latitude: _pin!.latitude,
        longitude: _pin!.longitude,
        city: _city.text,
        state: _state.text,
        postalCode: _postalCode.text,
        contactMobileNumber: _contactMobile.text,
        description: _description.text,
        logoUrl: logoUrl,
        coverImageUrl: coverImageUrl,
      );

  void _continueFromBusiness(bool signedIn) {
    setState(() => _touchedBusiness = true);
    if (!_businessValid) return;
    if (signedIn) {
      ref.read(merchantRegistrationControllerProvider.notifier).submit(buildInput: _buildInput, logo: _logo, cover: _cover);
    } else {
      setState(() => _step = _Step.identity);
    }
  }

  void _submitIdentity() {
    setState(() => _touchedIdentity = true);
    if (!_identityValid) return;
    ref.read(merchantRegistrationControllerProvider.notifier).submit(
          buildInput: _buildInput,
          logo: _logo,
          cover: _cover,
          createAccount: (mobileNumber: _mobile.text.trim(), name: _ownerName.text.trim(), password: _password.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final account = auth is AuthAuthenticated ? auth.account : null;
    final state = ref.watch(merchantRegistrationControllerProvider);

    if (account != null && !_prefilledOwner) {
      _prefilledOwner = true;
      if (_ownerName.text.isEmpty) _ownerName.text = account.customerProfile?.name ?? '';
    }

    // A server-side validation failure on the merchant itself sends the
    // applicant back to the business step, where the field lives.
    ref.listen(merchantRegistrationControllerProvider, (prev, next) {
      if (next.error != null && next.fieldErrors.keys.any((k) => !{'mobile_number', 'password', 'name'}.contains(k)) && _step == _Step.identity) {
        setState(() => _step = _Step.business);
      }
    });

    if (state.registered != null) {
      return _SuccessView(imageUploadFailed: state.imageUploadFailed);
    }

    return Scaffold(
      backgroundColor: AuthPalette.cream,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                AuthHeader(
                  onBack: () {
                    if (_step == _Step.identity) {
                      setState(() => _step = _Step.business);
                    } else if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(account == null ? '/login' : '/home');
                    }
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                    children: [
                      const AuthBrandBlock(logoHeight: 56),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Join Town Shoppy', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AuthPalette.brown)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        account != null
                            ? 'Signed in as ${account.mobileNumber}. A Super Admin reviews every application.'
                            : "Tell us about your business — you'll set a password next. A Super Admin reviews every application.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AuthPalette.mutedText),
                      ),
                      if (account == null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Already have an account? ', style: Theme.of(context).textTheme.bodySmall),
                            InkWell(
                              onTap: () => context.go('/login'),
                              child: Text('Sign in', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.orangeDeep, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _StepIndicator(current: _step, showIdentity: account == null),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                          border: Border.all(color: AuthPalette.fieldBorder),
                          boxShadow: AppElevation.subtle,
                        ),
                        child: _step == _Step.business ? _businessForm(state, signedIn: account != null) : _identityForm(state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessForm(MerchantRegistrationState state, {required bool signedIn}) {
    final categories = ref.watch(merchantCategoriesProvider);
    final towns = ref.watch(townsProvider);
    final associations = _townId == null ? null : ref.watch(associationsByTownProvider(_townId!));
    String? server(String f) => state.fieldErrors[f]?.firstOrNull;
    String? show(String? local) => _touchedBusiness ? local : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Business information', subtitle: "Tell us about the business you're registering.", icon: Icons.storefront_rounded),
        const SizedBox(height: AppSpacing.smd),
        AppTextField(label: 'Business name *', controller: _name, hintText: 'Sunrise Grocers', errorText: server('name') ?? show(_nameError), textInputAction: TextInputAction.next),
        const SizedBox(height: AppSpacing.smd),
        categories.when(
          loading: () => const LoadingSkeleton(height: AppSize.field),
          error: (_, _) => const InfoBox(icon: Icons.cloud_off_rounded, tone: AppTone.error, message: 'Could not load categories. Pull to retry later.'),
          data: (list) => DropdownButtonFormField<int>(
            value: _categoryId,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Category *', errorText: server('category_id') ?? show(_categoryError)),
            items: [for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        AppTextField(
          label: 'Description',
          controller: _description,
          maxLines: 3,
          maxLength: 2000,
          hintText: 'What do you sell? What makes your business unique? (optional)',
          helperText: 'Shown on your public storefront profile.',
          errorText: server('description'),
        ),
        const SizedBox(height: AppSpacing.smd),
        Text('Business logo', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        ImagePickerField(label: 'logo', pendingFile: _logo, onPicked: (f) => setState(() => _logo = f), onRemoved: () => setState(() => _logo = null)),
        const SizedBox(height: AppSpacing.smd),
        Text('Cover image', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text('The banner shown at the top of your storefront profile.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        ImagePickerField(label: 'cover image', pendingFile: _cover, onPicked: (f) => setState(() => _cover = f), onRemoved: () => setState(() => _cover = null)),
        const SizedBox(height: AppSpacing.section),
        const SectionHeader(title: 'Owner information', subtitle: "Who's responsible for this business.", icon: Icons.person_outline_rounded),
        const SizedBox(height: AppSpacing.smd),
        AppTextField(label: 'Owner name *', controller: _ownerName, hintText: 'Your full name', errorText: server('owner_name') ?? show(_ownerError), textInputAction: TextInputAction.next),
        const SizedBox(height: AppSpacing.smd),
        AppTextField(
          label: 'Contact mobile number',
          controller: _contactMobile,
          hintText: '9876543210 (optional)',
          helperText: 'Shown to customers if different from your own login number.',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
          errorText: server('contact_mobile_number'),
        ),
        const SizedBox(height: AppSpacing.section),
        const SectionHeader(title: 'Location', subtitle: 'Where customers can find you.', icon: Icons.location_on_outlined),
        const SizedBox(height: AppSpacing.smd),
        towns.when(
          loading: () => const LoadingSkeleton(height: AppSize.field),
          error: (_, _) => const InfoBox(icon: Icons.cloud_off_rounded, tone: AppTone.error, message: 'Could not load towns.'),
          data: (list) => DropdownButtonFormField<int>(
            value: _townId,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Town *', errorText: show(_townError)),
            items: [for (final t in list) DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() {
              _townId = v;
              _associationId = null; // changing town resets association, as on the web
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        if (associations == null)
          const AppTextField(label: 'Association *', enabled: false, hintText: 'Select a town first')
        else
          associations.when(
            loading: () => const LoadingSkeleton(height: AppSize.field),
            error: (_, _) => const InfoBox(icon: Icons.cloud_off_rounded, tone: AppTone.error, message: 'Could not load associations.'),
            data: (list) => DropdownButtonFormField<int>(
              // Keyed by town so switching towns rebuilds the field with a
              // clean initial value instead of a stale selection.
              key: ValueKey('association-$_townId'),
              value: _associationId,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Association *', errorText: server('association_id') ?? show(_associationError)),
              items: [for (final a in list) DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _associationId = v),
            ),
          ),
        const SizedBox(height: AppSpacing.smd),
        AppTextField(label: 'Address *', controller: _address, hintText: '221B Baker Street', errorText: server('address_line') ?? show(_addressError), textInputAction: TextInputAction.next),
        const SizedBox(height: AppSpacing.smd),
        Row(
          children: [
            Expanded(child: AppTextField(label: 'City', controller: _city, errorText: server('city'), textInputAction: TextInputAction.next)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: AppTextField(label: 'State', controller: _state, errorText: server('state'), textInputAction: TextInputAction.next)),
          ],
        ),
        const SizedBox(height: AppSpacing.smd),
        AppTextField(
          label: 'Postal code',
          controller: _postalCode,
          maxLength: 16,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: server('postal_code'),
        ),
        const SizedBox(height: AppSpacing.smd),
        Text('Business location *', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        LocationPicker(value: _pin, onChanged: (p) => setState(() => _pin = p), errorText: server('latitude') ?? show(_pinError)),
        const SizedBox(height: AppSpacing.section),
        if (state.error != null && state.fieldErrors.isEmpty) ...[
          InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: state.error!.message),
          const SizedBox(height: AppSpacing.md),
        ] else if (state.fieldErrors.isNotEmpty) ...[
          const InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: 'Please fix the highlighted fields.'),
          const SizedBox(height: AppSpacing.md),
        ],
        AuthGradientButton(
          label: signedIn ? 'Submit application' : 'Continue',
          isLoading: state.isSubmitting,
          onPressed: () => _continueFromBusiness(signedIn),
        ),
      ],
    );
  }

  Widget _identityForm(MerchantRegistrationState state) {
    String? server(String f) => state.fieldErrors[f]?.firstOrNull;
    String? show(String? local) => _touchedIdentity ? local : null;
    final toggle = IconButton(
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      tooltip: _obscure ? 'Show password' : 'Hide password',
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Create your account',
          subtitle: "Set a password to sign in and manage your business. We'll verify your mobile number later.",
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: AppSpacing.smd),
        AuthTextField(
          label: 'Mobile number',
          icon: Icons.smartphone_rounded,
          controller: _mobile,
          prefixText: '+91 ',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          autofocus: true,
          textInputAction: TextInputAction.next,
          errorText: server('mobile_number') ?? show(_mobileError),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          hintText: 'At least 8 characters',
          controller: _password,
          obscureText: _obscure,
          textInputAction: TextInputAction.next,
          errorText: server('password') ?? show(_passwordError),
          suffixIcon: toggle,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Confirm password',
          icon: Icons.lock_outline_rounded,
          controller: _confirm,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          errorText: show(_confirmError),
          onSubmitted: (_) => _submitIdentity(),
        ),
        if (state.error != null && state.fieldErrors.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(state.error!.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        AuthGradientButton(label: 'Create account and submit', isLoading: state.isSubmitting, onPressed: _submitIdentity),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Back to business details',
          variant: AppButtonVariant.text,
          onPressed: state.isSubmitting ? null : () => setState(() => _step = _Step.business),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.showIdentity});

  final _Step current;
  final bool showIdentity;

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String label, bool active, bool done) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSpacing.lg,
              height: AppSpacing.lg,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active || done ? AppColors.orange : AuthPalette.iconBadge,
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: AppIconSize.xs, color: AppColors.onOrange)
                  : Text('$n', style: AppTypography.badgeLabel.copyWith(color: active ? AppColors.onOrange : AuthPalette.brown)),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: active ? AuthPalette.brown : AuthPalette.mutedText)),
          ],
        );

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        step(1, 'Business details', current == _Step.business, current == _Step.identity),
        if (showIdentity) ...[
          const Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: AuthPalette.mutedText),
          step(2, 'Set a password', current == _Step.identity, false),
        ],
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.imageUploadFailed});

  final bool imageUploadFailed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AuthPalette.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: AuthPalette.fieldBorder),
                boxShadow: AppElevation.subtle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppIconSize.hero),
                  const SizedBox(height: AppSpacing.md),
                  Text('Application submitted', style: textTheme.headlineMedium?.copyWith(color: AuthPalette.brown), textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "Your business is now pending review by a Town Shoppy Super Admin. You already have Owner access to your business dashboard — some actions will unlock once you're approved.",
                    style: textTheme.bodyMedium?.copyWith(color: AuthPalette.mutedText),
                    textAlign: TextAlign.center,
                  ),
                  if (imageUploadFailed) ...[
                    const SizedBox(height: AppSpacing.md),
                    const InfoBox(
                      icon: Icons.image_not_supported_outlined,
                      tone: AppTone.pending,
                      message: 'Your business was submitted, but an image could not be uploaded. You can add it from your profile.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AuthGradientButton(label: 'Go to dashboard', onPressed: () => context.go(BusinessRoutes.root)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
