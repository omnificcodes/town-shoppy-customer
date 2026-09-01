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
