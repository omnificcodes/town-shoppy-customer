import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/edit_profile_controller.dart';
import '../data/customer_profile_repository.dart';
import 'social_platforms.dart';

/// Everything here is optional, same "progressive profile completion"
/// principle the backend's `CustomerProfile` docblock states -- a customer
/// can save with only their name changed, or nothing at all.
///
/// Photos upload the moment they are picked (`POST /uploads/image`) and
/// only become the profile's once Save sends the returned URL -- the same
/// upload-then-save flow the business profile editor uses.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _ImageSlot { photo, cover }

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Map<SocialPlatform, TextEditingController> _socialControllers = {
    for (final p in SocialPlatform.values) p: TextEditingController(),
  };

  DateTime? _dateOfBirth;
  DateTime? _anniversaryDate;
  String? _profilePhotoUrl;
  String? _coverImageUrl;
  _ImageSlot? _uploading;

  bool _initialized = false;
  DateTime? _initialDateOfBirth;
  DateTime? _initialAnniversaryDate;
  Map<String, String>? _initialSocialLinks;
  String? _initialProfilePhotoUrl;
  String? _initialCoverImageUrl;

  /// Links saved under any other platform (from the earlier free-form
  /// editor). Not shown, but sent back on every save so none are lost.
  Map<String, String> _otherSocialLinks = const {};

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _socialControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeFrom(AuthAuthenticated authState) {
    if (_initialized) return;
    _initialized = true;

    final profile = authState.account.customerProfile;
    _nameController.text = profile?.name ?? '';
    _initialDateOfBirth = profile?.dateOfBirth;
    _dateOfBirth = _initialDateOfBirth;
    _initialAnniversaryDate = profile?.anniversaryDate;
    _anniversaryDate = _initialAnniversaryDate;
    _initialProfilePhotoUrl = profile?.profilePhotoUrl;
    _profilePhotoUrl = _initialProfilePhotoUrl;
    _initialCoverImageUrl = profile?.coverImageUrl;
    _coverImageUrl = _initialCoverImageUrl;

    final links = profile?.socialLinks;
    _initialSocialLinks = links;
    for (final platform in SocialPlatform.values) {
      _socialControllers[platform]!.text = links?[platform.key] ?? '';
    }
    _otherSocialLinks = {
      for (final entry in links?.entries ?? const <MapEntry<String, String>>[])
        if (!SocialPlatform.keys.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<void> _pickDate({required DateTime? initial, required ValueChanged<DateTime?> onPicked}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _upload(_ImageSlot slot, XFile file) async {
    setState(() => _uploading = slot);
    try {
      final url = await ref.read(customerProfileRepositoryProvider).uploadImage(file);
      if (!mounted) return;
      setState(() => slot == _ImageSlot.photo ? _profilePhotoUrl = url : _coverImageUrl = url);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Map<String, String>? get _socialLinksMap {
    final links = <String, String>{
      ..._otherSocialLinks,
      for (final platform in SocialPlatform.values)
        if (_socialControllers[platform]!.text.trim().isNotEmpty)
          platform.key: _socialControllers[platform]!.text.trim(),
    };
    return links.isEmpty ? null : links;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final socialLinks = _socialLinksMap;

    ref
        .read(editProfileControllerProvider.notifier)
        .submit(
          name: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          clearDateOfBirth: _dateOfBirth == null && _initialDateOfBirth != null,
          anniversaryDate: _anniversaryDate,
          clearAnniversaryDate: _anniversaryDate == null && _initialAnniversaryDate != null,
          socialLinks: socialLinks,
          clearSocialLinks: socialLinks == null && _initialSocialLinks != null,
          profilePhotoUrl: _profilePhotoUrl,
          clearProfilePhoto: _profilePhotoUrl == null && _initialProfilePhotoUrl != null,
          coverImageUrl: _coverImageUrl,
          clearCoverImage: _coverImageUrl == null && _initialCoverImageUrl != null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final editState = ref.watch(editProfileControllerProvider);

    ref.listen(editProfileControllerProvider, (previous, next) {
      if (next.success && previous?.success != true) context.pop();
    });

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: LoadingSkeletonList(count: 4));
    }

    _initializeFrom(authState);
    final isBusy = _uploading != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            _PhotoHeader(
              coverUrl: _coverImageUrl,
              photoUrl: _profilePhotoUrl,
              initials: _initials(_nameController.text, authState.account.mobileNumber),
              uploading: _uploading,
              onPickCover: (file) => _upload(_ImageSlot.cover, file),
              onRemoveCover: () => setState(() => _coverImageUrl = null),
              onPickPhoto: (file) => _upload(_ImageSlot.photo, file),
              onRemovePhoto: () => setState(() => _profilePhotoUrl = null),
            ),
            const SizedBox(height: AppSpacing.section),
            AppTextField(label: 'Name', controller: _nameController, textInputAction: TextInputAction.next),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(
              icon: Icons.cake_outlined,
              title: 'Special dates',
              subtitle: 'Optional -- we can send you a little something.',
            ),
            const SizedBox(height: AppSpacing.smd),
            _DateField(
              label: 'Date of birth',
              value: _dateOfBirth,
              onTap: () => _pickDate(initial: _dateOfBirth, onPicked: (d) => setState(() => _dateOfBirth = d)),
              onClear: _dateOfBirth == null ? null : () => setState(() => _dateOfBirth = null),
            ),
            const SizedBox(height: AppSpacing.smd),
            _DateField(
              label: 'Anniversary',
              value: _anniversaryDate,
              onTap: () => _pickDate(initial: _anniversaryDate, onPicked: (d) => setState(() => _anniversaryDate = d)),
              onClear: _anniversaryDate == null ? null : () => setState(() => _anniversaryDate = null),
            ),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(
              icon: Icons.link_rounded,
              title: 'Social media links',
              subtitle: 'Optional -- paste the link to your profile or page.',
            ),
            const SizedBox(height: AppSpacing.smd),
            for (final platform in SocialPlatform.values) ...[
              _SocialLinkField(platform: platform, controller: _socialControllers[platform]!),
              const SizedBox(height: AppSpacing.smd),
            ],
            const SizedBox(height: AppSpacing.md),
            if (editState.submitError != null) ...[
              InfoBox(tone: AppTone.error, icon: Icons.error_outline_rounded, message: editState.submitError!.message),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: isBusy ? 'Uploading photo…' : 'Save changes',
              isLoading: editState.isSubmitting,
              onPressed: isBusy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name, String mobile) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isNotEmpty) return parts.take(2).map((p) => p[0].toUpperCase()).join();
    return mobile.length >= 2 ? mobile.substring(mobile.length - 2) : '?';
  }
}

/// Shows the gallery/camera choice, then checks type and size -- the same
/// rules `POST /uploads/image` enforces (JPG, PNG or WebP, up to 5 MB).
Future<XFile?> _pickImage(BuildContext context, {required String title}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xs),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  final file = await ImagePicker().pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
  if (file == null || !context.mounted) return null;

  const allowed = {'jpg', 'jpeg', 'png', 'webp'};
  final ext = file.name.split('.').last.toLowerCase();
  if (!allowed.contains(ext) && source == ImageSource.gallery) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a JPG, PNG, or WebP image.')));
    return null;
  }
  if (await file.length() > 5 * 1024 * 1024) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be 5MB or smaller.')));
    }
    return null;
  }
  return file;
}

