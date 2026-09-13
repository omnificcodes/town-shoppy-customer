import '../../../core/theme/app_colors.dart';

/// `MerchantStatus` -> badge tone/label, same vocabulary as the merchant
/// web app's `MERCHANT_STATUS_LABEL` / `_TONE`.
AppTone merchantStatusTone(String status) => switch (status) {
      'active' => AppTone.success,
      'pending' => AppTone.pending,
      'suspended' || 'rejected' || 'subscription_expired' => AppTone.error,
      'inactive' => AppTone.neutral,
      _ => AppTone.neutral,
    };

String merchantStatusLabel(String status) => switch (status) {
      'active' => 'Active',
      'pending' => 'Pending approval',
      'suspended' => 'Suspended',
      'rejected' => 'Rejected',
      'inactive' => 'Inactive',
      'subscription_expired' => 'Subscription expired',
      _ => status.isEmpty ? status : '${status[0].toUpperCase()}${status.substring(1).replaceAll('_', ' ')}',
    };

/// `SubscriptionStatus` -> badge tone/label.
AppTone subscriptionStatusTone(String status) => switch (status) {
      'active' => AppTone.success,
      'grace_period' || 'past_due' => AppTone.pending,
      'suspended' || 'expired' || 'cancelled' => AppTone.error,
      _ => AppTone.neutral,
    };

String subscriptionStatusLabel(String status) => switch (status) {
      'active' => 'Active',
      'grace_period' => 'Grace period',
      'past_due' => 'Past due',
      'suspended' => 'Suspended',
      'expired' => 'Expired',
      'cancelled' => 'Cancelled',
      _ => status.isEmpty ? status : '${status[0].toUpperCase()}${status.substring(1).replaceAll('_', ' ')}',
    };
