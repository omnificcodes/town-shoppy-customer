import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Icon + accent color for each customer-relevant `NotificationType` value
/// (`App\Domain\Notification\Enums\NotificationType`). The backend enum
/// also has `merchant.approved`/`merchant.rejected` -- deliberately not
/// mapped here, since those only ever notify a Merchant Owner/Staff
/// account and this is the customer-only app (DEC-16: separate app per
/// role, no cross-surface notification delivery); they'd fall through to
/// [_fallback] if they somehow ever arrived here, same as any other
/// future/unknown type.
class NotificationTypeDisplay {
  const NotificationTypeDisplay(this.icon, this.color);

  final IconData icon;
  final Color color;

  static const _fallback = NotificationTypeDisplay(Icons.notifications_rounded, AppColors.info);

  static const Map<String, NotificationTypeDisplay> _byType = {
    'purchase.recorded': NotificationTypeDisplay(Icons.receipt_long_rounded, AppColors.info),
    'purchase.coupon_generated': NotificationTypeDisplay(Icons.confirmation_number_rounded, AppColors.pending),
    'purchase.submitted': NotificationTypeDisplay(Icons.hourglass_top_rounded, AppColors.pending),
    'purchase.rejected': NotificationTypeDisplay(Icons.cancel_rounded, AppColors.error),
    'redemption.initiated': NotificationTypeDisplay(Icons.qr_code_rounded, AppColors.info),
    'redemption.completed': NotificationTypeDisplay(Icons.check_circle_rounded, AppColors.success),
    'redemption.cancelled': NotificationTypeDisplay(Icons.cancel_rounded, AppColors.error),
    'redemption.expired': NotificationTypeDisplay(Icons.timer_off_rounded, AppColors.pending),
    'referral.qualified': NotificationTypeDisplay(Icons.people_alt_rounded, AppColors.success),
    'referral.reward_received': NotificationTypeDisplay(Icons.card_giftcard_rounded, AppColors.success),
    'referral.milestone_reached': NotificationTypeDisplay(Icons.emoji_events_rounded, AppColors.pending),
    'subscription.activated': NotificationTypeDisplay(Icons.workspace_premium_rounded, AppColors.success),
    'subscription.cancelled': NotificationTypeDisplay(Icons.cancel_rounded, AppColors.error),
    'subscription.grace_period': NotificationTypeDisplay(Icons.warning_amber_rounded, AppColors.pending),
    'subscription.expired_suspended': NotificationTypeDisplay(Icons.error_outline_rounded, AppColors.error),
    'payment.successful': NotificationTypeDisplay(Icons.payments_rounded, AppColors.success),
    'payment.failed': NotificationTypeDisplay(Icons.error_outline_rounded, AppColors.error),
    'payment.invoice_available': NotificationTypeDisplay(Icons.description_rounded, AppColors.info),
    'payment.refund_confirmed': NotificationTypeDisplay(Icons.replay_rounded, AppColors.success),
    'draw.won': NotificationTypeDisplay(Icons.emoji_events_rounded, AppColors.success),
  };

  static NotificationTypeDisplay forType(String type) => _byType[type] ?? _fallback;
}
