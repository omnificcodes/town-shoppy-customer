import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/image_picker_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/location_picker.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../application/business_branches_controller.dart';
import '../../data/business_merchant_repository.dart';
import '../../data/models/merchant_branch.dart';
import '../widgets/business_page_header.dart';

/// Loads the branch named in the URL, then hands it to [BranchFormScreen].
///
/// The form needs a whole entity, and the route used to pass one through
/// GoRouter's `extra`. That is in-memory only: on the hosted web build it
/// does not survive a page reload, so a refreshed `/edit` URL rendered an
/// empty create form -- and saving it CREATED a second record instead of
/// editing the one the URL named. The id in the path is the durable half,
/// so it is what this loads from; `extra` is kept only as a hint that
/// paints the filled form instantly when arriving from the list.
class EditBranchScreen extends ConsumerWidget {
  const EditBranchScreen({super.key, required this.branchId, this.initial});

  final int branchId;
  final MerchantBranch? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A merchant's branches load as one complete list, so there is no
    // per-branch endpoint to call -- the branch is simply the one in it.
    final async = ref.watch(businessBranchesControllerProvider);
    final branches = async.value;
    final branch = branches?.where((b) => b.id == branchId).firstOrNull ?? initial;

    if (branch != null) {
      return BranchFormScreen(key: ValueKey('branch-form-$branchId'), branch: branch);
    }

    return BusinessScaffold(
      title: 'Edit branch',
      body: async.hasError
          ? ErrorState(
              error: async.error is AppException ? async.error! as AppException : const UnknownAppException(),
              title: 'Could not load this branch',
              onRetry: () => ref.invalidate(businessBranchesControllerProvider),
            )
          : branches != null
              // Loaded, but this id is not among them: deleted, or never
              // this merchant's. Never fall through to a create form.
              ? const ErrorState(
                  error: NotFoundException('This branch no longer exists, or it is not one of yours.'),
                  title: 'Branch not found',
                )
              : const LoadingSkeletonList(count: 4),
    );
  }
}
/// Create or edit a branch -- the web's `BranchFormDialog` field for field.
/// Owner only (`MerchantBranchPolicy::create/update`).
class BranchFormScreen extends ConsumerStatefulWidget {
  const BranchFormScreen({super.key, this.branch});

  /// `null` = create.
  final MerchantBranch? branch;

  @override
  ConsumerState<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends ConsumerState<BranchFormScreen> {
  late final _name = TextEditingController(text: widget.branch?.name ?? '');
  late final _address = TextEditingController(text: widget.branch?.addressLine ?? '');
  late final _locality = TextEditingController(text: widget.branch?.locality ?? '');
  late final _city = TextEditingController(text: widget.branch?.city ?? '');
  late final _state = TextEditingController(text: widget.branch?.state ?? '');
  late final _postal = TextEditingController(text: widget.branch?.postalCode ?? '');
  late String? _coverUrl = widget.branch?.coverImageUrl;
  late LatLng? _pin = widget.branch?.latitude != null && widget.branch?.longitude != null ? LatLng(widget.branch!.latitude!, widget.branch!.longitude!) : null;
  late bool _isPrimary = widget.branch?.isPrimary ?? false;

  bool _touched = false;
  bool _uploading = false;
  bool _saving = false;
  AppException? _error;
  Map<String, List<String>> _fieldErrors = const {};

  bool get _isEditing => widget.branch != null;

  @override
  void dispose() {
    for (final c in [_name, _address, _locality, _city, _state, _postal]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError => _name.text.trim().isEmpty ? 'Branch name is required.' : null;
  String? get _addressError => _address.text.trim().isEmpty ? 'Address is required.' : null;
  String? get _pinError => _pin == null ? "Pin this branch's location on the map." : null;

  Future<void> _upload(XFile file) async {
    setState(() => _uploading = true);
    try {
      final url = await ref.read(businessMerchantRepositoryProvider).uploadImage(file);
      if (mounted) setState(() => _coverUrl = url);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _touched = true);
    if (_nameError != null || _addressError != null || _pinError != null) return;

    final input = BranchInput(
      name: _name.text,
      addressLine: _address.text,
      latitude: _pin!.latitude,
      longitude: _pin!.longitude,
      coverImageUrl: _coverUrl,
      locality: _locality.text,
      city: _city.text,
      state: _state.text,
      postalCode: _postal.text,
      isPrimary: _isPrimary,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final controller = ref.read(businessBranchesControllerProvider.notifier);
      if (_isEditing) {
        await controller.patch(widget.branch!.id, input.toJson());
      } else {
        await controller.create(input);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_name.text.trim()} ${_isEditing ? 'updated' : 'added'}.')));
      context.pop();
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
      title: _isEditing ? 'Edit branch' : 'New branch',
      padded: false,
      bottomBar: AppButton(label: _isEditing ? 'Save changes' : 'Add branch', isLoading: _saving, onPressed: _uploading ? null : _save),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          SectionHeader(
            title: 'Branch details',
            subtitle: _isEditing ? "Update ${widget.branch!.name}'s details." : 'Add a new location for your business.',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Branch name', controller: _name, hintText: 'Downtown Branch', errorText: server('name') ?? show(_nameError), textInputAction: TextInputAction.next),
          const SizedBox(height: AppSpacing.smd),
          Text('Cover image', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text('A photo of this location, shown on its branch card. Falls back to your business cover image when left empty.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          ImagePickerField(label: 'cover image', previewUrl: _coverUrl, isBusy: _uploading, onPicked: _upload, onRemoved: () => setState(() => _coverUrl = null)),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(label: 'Address', controller: _address, hintText: '221B Baker Street', errorText: server('address_line') ?? show(_addressError), textInputAction: TextInputAction.next),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              Expanded(child: AppTextField(label: 'Locality', controller: _locality, errorText: server('locality'), textInputAction: TextInputAction.next)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: AppTextField(label: 'City', controller: _city, errorText: server('city'), textInputAction: TextInputAction.next)),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              Expanded(child: AppTextField(label: 'State', controller: _state, errorText: server('state'), textInputAction: TextInputAction.next)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  label: 'Postal code',
                  controller: _postal,
                  maxLength: 16,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  errorText: server('postal_code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Text('Branch location *', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          LocationPicker(value: _pin, onChanged: (p) => setState(() => _pin = p), errorText: server('latitude') ?? show(_pinError)),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Primary branch'),
            subtitle: Text(
              _isEditing && widget.branch!.isPrimary
                  ? 'This is already your primary branch.'
                  : 'Makes this the branch customers see first. The current primary branch will be demoted automatically.',
            ),
            value: _isPrimary,
            activeColor: AppColors.businessInk,
            onChanged: _isEditing && widget.branch!.isPrimary ? null : (v) => setState(() => _isPrimary = v),
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
