import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// A merchant's logo, or a branded fallback while it loads, fails to load,
/// or is simply absent (`logo_url` is nullable on the backend — not every
/// merchant has uploaded one). Never shows a broken-image icon.
class MerchantLogo extends StatelessWidget {
  const MerchantLogo({super.key, required this.url, required this.merchantName, this.size = AppSize.controlMd});

  final String? url;
  final String merchantName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // Proportional, not a fixed token: the same logo renders at 40/48/56,
      // and a fixed radius would read square on the small one and pill-ish
      // on the large one.
      borderRadius: BorderRadius.circular(size / 4),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url!.isEmpty
            ? _fallback(context)
            : Image.network(
                url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _fallback(context, loading: true);
                },
                errorBuilder: (context, error, stackTrace) => _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context, {bool loading = false}) {
    return Container(
      color: AppColors.orangeTint,
      alignment: Alignment.center,
      child: loading
          ? SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange),
            )
          : Semantics(
              label: '$merchantName logo placeholder',
              child: Icon(Icons.storefront_rounded, color: AppColors.orange, size: size * 0.55),
            ),
    );
  }
}
