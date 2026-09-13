import '../../../core/theme/app_colors.dart';

// Status vocabularies for Phase 3 -- same labels/tones as the merchant web
// app's `offer-status.ts`, `offer-redemption-status.ts`, `prize-status.ts`.

AppTone offerStatusTone(String s) => switch (s) {
      'active' => AppTone.success,
      'draft' => AppTone.info,
      _ => AppTone.neutral,
    };

/// Merchant-facing: a draft is "Scheduled" (set up, not live yet).
String offerStatusLabel(String s) => switch (s) {
      'draft' => 'Scheduled',
      'active' => 'Active',
      'expired' => 'Expired',
      _ => s,
    };

String offerTypeLabel(String t) => switch (t) {
      'percentage_discount' => 'Percentage discount',
      'fixed_discount' => 'Fixed discount',
      'announcement' => 'Announcement',
      _ => t.replaceAll('_', ' '),
    };

AppTone offerRedemptionStatusTone(String s) => switch (s) {
      'pending' => AppTone.pending,
      'approved' => AppTone.success,
      'rejected' => AppTone.error,
      _ => AppTone.neutral,
    };

String offerRedemptionStatusLabel(String s) => switch (s) {
      'pending' => 'Awaiting review',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => s,
    };

AppTone prizeStatusTone(String s) => switch (s) {
      'draft' => AppTone.pending,
      'available' => AppTone.info,
      'allocated' => AppTone.pending,
      'awarded' => AppTone.success,
      'withdrawn' => AppTone.error,
      _ => AppTone.neutral,
    };

String prizeStatusLabel(String s) => switch (s) {
      'draft' => 'Awaiting approval',
      'available' => 'Approved',
      'allocated' => 'In a draw',
      'awarded' => 'Awarded',
      'withdrawn' => 'Withdrawn',
      _ => s,
    };

AppTone voucherStatusTone(String s) => switch (s) {
      'claimed' => AppTone.success,
      'active' => AppTone.pending,
      'assigned' => AppTone.info,
      'void' => AppTone.error,
      _ => AppTone.neutral,
    };

String voucherStatusLabel(String s) => switch (s) {
      'issued' => 'Issued',
      'assigned' => 'Assigned',
      'active' => 'Ready to claim',
      'claimed' => 'Claimed',
      'expired' => 'Expired',
      'void' => 'Void',
      'replaced' => 'Replaced',
      _ => s,
    };
