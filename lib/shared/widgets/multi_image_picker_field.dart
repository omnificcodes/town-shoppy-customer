import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Pick-several-images control -- the Products form's own need (up to
/// [maxImages]); every other image field in this app is single-image (see
/// [ImagePickerField]). Same pick -> validate -> upload-immediately flow as
/// that widget, just holding a list of already-uploaded URLs instead of
/// one: the caller owns [urls] and gets a full replacement list back via
/// [onChanged] after each add/remove, same "caller owns the value" contract
/// [ImagePickerField] uses.
class MultiImagePickerField extends StatefulWidget {
  const MultiImagePickerField({
    super.key,
    required this.urls,
    required this.onChanged,
    required this.onUpload,
    this.maxImages = 5,
    this.helper = 'JPG, PNG, or WebP — up to 5MB each',
  });

  final List<String> urls;
  final ValueChanged<List<String>> onChanged;

  /// Uploads one picked file and returns its public URL (throws on
  /// failure) -- the caller's own `POST /uploads/image` call, same as
  /// [ImagePickerField]'s `onPicked` contract.
  final Future<String> Function(XFile file) onUpload;

  final int maxImages;
  final String helper;

  @override
  State<MultiImagePickerField> createState() => _MultiImagePickerFieldState();
}

class _MultiImagePickerFieldState extends State<MultiImagePickerField> {
  static const _maxBytes = 5 * 1024 * 1024;
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  bool _uploading = false;

  Future<void> _pick() async {
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
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
    if (file == null || !mounted) return;

    final ext = file.name.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext) && source == ImageSource.gallery) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a JPG, PNG, or WebP image.')));
      return;
    }
    if (await file.length() > _maxBytes) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be 5MB or smaller.')));
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await widget.onUpload(file);
      widget.onChanged([...widget.urls, url]);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload that image.')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _remove(int index) {
    final updated = [...widget.urls]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final canAddMore = widget.urls.length < widget.maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.smd,
          runSpacing: AppSpacing.smd,
          children: [
            for (var i = 0; i < widget.urls.length; i++) _ImageThumb(url: widget.urls[i], onRemove: _uploading ? null : () => _remove(i)),
            if (canAddMore) _AddTile(isBusy: _uploading, onTap: _pick),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('${widget.urls.length}/${widget.maxImages} photos · ${widget.helper}', style: AppTypography.caption),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.url, required this.onRemove});

  final String url;
  final VoidCallback? onRemove;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Image.network(
              url,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surfaceMuted, child: Icon(Icons.broken_image_outlined, color: AppColors.textDisabled)),
            ),
          ),
          Positioned(
            top: -AppSpacing.xs,
            right: -AppSpacing.xs,
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxs),
                  child: Icon(Icons.close_rounded, size: AppIconSize.sm, color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.isBusy, required this.onTap});

  final bool isBusy;
  final VoidCallback onTap;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: isBusy ? null : onTap,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.border)),
          alignment: Alignment.center,
          child: isBusy
              ? const SizedBox(width: AppIconSize.md, height: AppIconSize.md, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_photo_alternate_outlined, color: AppColors.orange, size: AppIconSize.lg),
        ),
      ),
    );
  }
}
