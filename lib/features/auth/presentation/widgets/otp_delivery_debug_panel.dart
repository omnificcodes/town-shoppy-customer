import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/otp_request_result.dart';
import 'auth_widgets.dart';

/// Temporary debugging panel on the code-entry screen: how each OTP channel
/// (SMS, WhatsApp) went and the provider's own error when it failed.
/// Renders nothing unless the API sent delivery details, so it disappears
/// by itself once the API's `OTP_EXPOSE_DELIVERY_ERRORS` is switched off.
class OtpDeliveryDebugPanel extends StatelessWidget {
  const OtpDeliveryDebugPanel({super.key, required this.deliveries, this.debugCode});

  final List<OtpDelivery> deliveries;
  final String? debugCode;

  @override
  Widget build(BuildContext context) {
    if (deliveries.isEmpty) return const SizedBox.shrink();

    final anyProblem = deliveries.any((d) => !d.sent || d.error != null);
    final accent = anyProblem ? AppColors.error : AppColors.success;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodySmall?.copyWith(color: AuthPalette.brown);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: anyProblem ? AppColors.errorBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(anyProblem ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, size: 18, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'OTP delivery (debug)',
                  style: textTheme.labelLarge?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          for (final d in deliveries) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('${d.channelLabel} via ${d.provider}: ${d.sent ? 'accepted' : 'failed'}', style: bodyStyle?.copyWith(fontWeight: FontWeight.w600)),
            if (d.error != null) SelectableText(d.error!, style: bodyStyle),
          ],
          if (debugCode != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SelectableText('Code: $debugCode', style: bodyStyle?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
