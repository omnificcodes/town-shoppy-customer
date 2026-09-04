import '../../../shared/widgets/status_badge.dart';

/// Maps `CouponStatus` (`active`/`won`/`expired` -- see the backend enum)
/// to a display tone/label, and the same for a per-cadence
/// `CouponEligibility.status` (`active`/`closed`/`won`). Kept in one file,
/// same convention as `purchase_status.dart`, so both the coupon list and
/// detail screens read status identically.
StatusTone couponStatusTone(String status) => switch (status) {
      'active' => StatusTone.success,
      'won' => StatusTone.success,
      'expired' => StatusTone.neutral,
      _ => StatusTone.neutral,
    };

String couponStatusLabel(String status) => switch (status) {
      'active' => 'Active',
      'won' => 'Won 🎉',
      'expired' => 'Expired',
      _ => status,
    };

StatusTone eligibilityStatusTone(String status) => switch (status) {
      'active' => StatusTone.success,
      'won' => StatusTone.success,
      'closed' => StatusTone.neutral,
      _ => StatusTone.neutral,
    };

String cadenceLabel(String cadence) => switch (cadence) {
      'weekly' => 'Weekly draw',
      'monthly' => 'Monthly draw',
      'mega' => 'Mega draw',
      _ => cadence,
    };
