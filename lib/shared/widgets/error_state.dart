import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import 'app_button.dart';
import 'state_panel.dart';

/// Friendly, consumer-facing error surface (section 36) — always shows
/// [AppException.message], which is already backend-safe, never a raw
/// exception's `toString()`. [compact] is the inline density for a section
/// that failed inside an otherwise healthy screen (e.g. one Home carousel).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.title, this.compact = false});

  final AppException error;
  final VoidCallback? onRetry;
  final String? title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StatePanel(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.error,
      title: title,
      message: error.message,
      compact: compact,
      action: onRetry == null
          ? null
          : AppButton(
              label: 'Try again',
              variant: AppButtonVariant.secondary,
              size: compact ? AppButtonSize.sm : AppButtonSize.md,
              expand: !compact,
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
            ),
    );
  }
}