/// The cover banner with the round profile photo overlapping its bottom
/// edge, each with its own Upload / Change / Remove controls.
class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.coverUrl,
    required this.photoUrl,
    required this.initials,
    required this.uploading,
    required this.onPickCover,
    required this.onRemoveCover,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  final String? coverUrl;
  final String? photoUrl;
  final String initials;
  final _ImageSlot? uploading;
  final ValueChanged<XFile> onPickCover;
  final VoidCallback onRemoveCover;
  final ValueChanged<XFile> onPickPhoto;
  final VoidCallback onRemovePhoto;

  static const _coverHeight = 150.0;
  static const _photoSize = 96.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final busy = uploading != null;

    Future<void> pick(String title, ValueChanged<XFile> onPicked) async {
      final file = await _pickImage(context, title: title);
      if (file != null) onPicked(file);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _coverHeight + _photoSize / 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _coverHeight,
                  child: Semantics(
                    image: true,
                    label: hasCover ? 'Cover image' : 'No cover image',
                    child: hasCover
                        ? Image.network(
                            coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _CoverPlaceholder(),
                          )
                        : const _CoverPlaceholder(),
                  ),
                ),
                if (uploading == _ImageSlot.cover)
                  const Positioned(left: 0, right: 0, top: 0, height: _coverHeight, child: _UploadingScrim()),
                Positioned(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: _ImageMenuButton(
                    label: hasCover ? 'Edit cover' : 'Add cover',
                    icon: Icons.photo_camera_outlined,
                    enabled: !busy,
                    hasImage: hasCover,
                    onUpload: () => pick(hasCover ? 'Change cover image' : 'Upload cover image', onPickCover),
                    onRemove: onRemoveCover,
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  bottom: 0,
                  child: Container(
                    width: _photoSize,
                    height: _photoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.surface, width: 4),
                      boxShadow: AppElevation.card,
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Semantics(
                            image: true,
                            label: hasPhoto ? 'Profile photo' : 'No profile photo',
                            child: hasPhoto
                                ? Image.network(
                                    photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _InitialsAvatar(initials: initials),
                                  )
                                : _InitialsAvatar(initials: initials),
                          ),
                          if (uploading == _ImageSlot.photo) const _UploadingScrim(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.smd, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile photo', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xxs),
                Text('JPG, PNG, or WebP — up to 5MB', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => pick(hasPhoto ? 'Change profile photo' : 'Upload profile photo', onPickPhoto),
                      icon: const Icon(Icons.add_a_photo_outlined, size: AppIconSize.sm),
                      label: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
                    ),
                    if (hasPhoto)
                      TextButton.icon(
                        onPressed: busy ? null : onRemovePhoto,
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        icon: const Icon(Icons.delete_outline_rounded, size: AppIconSize.sm),
                        label: const Text('Remove photo'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.warmWash),
      child: Center(
        child: Icon(Icons.panorama_outlined, color: AppColors.orangeDeep, size: AppIconSize.display),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.promoHero),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _UploadingScrim extends StatelessWidget {
  const _UploadingScrim();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.scrim,
      child: Center(child: CircularProgressIndicator(color: AppColors.onScrim)),
    );
  }
}

/// The cover's pill button: straight to the picker when there is no cover,
/// otherwise a menu with Change / Remove.
class _ImageMenuButton extends StatelessWidget {
  const _ImageMenuButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.hasImage,
    required this.onUpload,
    required this.onRemove,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool hasImage;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: const BoxConstraints(minHeight: AppSize.controlSm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
      decoration: BoxDecoration(color: AppColors.scrim, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.sm, color: AppColors.onScrim),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.onScrim, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    if (!hasImage) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            onTap: enabled ? onUpload : null,
            child: Opacity(opacity: enabled ? 1 : 0.6, child: pill),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: label,
      enabled: enabled,
      onSelected: (value) => value == 'change' ? onUpload() : onRemove(),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'change',
          child: ListTile(leading: Icon(Icons.swap_horiz_rounded), title: Text('Change cover')),
        ),
        PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
            title: Text('Remove cover', style: TextStyle(color: AppColors.error)),
          ),
        ),
      ],
      child: Opacity(opacity: enabled ? 1 : 0.6, child: pill),
    );
  }
}

/// One platform row: the brand icon tile, then the link field validated
/// against that platform's hosts.
class _SocialLinkField extends StatelessWidget {
  const _SocialLinkField({required this.platform, required this.controller});

  final SocialPlatform platform;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: AppSize.field,
            height: AppSize.field,
            decoration: BoxDecoration(
              color: platform.brandColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
              border: Border.all(color: platform.brandColor.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: FaIcon(platform.icon, color: platform.brandColor, size: AppIconSize.lg),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => platform.validate(value ?? ''),
            decoration: InputDecoration(
              labelText: platform.label,
              hintText: platform.hint,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: AppIconSize.sm),
                        tooltip: 'Clear ${platform.label} link',
                        onPressed: controller.clear,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A tappable date picker styled like [AppTextField] but without owning a
/// [TextEditingController] -- the displayed text is a formatted [value],
/// not something the user directly types, so there is no controller to
/// create-and-leak on every rebuild the way a plain `AppTextField` would
/// need one for.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap, required this.onClear});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: AppIconSize.md),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: AppIconSize.sm),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? 'Not set' : _formatDate(value!),
          style: value == null
              ? Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).hintColor)
              : Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
