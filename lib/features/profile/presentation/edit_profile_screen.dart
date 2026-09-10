import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/edit_profile_controller.dart';

/// Everything here is optional, same "progressive profile completion"
/// principle the backend's `CustomerProfile` docblock states -- a customer
/// can save with only their name changed, or nothing at all.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final List<_SocialLinkRow> _socialLinks = [];

  DateTime? _dateOfBirth;
  DateTime? _anniversaryDate;

  bool _initialized = false;
  String _initialName = '';
  DateTime? _initialDateOfBirth;
  DateTime? _initialAnniversaryDate;
  Map<String, String>? _initialSocialLinks;

  @override
  void dispose() {
    _nameController.dispose();
    for (final row in _socialLinks) {
      row.dispose();
    }
    super.dispose();
  }

  void _initializeFrom(AuthAuthenticated authState) {
    if (_initialized) return;
    _initialized = true;

    final profile = authState.account.customerProfile;
    _initialName = profile?.name ?? '';
    _nameController.text = _initialName;
    _initialDateOfBirth = profile?.dateOfBirth;
    _dateOfBirth = _initialDateOfBirth;
    _initialAnniversaryDate = profile?.anniversaryDate;
    _anniversaryDate = _initialAnniversaryDate;
    _initialSocialLinks = profile?.socialLinks;
    for (final entry in profile?.socialLinks?.entries ?? const <MapEntry<String, String>>[]) {
      _socialLinks.add(_SocialLinkRow(platform: entry.key, url: entry.value));
    }
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

  Map<String, String>? get _socialLinksMap {
    final entries = _socialLinks
        .where((row) => row.platformController.text.trim().isNotEmpty && row.urlController.text.trim().isNotEmpty)
        .map((row) => MapEntry(row.platformController.text.trim(), row.urlController.text.trim()));
    return entries.isEmpty ? null : Map.fromEntries(entries);
  }

  void _submit() {
    final name = _nameController.text.trim();
    final socialLinks = _socialLinksMap;

    ref.read(editProfileControllerProvider.notifier).submit(
          name: name,
          dateOfBirth: _dateOfBirth,
          clearDateOfBirth: _dateOfBirth == null && _initialDateOfBirth != null,
          anniversaryDate: _anniversaryDate,
          clearAnniversaryDate: _anniversaryDate == null && _initialAnniversaryDate != null,
          socialLinks: socialLinks,
          clearSocialLinks: socialLinks == null && _initialSocialLinks != null,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppTextField(label: 'Name', controller: _nameController, textInputAction: TextInputAction.next),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(icon: Icons.cake_outlined, title: 'Special dates', subtitle: 'Optional -- we can send you a little something.'),
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
          const SectionHeader(icon: Icons.link_rounded, title: 'Social links', subtitle: 'Optional -- shown on nothing yet, just saved for later.'),
          const SizedBox(height: AppSpacing.smd),
          for (var i = 0; i < _socialLinks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: AppTextField(label: 'Platform', controller: _socialLinks[i].platformController, hintText: 'instagram'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: 'Link',
                      controller: _socialLinks[i].urlController,
                      hintText: 'https://…',
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    tooltip: 'Remove',
                    onPressed: () => setState(() {
                      _socialLinks[i].dispose();
                      _socialLinks.removeAt(i);
                    }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _socialLinks.add(_SocialLinkRow())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add social link'),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          if (editState.submitError != null) ...[
            InfoBox(tone: AppTone.error, icon: Icons.error_outline_rounded, message: editState.submitError!.message),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(label: 'Save changes', isLoading: editState.isSubmitting, onPressed: _submit),
        ],
      ),
    );
  }
}

class _SocialLinkRow {
  _SocialLinkRow({String platform = '', String url = ''})
      : platformController = TextEditingController(text: platform),
        urlController = TextEditingController(text: url);

  final TextEditingController platformController;
  final TextEditingController urlController;

  void dispose() {
    platformController.dispose();
    urlController.dispose();
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
              : IconButton(icon: const Icon(Icons.close_rounded, size: AppIconSize.sm), tooltip: 'Clear', onPressed: onClear),
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
