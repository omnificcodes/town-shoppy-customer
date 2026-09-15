import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Pick-an-image control for logos, covers, offer and prize artwork -- the
/// mobile twin of the merchant web app's `ImageUpload`. Shows either an
/// empty dropzone-style button or a preview with Change / Remove.
///
/// It only *picks*; whether the file is uploaded immediately (profile
/// editor) or held until later (registration, where no account exists yet)
/// is the caller's business -- pass whichever of [previewUrl] (already
/// uploaded) or [pendingFile] (picked, not uploaded) applies.
class ImagePickerField extends StatelessWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.onPicked,
    required this.onRemoved,
    this.previewUrl,
    this.pendingFile,
    this.isBusy = false,
    this.helper = 'JPG, PNG, or WebP — up to 5MB',
    this.previewSize = 64,
  });

  final String label;
  final ValueChanged<XFile> onPicked;
  final VoidCallback onRemoved;
  final String? previewUrl;
  final XFile? pendingFile;
  final bool isBusy;
  final String helper;
  final double previewSize;

  static const _maxBytes = 5 * 1024 * 1024;
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    if (source == null || !context.mounted) return;

    final file = await ImagePicker().pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
    if (file == null || !context.mounted) return;

    final ext = file.name.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext) && source == ImageSource.gallery) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a JPG, PNG, or WebP image.')));
      return;
    }
    if (await file.length() > _maxBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be 5MB or smaller.')));
      }
      return;
    }
    onPicked(file);
  }

  bool get _hasImage => (previewUrl != null && previewUrl!.isNotEmpty) || pendingFile != null;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!_hasImage) {
      return Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: isBusy ? null : () => _pick(context),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: AppSize.avatarMd,
                  height: AppSize.avatarMd,
                  decoration: const BoxDecoration(color: AppColors.orangeTint, shape: BoxShape.circle),
                  child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.orange, size: AppIconSize.md),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload $label', style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(helper, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: SizedBox(
              width: previewSize,
              height: previewSize,
              child: _Preview(url: previewUrl, file: pendingFile),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: isBusy ? null : () => _pick(context),
                  icon: isBusy
                      ? const SizedBox(width: AppIconSize.sm, height: AppIconSize.sm, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.swap_horiz_rounded, size: AppIconSize.sm),
                  label: Text(isBusy ? 'Uploading…' : 'Change'),
                ),
                TextButton.icon(
                  onPressed: isBusy ? null : onRemoved,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline_rounded, size: AppIconSize.sm),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.url, required this.file});

  final String? url;
  final XFile? file;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return FutureBuilder(
        future: file!.readAsBytes(),
        builder: (context, snapshot) => snapshot.hasData
            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
            : const ColoredBox(color: AppColors.surfaceMuted),
      );
    }
    return Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, 
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceMuted,
        child: Icon(Icons.broken_image_outlined, color: AppColors.textDisabled),
      ),
    );
  }
}
