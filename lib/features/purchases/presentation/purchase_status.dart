import '../../../shared/widgets/status_badge.dart';

/// Maps `PurchaseStatus` (`pending`/`recorded`/`rejected`/`disputed`/
/// `voided` — see the backend enum) to a display tone. Shared between the
/// Home "recent purchases" preview and the full Purchases list/detail
/// screens so the same status always reads the same way everywhere in the
/// app. `pending`/`rejected` only ever occur for a Method 1 (customer
/// scanned a merchant QR) request — see PurchaseStatus's own docblock.
StatusTone purchaseStatusTone(String status) => switch (status) {
      'pending' => StatusTone.pending,
      'recorded' => StatusTone.success,
      'rejected' => StatusTone.error,
      'disputed' => StatusTone.pending,
      'voided' => StatusTone.error,
      _ => StatusTone.neutral,
    };

/// Customer-facing label for a raw `PurchaseStatus` string — the badge and
/// the detail screen must never show the backend's lowercase enum value.
/// `pending` reads as what the customer is actually waiting on (the
/// merchant's approval), not as a generic "pending".
String purchaseStatusLabel(String status) => switch (status) {
      'pending' => 'Awaiting approval',
      'recorded' => 'Recorded',
      'rejected' => 'Rejected',
      'disputed' => 'Disputed',
      'voided' => 'Voided',
      _ => status.isEmpty ? status : '${status[0].toUpperCase()}${status.substring(1)}',
    };
